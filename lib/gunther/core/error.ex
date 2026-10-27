defmodule Gunther.Error do
  @moduledoc """
  El contrato de errores de Gunther (SPEC §4.13).

  Todos los errores son **valores**, no excepciones. El framework solo lanza
  si está roto (config inválida al arrancar).

  ## Códigos

  El código es un `atom()`. Los que tienen equivalencia HTTP son:

  | HTTP | Códigos |
  | ---- | ------- |
  | 400  | `:invalid_request`, `:tool_not_found`, `:tool_invalid_arguments` |
  | 402  | `:budget_exceeded`, `:budget_exhausted` |
  | 403  | `:tool_denied`, `:board_forbidden` |
  | 404  | `:session_not_found`, `:prompt_not_found`, `:eval_corpus_not_found` |
  | 409  | `:tool_confirmation_required`, `:version_conflict` |
  | 410  | `:session_closed` |
  | 422  | `:invalid_structured_output`, `:guardrail_input_veto`, `:guardrail_output_veto`, `:context_overflow`, `:result_too_large`, `:board_full`, `:invalid_plan_fragment` |
  | 429  | `:rate_limited` |
  | 499  | `:cancelled` |
  | 500  | `:config_error`, `:tool_error`, `:store_error`, `:embedder_error`, `:chunker_error`, `:retriever_error`, `:reranker_error`, `:guardrail_error`, `:command_failed`, `:command_blocked`, `:internal_error` |
  | 502  | `:mcp_connection_failed`, `:mcp_protocol_error`, `:node_protocol_error` |
  | 503  | `:no_candidates`, `:no_model_available`, `:overloaded`, `:refused_capacity`, `:refused_timeout`, `:provider_unavailable`, `:bulkhead_full`, `:too_many_sessions`, `:too_many_agents`, `:no_gpu`, `:memory_unknown`, `:gpu_layers_fixed`, `:no_room`, `:node_unreachable`, `:node_auth_failed`, `:device_unusable`, `:mailbox_full` |
  | 504  | `:timeout` |

  `:provider_error` usa el código HTTP del backend. `:stream_interrupted` y
  `:classifier_error` no tienen equivalente HTTP.

  Un código que no esté en esta tabla es `:internal_error` y hay que añadirlo.

  ## `retryable?`

  Es `true` para: `:no_model_available`, `:overloaded`, `:provider_unavailable`,
  `:bulkhead_full`, `:refused_timeout`, `:rate_limited`, `:too_many_sessions`,
  `:too_many_agents`, `:mcp_connection_failed`, `:stream_interrupted`,
  `:timeout`, `:memory_unknown`, `:no_room`, `:node_unreachable`,
  `:device_unusable`.

  Depende del backend en: `:provider_error`, `:store_error`, `:embedder_error`,
  `:retriever_error`, `:tool_error`, `:command_failed`.

  Es `false` en el resto, incluidos `:node_auth_failed` (no se resuelve
  reintentando) y `:tool_confirmation_required`.
  """

  @type code :: atom()
  @type t :: %__MODULE__{
          code: code(),
          message: binary(),
          retryable?: boolean(),
          retry_after_ms: non_neg_integer() | nil,
          details: map(),
          cause: term() | nil
        }

  @enforce_keys [:code, :message]
  defstruct [:code, :message, :retryable?, :retry_after_ms, details: %{}, cause: nil]

  @doc """
  Construye un error.

  ## Ejemplos

      iex> Gunther.Error.new(:timeout, "deadline exceeded")
      %Gunther.Error{code: :timeout, message: "deadline exceeded", retryable?: true, retry_after_ms: nil, details: %{}, cause: nil}
  """
  @spec new(code(), binary(), keyword()) :: t()
  def new(code, message, opts \\ []) when is_atom(code) and is_binary(message) do
    %__MODULE__{
      code: code,
      message: message,
      retryable?: Keyword.get(opts, :retryable?, default_retryable?(code)),
      retry_after_ms: Keyword.get(opts, :retry_after_ms),
      details: Keyword.get(opts, :details, %{}),
      cause: Keyword.get(opts, :cause)
    }
  end

  @doc """
  Dice si el error se puede reintentar.

  Los errores de backend (`:provider_error`, `:store_error`,
  `:embedder_error`, `:retriever_error`, `:tool_error`, `:command_failed`)
  dependen del backend, asi que el valor por defecto es `false` y quien lo
  devuelve decide.

  ## Ejemplos

      iex> Gunther.Error.retryable?(%Gunther.Error{code: :overloaded, message: "x"})
      true

      iex> Gunther.Error.retryable?(%Gunther.Error{code: :node_auth_failed, message: "x"})
      false
  """
  @spec retryable?(t()) :: boolean()
  def retryable?(%__MODULE__{retryable?: value}) when is_boolean(value), do: value
  def retryable?(%__MODULE__{code: code}), do: default_retryable?(code)

  @always_retryable [
    :no_model_available,
    :overloaded,
    :provider_unavailable,
    :bulkhead_full,
    :refused_timeout,
    :rate_limited,
    :too_many_sessions,
    :too_many_agents,
    :mcp_connection_failed,
    :stream_interrupted,
    :timeout,
    :memory_unknown,
    :no_room,
    :node_unreachable,
    :device_unusable
  ]

  @backend_dependent [
    :provider_error,
    :store_error,
    :embedder_error,
    :retriever_error,
    :tool_error,
    :command_failed
  ]

  defp default_retryable?(code) when code in @always_retryable, do: true
  defp default_retryable?(code) when code in @backend_dependent, do: false
  defp default_retryable?(_code), do: false

  @doc """
  El código HTTP equivalente, si lo tiene.

  `:provider_error` y `:stream_interrupted` no tienen uno fijo.

  ## Ejemplos

      iex> Gunther.Error.http_status(%Gunther.Error{code: :timeout, message: "x"})
      504

      iex> Gunther.Error.http_status(%Gunther.Error{code: :stream_interrupted, message: "x"})
      nil
  """
  @spec http_status(t()) :: pos_integer() | nil
  def http_status(%__MODULE__{code: code}) do
    case http_status_for(code) do
      nil -> nil
      status -> status
    end
  end

  @doc """
  El conjunto de códigos conocidos, agrupados por HTTP.

  ## Ejemplos

      iex> Gunther.Error.codes()[504]
      [:timeout]
  """
  @spec codes() :: %{pos_integer() => [code()]}
  def codes do
    %{
      400 => [:invalid_request, :tool_not_found, :tool_invalid_arguments],
      402 => [:budget_exceeded, :budget_exhausted],
      403 => [:tool_denied, :board_forbidden],
      404 => [:session_not_found, :prompt_not_found, :eval_corpus_not_found],
      409 => [:tool_confirmation_required, :version_conflict],
      410 => [:session_closed],
      422 => [
        :invalid_structured_output,
        :guardrail_input_veto,
        :guardrail_output_veto,
        :context_overflow,
        :result_too_large,
        :board_full,
        :invalid_plan_fragment
      ],
      429 => [:rate_limited],
      499 => [:cancelled],
      500 => [
        :config_error,
        :tool_error,
        :store_error,
        :embedder_error,
        :chunker_error,
        :retriever_error,
        :reranker_error,
        :guardrail_error,
        :command_failed,
        :command_blocked,
        :internal_error
      ],
      502 => [:mcp_connection_failed, :mcp_protocol_error, :node_protocol_error],
      503 => [
        :no_candidates,
        :no_model_available,
        :overloaded,
        :refused_capacity,
        :refused_timeout,
        :provider_unavailable,
        :bulkhead_full,
        :too_many_sessions,
        :too_many_agents,
        :no_gpu,
        :memory_unknown,
        :gpu_layers_fixed,
        :no_room,
        :node_unreachable,
        :node_auth_failed,
        :device_unusable,
        :mailbox_full
      ],
      504 => [:timeout]
    }
  end

  @doc """
  El conjunto de códigos conocidos, en una lista.

  ## Ejemplos

      iex> :timeout in Gunther.Error.all_codes()
      true
  """
  @spec all_codes() :: [code()]
  def all_codes do
    codes()
    |> Map.values()
    |> List.flatten()
  end

  defp http_status_for(code) do
    Enum.find_value(codes(), fn {status, list} -> if code in list, do: status end)
  end

  @doc """
  Traduce un error ajeno a un `Gunther.Error`.

  Un `%Gunther.Error{}` se devuelve tal cual. Un átomo conocido se convierte
  en error con ese código. Cualquier otra cosa es `:internal_error`.

  ## Ejemplos

      iex> Gunther.Error.from(:timeout)
      %Gunther.Error{code: :timeout, message: "timeout", retryable?: true, retry_after_ms: nil, details: %{}, cause: nil}

      iex> Gunther.Error.from(:inventado)
      %Gunther.Error{code: :internal_error, message: "inventado", retryable?: false, retry_after_ms: nil, details: %{}, cause: :inventado}
  """
  @spec from(term()) :: t()
  def from(%__MODULE__{} = error), do: error

  def from(code) when is_atom(code) do
    if code in all_codes() do
      %__MODULE__{code: code, message: Atom.to_string(code), retryable?: default_retryable?(code)}
    else
      %__MODULE__{code: :internal_error, message: Atom.to_string(code), retryable?: false, cause: code}
    end
  end

  def from(other) do
    %__MODULE__{code: :internal_error, message: "internal_error", retryable?: false, cause: other}
  end
end
