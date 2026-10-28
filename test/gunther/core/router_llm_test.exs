defmodule Gunther.RouterLlmTest do
  use ExUnit.Case, async: true

  alias Gunther.DecisionSpec
  alias Gunther.Router

  # Un provider que responde con una ruta fija.
  defmodule Echo do
    def chat(_messages, _opts) do
      {:ok, %{content: ~s({"route": "code"}), finish_reason: :stop, usage: %{}}}
    end
  end

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

  defp spec(attrs \\ []) do
    DecisionSpec.new(
      Map.merge(
        %{
          id: :router,
          kind: :preference_router,
          model: :decisor,
          routes: %{code: %{description: "Programacion", models: [:b]}},
          verification: :active
        },
        Map.new(attrs)
      )
    )
  end

  defp opts(extra \\ []) do
    Keyword.merge(
      [
        catalog: catalog([model(:a), model(:b)]),
        consumer: :default,
        rules: [],
        consumer_rules: [],
        fallback_strategy: :least_used,
        cache_enabled: false,
        provider: Echo,
        decision_spec: spec()
      ],
      extra
    )
  end

  defp message, do: [%{role: :user, content: "arregla este bug"}]

  describe "la capa :llm en el router" do
    test "sin modelo de decision la capa no existe" do
      {:ok, decision} = Router.route(message(), opts(decision_spec: nil))

      assert decision.reason == :fallback
    end

    test "con router.llm = never la capa no existe" do
      {:ok, decision} = Router.route(message(), opts(llm_mode: :never))

      assert decision.reason == :fallback
    end

    test "con router.llm = fallback la capa decide" do
      {:ok, decision} = Router.route(message(), opts(llm_mode: :fallback))

      assert decision.chosen == :b
      assert decision.reason == :llm
      assert decision.layers_ran == [:llm]
    end

    test "la decision lleva el modelo que opino y el hash de lo que vio" do
      {:ok, decision} = Router.route(message(), opts(llm_mode: :fallback))

      assert decision.decision_model.id == :router
      assert decision.decision_model.kind == :preference_router
      assert is_binary(decision.decision_model.decision_input_sha256)
    end

    test "un veto corta antes que la capa :llm" do
      rules = [%{name: "v", when: nil, action: :veto, target: %{models: [:b]}, weight: nil}]

      {:ok, decision} = Router.route(message(), opts(llm_mode: :fallback, rules: rules))

      assert decision.chosen == :a
      assert decision.reason == :rule
    end

    test "un pin gana a la capa :llm" do
      {:ok, decision} = Router.route(message(), opts(llm_mode: :fallback, pin: :a))

      assert decision.chosen == :a
      assert decision.reason == :pin
    end

    test "un modelo de decision sin verificar deja el aviso" do
      {:ok, decision} =
        Router.route(message(), opts(llm_mode: :fallback, decision_spec: spec(verification: :unverified)))

      assert decision.reason == :fallback
      assert :classifier_unverified in decision.degraded
    end
  end
end
