defmodule Gunther.Resilience.Pipeline do
  @moduledoc """
  El pipeline ejecutable de resiliencia (SPEC §2.5, CE-12, CE-13).

  Es la orquestacion de las seis capas de §2.5: retry, rate limit, bulkhead,
  circuit breaker, timeout de intento y la llamada. Las tres primeras
  viven en `Arrea` y en `Gunther.Resilience.Supervisor`; este modulo las
  encadena y aplica el **presupuesto de tiempo**.

  ## El presupuesto de tiempo (CE-12)

  `opts.timeout` es el plazo **total** de la petición: retries, failovers y
  structured retries incluidos. Al empezar se fija
  `deadline = monotonic_now + timeout`, y cada intento recibe
  `min(attempt_timeout_ms, deadline − now)`. Si `deadline − now ≤ 0`, el
  resultado es `{:error, :timeout}`. Un backoff nunca duerme mas que
  `deadline − now`.

  ## El fallo (CE-13)

  La tabla de §2.5 decide, para cada error, si se reintenta, si pasa a otro
  candidato y si cuenta en el breaker. `Gunther.Resilience` tiene esa tabla;
  aqui se aplica.

  ## Ejemplos

      iex> Gunther.Resilience.Pipeline.call(fn _attempt -> {:ok, :respuesta} end, [timeout: 5_000], [])
      {:ok, :respuesta}
  """

  alias Gunther.Error
  alias Gunther.Resilience

  @type opts :: [
          timeout: pos_integer(),
          attempt_timeout_ms: pos_integer(),
          max_attempts: pos_integer(),
          max_failovers: non_neg_integer(),
          base_ms: non_neg_integer(),
          cap_ms: non_neg_integer()
        ]

  @doc """
  Ejecuta `fun` con el pipeline de resiliencia.

  `fun` recibe el numero de intento (empezando en uno) y el presupuesto de
  tiempo que le queda, en milisegundos. Devuelve `{:ok, resultado}` o
  `{:error, codigo}`.

  `fallbacks` son los candidatos alternativos: si el error admite failover,
  se prueban en orden hasta agotar `max_failovers`.

  ## Ejemplos

      iex> Gunther.Resilience.Pipeline.call(fn _attempt -> {:error, :invalid_request} end, [timeout: 1_000], [])
      {:error, %Gunther.Error{code: :invalid_request, message: "peticion invalida", retryable?: false, retry_after_ms: nil, details: %{original: :invalid_request}, cause: nil}}
  """
  @spec call((pos_integer(), non_neg_integer() -> {:ok, term()} | {:error, term()}), opts(), [term()]) ::
          {:ok, term()} | {:error, Error.t()}
  def call(fun, opts, fallbacks \\ []) do
    timeout = Keyword.get(opts, :timeout, 30_000)
    deadline = System.monotonic_time(:millisecond) + timeout

    attempt_candidates(fun, opts, fallbacks, deadline, [])
  end

  # El candidato actual se intenta primero; los `fallbacks` van despues, y
  # solo si el error admite failover y queda margen.
  defp attempt_candidates(fun, opts, fallbacks, deadline, used_failovers) do
    case attempt_with_retries(fun, opts, deadline) do
      {:ok, result} ->
        {:ok, result}

      {:error, error} ->
        cond do
          # Un error que no admite failover se queda: no hay a donde ir.
          not Resilience.failover?(error.code) ->
            {:error, error}

          # Quedan candidatos y margen de failover: se pasa al siguiente.
          match?([_first | _rest], fallbacks) and
              length(used_failovers) < Keyword.get(opts, :max_failovers, 2) ->
            [_next | rest] = fallbacks
            attempt_candidates(fun, opts, rest, deadline, [:failed | used_failovers])

          true ->
            {:error, error}
        end
    end
  end

  # Los reintentos de un mismo candidato.
  defp attempt_with_retries(fun, opts, deadline) do
    max_attempts = Keyword.get(opts, :max_attempts, 3)
    attempt_timeout = Keyword.get(opts, :attempt_timeout_ms, 30_000)
    base_ms = Keyword.get(opts, :base_ms, 200)
    cap_ms = Keyword.get(opts, :cap_ms, 5_000)

    do_attempts(fun, 1, max_attempts, attempt_timeout, base_ms, cap_ms, deadline)
  end

  defp do_attempts(fun, attempt, max_attempts, attempt_timeout, base_ms, cap_ms, deadline) do
    remaining = deadline - System.monotonic_time(:millisecond)

    if remaining <= 0 do
      {:error, Error.new(:timeout, "se agoto el plazo de la peticion")}
    else
      budget = min(attempt_timeout, remaining)

      case fun.(attempt, budget) do
        {:ok, result} ->
          {:ok, result}

        {:error, reason} ->
          handle_failure(
            fun,
            to_error(reason),
            attempt,
            max_attempts,
            attempt_timeout,
            base_ms,
            cap_ms,
            deadline
          )
      end
    end
  end

  # Que se hace con un error de un intento: reintentar, o devolver.
  defp handle_failure(fun, error, attempt, max_attempts, attempt_timeout, base_ms, cap_ms, deadline) do
    cond do
      not Resilience.retryable?(error.code) ->
        {:error, error}

      attempt >= max_attempts ->
        {:error, error}

      true ->
        retry_after_wait(fun, error, attempt, max_attempts, attempt_timeout, base_ms, cap_ms, deadline)
    end
  end

  # El retraso antes del siguiente intento. Si no cabe en el plazo que
  # queda, no se reintenta: es preferible fallar que reintentar sin tiempo.
  defp retry_after_wait(fun, error, attempt, max_attempts, attempt_timeout, base_ms, cap_ms, deadline) do
    case wait_ms(error, attempt, base_ms, cap_ms, deadline) do
      :no_time ->
        {:error, error}

      wait ->
        Process.sleep(wait)
        do_attempts(fun, attempt + 1, max_attempts, attempt_timeout, base_ms, cap_ms, deadline)
    end
  end

  # El retraso antes del siguiente intento.
  #
  # Un `retry_after` del servicio **manda** sobre el backoff: si el servidor
  # dice que espere 120 ms, esperar 200 ms de backoff seria disrespectful y
  # esperar menos seria reintentar antes de tiempo. Si el `retry_after` no
  # cabe en el plazo que queda, no se reintenta.
  defp wait_ms(error, attempt, base_ms, cap_ms, deadline) do
    remaining = deadline - System.monotonic_time(:millisecond)

    case error.retry_after_ms do
      nil ->
        backoff = Resilience.backoff_ms(attempt, base_ms, cap_ms, remaining)
        if backoff > remaining, do: :no_time, else: backoff

      retry_after ->
        if retry_after > remaining, do: :no_time, else: retry_after
    end
  end

  # Los errores son valores (SPEC §4.13). Un codigo que no este en la tabla
  # es `:internal_error`.
  defp to_error(%Error{} = error), do: error

  defp to_error({:rate_limited, retry_after_ms}) when is_integer(retry_after_ms) do
    Error.new(:rate_limited, "el proveedor limita la tasa",
      retry_after_ms: retry_after_ms,
      details: %{retry_after_ms: retry_after_ms}
    )
  end

  defp to_error(code) when is_atom(code) do
    # §4.13: un codigo que no este en la tabla es `:internal_error` y hay que
    # anadirlo. Un codigo desconocido no se reintenta ni se propaga tal cual.
    if code in Error.all_codes() do
      Error.new(code, message_for(code), details: %{original: code})
    else
      Error.new(:internal_error, "codigo de error desconocido: #{inspect(code)}", details: %{original: code})
    end
  end

  defp to_error(other) do
    Error.new(:internal_error, "error no reconocido", details: %{original: other})
  end

  defp message_for(:timeout), do: "se agoto el tiempo de espera"
  defp message_for(:rate_limited), do: "el proveedor limita la tasa"
  defp message_for(:provider_unavailable), do: "el proveedor no esta disponible"
  defp message_for(:overloaded), do: "el proveedor esta saturado"
  defp message_for(:bulkhead_full), do: "no hay hueco para esta llamada"
  defp message_for(:node_unreachable), do: "el nodo no responde"
  defp message_for(:no_model_available), do: "no hay modelo disponible"
  defp message_for(:invalid_request), do: "peticion invalida"
  defp message_for(:invalid_structured_output), do: "la salida no cumple el esquema"
  defp message_for(:stream_interrupted), do: "la respuesta se corto"
  defp message_for(:cancelled), do: "la peticion se cancelo"
  defp message_for(code), do: "error: #{code}"
end
