defmodule Gunther.Response do
  @moduledoc """
  La respuesta de una inferencia (SPEC §4.2).

  ## `degraded`

  Es `true` si `Decision.degraded` no está vacío **o** hay algún warning con
  `code` en `[:degraded, :failover, :llm_timeout, :classifier_error,
  :classifier_unverified, :embedding_unavailable, :structured_fallback]`.

  `:context_compacted`, `:guardrail_modified` y `:empty_response` **no**
  cuentan: el consumidor distingue «respondió bien» de «respondió degradado»
  sin inspeccionar los warnings.

  ## Ejemplos

      iex> Gunther.Response.new(%{content: "hola", model: :m, provider: :p})
      %Gunther.Response{content: "hola", model: :m, provider: :p, node: nil, usage: %{input: 0, output: 0, cached_input: nil, reasoning: nil}, finish_reason: :stop, reasoning: nil, tool_calls: nil, structured: nil, session: nil, trace: nil, warnings: [], degraded: false, latency_ms: 0, cost: nil, cache_hit: false, provider_request_id: nil}
  """

  @type finish_reason :: :stop | :length | :tool_calls | :content_filter | :error

  @type usage :: %{
          input: non_neg_integer(),
          output: non_neg_integer(),
          cached_input: non_neg_integer() | nil,
          reasoning: non_neg_integer() | nil
        }

  @type cost :: %{
          input_micros: non_neg_integer(),
          output_micros: non_neg_integer(),
          total_micros: non_neg_integer()
        }

  @type warning :: %{code: atom(), message: binary(), details: map()}

  @type t :: %__MODULE__{
          content: binary(),
          model: atom(),
          provider: atom(),
          node: atom() | nil,
          usage: usage(),
          finish_reason: finish_reason(),
          reasoning: binary() | nil,
          tool_calls: [%{id: binary(), name: binary(), arguments: map()}] | nil,
          structured: term() | nil,
          session: binary() | nil,
          trace: map() | nil,
          warnings: [warning()],
          degraded: boolean(),
          latency_ms: non_neg_integer(),
          cost: cost() | nil,
          cache_hit: boolean(),
          provider_request_id: binary() | nil
        }

  @enforce_keys [:content, :model, :provider]
  defstruct content: "",
            model: nil,
            provider: nil,
            node: nil,
            usage: %{input: 0, output: 0, cached_input: nil, reasoning: nil},
            finish_reason: :stop,
            reasoning: nil,
            tool_calls: nil,
            structured: nil,
            session: nil,
            trace: nil,
            warnings: [],
            degraded: false,
            latency_ms: 0,
            cost: nil,
            cache_hit: false,
            provider_request_id: nil

  @degrading_codes [
    :degraded,
    :failover,
    :llm_timeout,
    :classifier_error,
    :classifier_unverified,
    :embedding_unavailable,
    :structured_fallback
  ]

  @doc """
  Construye una respuesta y calcula `degraded` a partir de los warnings.

  ## Ejemplos

      iex> Gunther.Response.new(%{content: "x", model: :m, provider: :p, warnings: [%{code: :failover, message: "m", details: %{}}]}).degraded
      true

      iex> Gunther.Response.new(%{content: "x", model: :m, provider: :p, warnings: [%{code: :context_compacted, message: "m", details: %{}}]}).degraded
      false
  """
  @spec new(map()) :: t()
  def new(attrs) do
    warnings = Map.get(attrs, :warnings, [])

    response = struct!(__MODULE__, attrs)

    %{response | degraded: response.degraded or degrades?(warnings)}
  end

  @doc """
  Dice si una lista de warnings marca la respuesta como degradada.

  ## Ejemplos

      iex> Gunther.Response.degrades?([%{code: :empty_response, message: "m", details: %{}}])
      false
  """
  @spec degrades?([warning()]) :: boolean()
  def degrades?(warnings) when is_list(warnings) do
    Enum.any?(warnings, fn warning -> warning.code in @degrading_codes end)
  end

  def degrades?(_warnings), do: false

  @doc """
  Los códigos de warning que degradan la respuesta.

  ## Ejemplos

      iex> :failover in Gunther.Response.degrading_codes()
      true
  """
  @spec degrading_codes() :: [atom()]
  def degrading_codes, do: @degrading_codes
end
