defmodule Gunther.Router.LlmTest do
  use ExUnit.Case, async: true

  alias Gunther.DecisionSpec
  alias Gunther.Provider.Mock
  alias Gunther.Router.Llm

  defp spec(attrs \\ []) do
    DecisionSpec.new(
      Map.merge(
        %{
          id: :router,
          kind: :preference_router,
          model: :decisor,
          routes: %{
            code: %{description: "Programacion", models: [:a]},
            vision: %{description: "Imagenes", models: [:b]}
          },
          verification: :active
        },
        Map.new(attrs)
      )
    )
  end

  defp model(alias) do
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
    }
  end

  defp candidates, do: [model(:a), model(:b)]

  defp messages, do: [%{role: :user, content: "arregla este bug"}]

  defp opts(extra \\ []) do
    Keyword.merge(
      [
        provider: Mock,
        model_id: "decisor",
        timeout_ms: 1_000
      ],
      extra
    )
  end

  describe "rank/4" do
    test "sin spec la capa no existe" do
      assert {:skip, :no_spec, []} = Llm.rank(candidates(), messages(), nil, opts())
    end

    test "un spec sin verificar no acts" do
      assert {:skip, :unverified, [:classifier_unverified]} =
               Llm.rank(candidates(), messages(), spec(verification: :unverified), opts())
    end

    test "con allow_unverified el spec sin verificar actua" do
      spec = spec(verification: :unverified)

      assert {:ok, _ranking, _info} =
               Llm.rank(
                 candidates(),
                 messages(),
                 spec,
                 opts(allow_unverified: true, provider: Gunther.Router.LlmTest.Echo, echo: ~s({"route": "code"}))
               )
    end

    test "la ruta elegida da el ranking" do
      spec = spec()

      assert {:ok, [:a, :b], _info} =
               Llm.rank(
                 candidates(),
                 messages(),
                 spec,
                 opts(provider: Gunther.Router.LlmTest.Echo)
               )
    end

    test "una ruta desconocida es una abstension" do
      spec = spec()

      assert {:skip, :invalid_output, []} =
               Llm.rank(
                 candidates(),
                 messages(),
                 spec,
                 opts(provider: Gunther.Router.LlmTest.EchoUnknown)
               )
    end

    test "una salida que no es JSON es una abstension" do
      spec = spec()

      assert {:skip, :invalid_output, []} =
               Llm.rank(
                 candidates(),
                 messages(),
                 spec,
                 opts(provider: Gunther.Router.LlmTest.EchoInvalid)
               )
    end

    test "la ruta other con other: :abstain se abstiene" do
      spec = spec(other: :abstain)

      assert {:skip, :abstain, []} =
               Llm.rank(
                 candidates(),
                 messages(),
                 spec,
                 opts(provider: Gunther.Router.LlmTest.EchoOther)
               )
    end

    test "una ruta con modelos que no son elegibles se abstiene" do
      spec = spec(routes: %{code: %{description: "Programacion", models: [:fuera]}})

      assert {:skip, :abstain, []} =
               Llm.rank(
                 candidates(),
                 messages(),
                 spec,
                 opts(provider: Gunther.Router.LlmTest.Echo)
               )
    end

    test "la informacion lleva el modelo y el hash de lo que vio" do
      spec = spec(report_id: "rep-1")

      assert {:ok, _ranking, info} =
               Llm.rank(
                 candidates(),
                 messages(),
                 spec,
                 opts(provider: Gunther.Router.LlmTest.Echo)
               )

      assert info.id == :router
      assert info.kind == :preference_router
      assert info.report_id == "rep-1"
      assert is_binary(info.decision_input_sha256)
    end

    test "un timeout deja el aviso :llm_timeout" do
      spec = spec()

      assert {:skip, :timeout, [:llm_timeout]} =
               Llm.rank(candidates(), messages(), spec, opts(provider: Mock, mock: %{delay_ms: 2_000}, timeout_ms: 50))
    end

    test "un provider que falla deja el aviso :classifier_error" do
      spec = spec()

      assert {:skip, :reventado, [:classifier_error]} =
               Llm.rank(candidates(), messages(), spec, opts(provider: Gunther.Router.LlmTest.EchoBroken))
    end

    test "el prompt lleva las rutas y el texto al final" do
      spec = spec()
      view = Gunther.DecisionView.from_messages(messages(), [:user])
      prompt = Gunther.Decision.Prompt.render(spec.prompt, spec, view)

      assert prompt =~ "code: Programacion"
      assert prompt =~ "vision: Imagenes"
      assert prompt |> String.trim() |> String.ends_with?("arregla este bug")
    end

    test "el decisor no ve el contenido de assistant" do
      spec = spec()
      view = Gunther.DecisionView.from_messages(messages(), [:user])

      assert view.text == "arregla este bug"
    end
  end

  # Un provider por respuesta. Gunther no filtra opciones arbitrarias al
  # provider, asi que cada respuesta es un modulo.
  defmodule Echo do
    def chat(_messages, _opts) do
      {:ok, %{content: ~s({"route": "code"}), finish_reason: :stop, usage: %{}}}
    end
  end

  defmodule EchoUnknown do
    def chat(_messages, _opts) do
      {:ok, %{content: ~s({"route": "inventada"}), finish_reason: :stop, usage: %{}}}
    end
  end

  defmodule EchoOther do
    def chat(_messages, _opts) do
      {:ok, %{content: ~s({"route": "other"}), finish_reason: :stop, usage: %{}}}
    end
  end

  defmodule EchoInvalid do
    def chat(_messages, _opts) do
      {:ok, %{content: "no soy json", finish_reason: :stop, usage: %{}}}
    end
  end

  defmodule EchoBroken do
    def chat(_messages, _opts), do: {:error, :reventado}
  end
end
