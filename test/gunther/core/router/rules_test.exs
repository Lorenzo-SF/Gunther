defmodule Gunther.Router.RulesTest do
  use ExUnit.Case, async: true

  alias Gunther.Router.Rules

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

  defp rule(attrs) do
    Map.merge(%{name: "r", action: :veto, target: %{}}, attrs)
  end

  describe "when/2" do
    test "sin `when`, la regla aplica siempre" do
      assert Rules.when?(nil, "cualquier texto")
    end

    test "{contains: ...} busca el patron en el texto normalizado" do
      assert Rules.when?(%{contains: "privado"}, "esto es PRIVADO")
      refute Rules.when?(%{contains: "privado"}, "esto es publico")
    end

    test "{any: [...]} se cumple con una sola condicion" do
      assert Rules.when?(%{any: [%{contains: "a"}, %{contains: "z"}]}, "texto a")
      refute Rules.when?(%{any: [%{contains: "a"}, %{contains: "z"}]}, "texto b")
    end

    test "{all: [...]} exige todas las condiciones" do
      assert Rules.when?(%{all: [%{contains: "a"}, %{contains: "b"}]}, "texto a y b")
      refute Rules.when?(%{all: [%{contains: "a"}, %{contains: "b"}]}, "texto a")
    end

    test "{regex: ...} compila la expresion" do
      assert Rules.when?(%{regex: ~r/^priv/i}, "PRIVADO")
      refute Rules.when?(%{regex: ~r/^priv/i}, "publico")
    end

    test "la normalizacion quita diacriticos y baja a minusculas" do
      assert Rules.when?(%{contains: "informacion"}, "INFORMACIÓN sensible")
    end

    test "una condicion desconocida no se cumple" do
      refute Rules.when?(%{lang: "es"}, "hola")
    end

    test "una regex invalida no lanza: no se cumple" do
      refute Rules.when?(%{regex: "no-es-una-regex"}, "hola")
    end
  end

  describe "matches?/2" do
    test "el target de models casa por alias" do
      assert Rules.matches?(%{models: ["a"]}, model(:a))
      refute Rules.matches?(%{models: ["b"]}, model(:a))
    end

    test "el target de provider casa por provider" do
      assert Rules.matches?(%{provider: "p"}, model(:a))
      refute Rules.matches?(%{provider: "otro"}, model(:a))
    end

    test "el target de capability casa por capacidades" do
      assert Rules.matches?(%{capability: "vision"}, model(:a, capabilities: [:vision]))
      refute Rules.matches?(%{capability: "vision"}, model(:a))
    end

    test "el target de locality casa por localidad" do
      assert Rules.matches?(%{locality: "local"}, model(:a, locality: :local))
      refute Rules.matches?(%{locality: "local"}, model(:a, locality: :cloud))
    end

    test "el target de tags casa por etiquetas" do
      assert Rules.matches?(%{tags: ["barato"]}, model(:a, tags: [:barato]))
      refute Rules.matches?(%{tags: ["barato"]}, model(:a))
    end

    test "un target vacio no casa con nadie" do
      refute Rules.matches?(%{}, model(:a))
    end

    test "un target con una clave desconocida no casa con nadie" do
      refute Rules.matches?(%{inventada: "x"}, model(:a))
    end
  end

  describe "apply/4" do
    test "un veto elimina los candidatos que casan" do
      models = [model(:a, locality: :cloud), model(:b, locality: :local)]

      {eligible, filtered, applied} =
        Rules.apply(models, [rule(%{action: :veto, target: %{locality: "cloud"}})], "texto", [])

      assert Enum.map(eligible, & &1.alias) == [:b]
      assert filtered == [%{model: :a, reason: :veto}]
      assert applied == ["r"]
    end

    test "una regla sin `when` aplica siempre" do
      models = [model(:a)]

      {eligible, _filtered, _applied} =
        Rules.apply(models, [rule(%{action: :veto, target: %{models: ["a"]}})], "cualquier cosa", [])

      assert eligible == []
    end

    test "una regla cuyo `when` no se cumple no aplica" do
      models = [model(:a)]

      {eligible, _filtered, applied} =
        Rules.apply(
          models,
          [rule(%{action: :veto, when: %{contains: "privado"}, target: %{models: ["a"]}})],
          "texto publico",
          []
        )

      assert Enum.map(eligible, & &1.alias) == [:a]
      assert applied == []
    end

    test "un force restringe el conjunto a los que casan" do
      models = [model(:a, provider: :p1), model(:b, provider: :p2)]

      {eligible, filtered, applied} =
        Rules.apply(models, [rule(%{action: :force, target: %{provider: "p2"}})], "texto", [])

      assert Enum.map(eligible, & &1.alias) == [:b]
      assert filtered == [%{model: :a, reason: :force}]
      assert applied == ["r"]
    end

    test "dos force en desacuerdo se intersectan" do
      models = [model(:a, provider: :p1), model(:b, provider: :p2), model(:c, provider: :p3)]

      {eligible, _filtered, _applied} =
        Rules.apply(
          models,
          [
            rule(%{name: "f1", action: :force, target: %{provider: "p1"}}),
            rule(%{name: "f2", action: :force, target: %{provider: "p2"}})
          ],
          "texto",
          []
        )

      assert eligible == []
    end

    test "un veto gana a un force" do
      models = [model(:a, provider: :p1, locality: :cloud)]

      {eligible, _filtered, _applied} =
        Rules.apply(
          models,
          [
            rule(%{name: "f", action: :force, target: %{provider: "p1"}}),
            rule(%{name: "v", action: :veto, target: %{locality: "cloud"}})
          ],
          "texto",
          []
        )

      assert eligible == []
    end

    test "el veto se aplica antes que el force aunque la regla venga despues" do
      models = [model(:a, provider: :p1, locality: :cloud)]

      {eligible, filtered, _applied} =
        Rules.apply(
          models,
          [
            rule(%{name: "v", action: :veto, target: %{locality: "cloud"}}),
            rule(%{name: "f", action: :force, target: %{provider: "p1"}})
          ],
          "texto",
          []
        )

      assert eligible == []
      assert filtered == [%{model: :a, reason: :veto}]
    end

    test "un prefer suma su peso a los que casan" do
      models = [model(:a), model(:b)]

      {eligible, _filtered, _applied} =
        Rules.apply(
          models,
          [rule(%{name: "p", action: :prefer, weight: 2.0, target: %{models: ["b"]}})],
          "texto",
          []
        )

      # `prefer` no cambia el conjunto elegible: solo la puntuacion.
      assert Enum.map(eligible, & &1.alias) == [:a, :b]
    end

    test "las reglas de consumer se aplican antes que las globales" do
      models = [model(:a, locality: :cloud), model(:b, locality: :local)]

      {eligible, filtered, applied} =
        Rules.apply(
          models,
          [rule(%{name: "global", action: :veto, target: %{locality: "local"}})],
          "texto",
          [rule(%{name: "consumer", action: :veto, target: %{locality: "cloud"}})]
        )

      assert eligible == []
      # El veto del consumer eliminó :a; el global, después, :b.
      assert filtered == [%{model: :a, reason: :veto}, %{model: :b, reason: :veto}]
      assert applied == ["consumer", "global"]
    end
  end

  describe "preferences/2" do
    test "devuelve el peso acumulado por modelo para las reglas prefer" do
      rules = [
        rule(%{name: "p1", action: :prefer, weight: 2.0, target: %{models: ["a"]}}),
        rule(%{name: "p2", action: :prefer, weight: 1.0, target: %{models: ["a"]}}),
        rule(%{name: "v", action: :veto, target: %{models: ["a"]}})
      ]

      models = [model(:a), model(:b)]

      weights = Rules.preferences(models, rules)

      assert weights[:a] == 3.0
      assert weights[:b] == 0.0
    end
  end
end
