defmodule Gunther.RouterTest do
  use ExUnit.Case, async: true

  alias Gunther.Decision
  alias Gunther.Router

  defp model(alias, attrs \\ []) do
    Map.merge(
      %{
        alias: alias,
        provider: :p,
        model_id: "id",
        locality: :cloud,
        node: nil,
        capabilities: [],
        modalities: [],
        context_window: 4096,
        max_concurrency: 1,
        tags: []
      },
      Map.new(attrs)
    )
  end

  defp catalog(models) do
    %{version: 1, models: Map.new(models, &{&1.alias, &1}), providers: %{}, nodes: %{}}
  end

  defp opts(extra \\ []) do
    Keyword.merge(
      [
        catalog: catalog([model(:a), model(:b)]),
        consumer: :default,
        rules: [],
        consumer_rules: [],
        fallback_strategy: :least_used
      ],
      extra
    )
  end

  describe "route/2" do
    test "sin reglas elige el primer candidato del fallback" do
      {:ok, decision} = Router.route([%{role: :user, content: "hola"}], opts())

      assert decision.chosen == :a
      assert decision.reason == :fallback
      assert decision.layers_ran == [:fallback]
      assert decision.ranked == [:a, :b]
    end

    test "sin candidatos devuelve :no_candidates" do
      {:error, error} = Router.route([%{role: :user, content: "hola"}], opts(catalog: catalog([])))

      assert error.code == :no_candidates
    end

    test "una peticion invalida devuelve :invalid_request" do
      {:error, error} = Router.route([], opts())

      assert error.code == :invalid_request
    end

    test "un rol desconocido devuelve :invalid_request" do
      {:error, error} = Router.route([%{role: :inventado, content: "hola"}], opts())

      assert error.code == :invalid_request
    end

    test "un pin fija el modelo y gana al fallback" do
      {:ok, decision} =
        Router.route([%{role: :user, content: "hola"}], opts(model: :b))

      assert decision.chosen == :b
      assert decision.reason == :pin
      assert decision.layers_ran == [:pin]
    end

    test "un pin a un modelo que no existe devuelve :no_candidates" do
      {:error, error} = Router.route([%{role: :user, content: "hola"}], opts(model: :zzz))

      assert error.code == :no_candidates
    end

    test "un veto deja sin candidatos" do
      rules = [%{name: "v", action: :veto, target: %{locality: "cloud"}}]

      {:error, error} = Router.route([%{role: :user, content: "hola"}], opts(rules: rules))

      assert error.code == :no_candidates
      assert error.details.filtered == [%{model: :a, reason: :veto}, %{model: :b, reason: :veto}]
    end

    test "un veto deja el resto de candidatos" do
      rules = [%{name: "v", action: :veto, target: %{models: ["a"]}}]

      {:ok, decision} = Router.route([%{role: :user, content: "hola"}], opts(rules: rules))

      assert decision.chosen == :b
      # El motivo distingue el veto de la capa de reglas (§4.13): un veto es
      # seguridad y su motivo se ve.
      assert decision.reason == :veto
      assert decision.layers_ran == [:rule]
      assert decision.global_rules_applied == ["v"]
    end

    test "un force restringe a los que casan" do
      rules = [%{name: "f", action: :force, target: %{models: ["b"]}}]

      {:ok, decision} = Router.route([%{role: :user, content: "hola"}], opts(rules: rules))

      assert decision.chosen == :b
      # El motivo distingue el force: es el operador (§4.13).
      assert decision.reason == :force
      assert decision.layers_ran == [:rule]
    end

    test "un veto gana a un pin" do
      rules = [%{name: "v", action: :veto, target: %{models: ["b"]}}]

      {:error, error} = Router.route([%{role: :user, content: "hola"}], opts(rules: rules, model: :b))

      assert error.code == :no_candidates
    end

    test "un force gana a un pin" do
      rules = [%{name: "f", action: :force, target: %{models: ["a"]}}]

      {:ok, decision} = Router.route([%{role: :user, content: "hola"}], opts(rules: rules, model: :b))

      assert decision.chosen == :a
    end

    test "un prefer pondera el destino" do
      rules = [%{name: "p", action: :prefer, weight: 2.0, target: %{models: ["b"]}}]

      {:ok, decision} = Router.route([%{role: :user, content: "hola"}], opts(rules: rules))

      assert decision.chosen == :b
      assert decision.reason == :rule
      assert decision.ranked == [:b, :a]
    end

    test "un veto sobre otro modelo no cambia el destino pineado" do
      rules = [%{name: "v", action: :veto, target: %{models: ["a"]}}]

      {:ok, decision} = Router.route([%{role: :user, content: "hola"}], opts(rules: rules, model: :b))

      assert decision.chosen == :b
      assert decision.reason == :pin
    end

    test "un veto sobre el modelo pineado lo deja sin candidatos" do
      rules = [%{name: "v", action: :veto, target: %{models: ["b"]}}]

      {:error, error} = Router.route([%{role: :user, content: "hola"}], opts(rules: rules, model: :b))

      assert error.code == :no_candidates
    end

    test "la traza dice que capas corrieron" do
      {:ok, decision} = Router.route([%{role: :user, content: "hola"}], opts())

      trace = Router.trace(decision)

      assert trace.layers_ran == [:fallback]
      assert trace.chosen == :a
      assert trace.ranked == [:a, :b]
      assert is_integer(trace.duration_ms)
    end

    test "la traza lleva el numero de candidatos por capa" do
      {:ok, decision} = Router.route([%{role: :user, content: "hola"}], opts())

      trace = Router.trace(decision)

      assert trace.candidates_per_layer == [%{layer: :fallback, before: 2, after: 2}]
    end

    test "el ranking lleva todos los candidatos elegibles" do
      {:ok, decision} = Router.route([%{role: :user, content: "hola"}], opts())

      assert decision.ranked == [:a, :b]
    end

    test "el texto de la peticion se normaliza para las reglas" do
      rules = [%{name: "v", action: :veto, when: %{contains: "privado"}, target: %{locality: "cloud"}}]

      {:error, error} =
        Router.route([%{role: :user, content: "esto es PRIVADO"}], opts(rules: rules))

      assert error.code == :no_candidates
    end

    test "el provider del modelo elegido va en la decision" do
      {:ok, decision} = Router.route([%{role: :user, content: "hola"}], opts())

      assert decision.provider == :p
    end

    test "una decision lleva el instante y el identificador de traza" do
      {:ok, decision} = Router.route([%{role: :user, content: "hola"}], opts())

      assert %DateTime{} = decision.timestamp
      assert byte_size(decision.trace_id) > 0
    end
  end

  describe "route/2 con reglas de consumer" do
    test "una regla de consumer se aplica a su consumer" do
      consumer_rules = [%{name: "cv", action: :veto, target: %{models: ["a"]}}]

      {:ok, decision} =
        Router.route(
          [%{role: :user, content: "hola"}],
          opts(consumer_rules: consumer_rules)
        )

      assert decision.chosen == :b
      assert decision.consumer_rules_applied == ["cv"]
    end

    test "las reglas globales y las de consumer se distinguen en la traza" do
      rules = [%{name: "g", action: :prefer, target: %{models: ["a"]}}]
      consumer_rules = [%{name: "c", action: :veto, target: %{models: ["b"]}}]

      {:ok, decision} =
        Router.route(
          [%{role: :user, content: "hola"}],
          opts(rules: rules, consumer_rules: consumer_rules)
        )

      assert decision.global_rules_applied == ["g"]
      assert decision.consumer_rules_applied == ["c"]
    end
  end

  describe "fallback_strategy" do
    test "last deja el ultimo candidato primero" do
      {:ok, decision} =
        Router.route([%{role: :user, content: "hola"}], opts(fallback_strategy: :last))

      assert decision.chosen == :b
    end

    test "first deja el primero" do
      {:ok, decision} =
        Router.route([%{role: :user, content: "hola"}], opts(fallback_strategy: :first))

      assert decision.chosen == :a
    end

    test "una estrategia desconocida cae en el primero" do
      {:ok, decision} =
        Router.route([%{role: :user, content: "hola"}], opts(fallback_strategy: :inventada))

      assert decision.chosen == :a
    end
  end

  describe "Decision" do
    test "la decision es una struct con la forma del SPEC" do
      decision = %Decision{chosen: :a, provider: :p}

      assert decision.ranked == []
      assert decision.layers_ran == []
      assert decision.reason == :fallback
    end
  end
end
