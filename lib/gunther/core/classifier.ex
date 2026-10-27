defmodule Gunther.Classifier do
  @moduledoc """
  Un modelo de decisión especializado (SPEC §5.7, D-68).

  ## Autoridad acotada

  El clasificador **ordena, no juzga** (D-12, D-29): no puede añadir
  candidatos ni quitar los vetados. Su salida se intersecta con el conjunto
  elegible (§6.12, control M1).

  ## Entrada restringida

  `ctx` trae `:consumer`, `:timeout_ms` y `:cancelled?`. **No trae** `chat`,
  `Gunther.chat` ni acceso a la sesión completa. `DecisionView` es el único
  insumo.

  Si falla o expira, la capa se salta con warning `:llm_timeout` o
  `:classifier_error`.

  ## Ejemplos

      iex> Gunther.Classifier.default_context()
      %{consumer: :default, timeout_ms: 1500, cancelled?: nil}
  """

  alias Gunther.DecisionSpec
  alias Gunther.DecisionView

  @callback decision_spec() :: DecisionSpec.t()
  @callback rank(view :: DecisionView.t(), candidates :: [atom()], ctx :: map()) ::
              {:ok, %{ranking: [atom()], confidence: float() | nil}}
              | {:abstain, reason :: atom()}
              | {:error, term()}

  @doc """
  El contexto por defecto que recibe un clasificador.

  ## Ejemplos

      iex> Gunther.Classifier.default_context().consumer
      :default
  """
  @spec default_context() :: map()
  def default_context do
    %{consumer: :default, timeout_ms: 1500, cancelled?: nil}
  end
end
