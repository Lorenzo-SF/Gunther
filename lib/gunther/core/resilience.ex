defmodule Gunther.Resilience do
  @moduledoc """
  El pipeline de resiliencia de §2.5 (SPEC §2.5, D-51, D-52).

  ## Orden de fuera a dentro

  | #   | Capa               | Primitiva                                     |
  | --- | ------------------ | --------------------------------------------- |
  | 1   | Retry              | `Apero.Retry` (backoff exponencial con jitter) |
  | 2   | Rate limit         | `Arrea.RateLimiter` por provider                |
  | 3   | Bulkhead           | `Arrea.Bulkhead` por modelo                     |
  | 4   | Circuit breaker    | `Arrea.CircuitBreaker` por provider             |
  | 5   | Timeout de intento | `retry.attempt_timeout_ms`                     |
  | 6   | Llamada            | `Provider.chat/2` o `stream/3`                  |

  ## Presupuesto de tiempo (CE-12)

  `opts.timeout` es el **plazo total** de la petición. Al empezar se fija
  `deadline = monotonic_now + timeout`. Cada intento recibe
  `min(retry.attempt_timeout_ms, deadline − now)`. Si `deadline − now ≤ 0`,
  `{:error, :timeout}`. Un backoff nunca duerme más de `deadline − now`.

  ## G-05: rama B

  `Apero.Retry` **no** admite `retry_after_ms` (medido contra el código
  publicado de `apero` 4.1.0: `Apero.Retry.with/2` solo expone `retry_on` como
  predicado). Por eso el reintento con espera exacta se implementa aquí, en el
  módulo de frontera, y `Apero.Retry` no se usa.

  ## Ejemplos

      iex> Gunther.Resilience.retryable?(:timeout)
      true
  """

  alias Gunther.Error

  @always_retryable [
    :timeout,
    :node_unreachable,
    :provider_unavailable,
    :stream_interrupted,
    :connection_error
  ]

  @doc """
  ¿Este error se reintenta?

  La tabla completa está en §2.5 (CE-13). Un error que no esté en ella es
  `:internal_error` y no se reintenta.

  ## Ejemplos

      iex> Gunther.Resilience.retryable?(:timeout)
      true

      iex> Gunther.Resilience.retryable?(:invalid_request)
      false
  """
  @spec retryable?(atom()) :: boolean()
  def retryable?(code) when code in @always_retryable, do: true

  def retryable?(code) when is_atom(code) do
    %Error{retryable?: value} = Error.new(code, "x")
    value
  end

  def retryable?(_code), do: false

  @doc """
  ¿Este error hace failover al siguiente candidato?

  ## Ejemplos

      iex> Gunther.Resilience.failover?(:timeout)
      true

      iex> Gunther.Resilience.failover?(:invalid_request)
      false
  """
  @spec failover?(atom()) :: boolean()
  def failover?(code) when code in @always_retryable, do: true
  def failover?(:bulkhead_full), do: true
  def failover?(:rate_limited), do: true
  def failover?(:provider_unavailable), do: true
  def failover?(:invalid_structured_output), do: true
  def failover?(_code), do: false

  @doc """
  ¿Este error cuenta en el circuit breaker?

  ## Ejemplos

      iex> Gunther.Resilience.counts_in_breaker?(:timeout)
      true

      iex> Gunther.Resilience.counts_in_breaker?(:rate_limited)
      false
  """
  @spec counts_in_breaker?(atom()) :: boolean()
  def counts_in_breaker?(code) when code in @always_retryable, do: true
  def counts_in_breaker?(:invalid_structured_output), do: false
  def counts_in_breaker?(_code), do: false

  @doc """
  El nombre del breaker de un provider, con el prefijo de instancia.

  Los nombres de Arrea son globales, asi que el prefijo aisla dos instancias
  de Gunther en la misma VM (SPEC §2.7).

  ## Ejemplos

      iex> Gunther.Resilience.breaker_name(:main, :openai)
      {Gunther, :main, :breaker, :openai}
  """
  @spec breaker_name(atom(), atom()) :: tuple()
  def breaker_name(instance, provider) do
    {Gunther, instance, :breaker, provider}
  end

  @doc """
  El nombre del bulkhead de un modelo.

  ## Ejemplos

      iex> Gunther.Resilience.bulkhead_name(:main, :qwen)
      {Gunther, :main, :bulkhead, :qwen}
  """
  @spec bulkhead_name(atom(), atom()) :: tuple()
  def bulkhead_name(instance, model) do
    {Gunther, instance, :bulkhead, model}
  end

  @doc """
  El nombre del rate limiter de un provider.

  ## Ejemplos

      iex> Gunther.Resilience.rate_limiter_name(:main, :openai)
      {Gunther, :main, :rate_limiter, :openai}
  """
  @spec rate_limiter_name(atom(), atom()) :: tuple()
  def rate_limiter_name(instance, provider) do
    {Gunther, instance, :rate_limiter, provider}
  end

  @doc """
  Asegura que exista el breaker de un provider.

  ## G-02: rama A

  `Arrea.CircuitBreaker` **admite umbrales por breaker**: `validate_opts/1`
  acepta `:threshold` y `:timeout` en las opciones de cada instancia
  (medido contra `arrea` 3.1.0, `lib/arrea/circuit_breaker/circuit_breaker.ex`).
  Cada provider puede tener su propio umbral.

  ## G-03: rama A

  El half-open hace **una sola sonda**: el codigo de `arrea`.single-flight` en
  `:half_open` deja pasar solo al primer llamante.

  ## Opciones

    * `:instance` — la instancia de Gunther (por defecto `:main`)
    * `:threshold` — fallos consecutivos antes de abrir (por defecto 10)
    * `:timeout` — duracion abierta en ms (por defecto 30 000)

  ## Ejemplos

      iex> {:ok, pid} = Gunther.Resilience.ensure_breaker(:openai, %{})
      iex> is_pid(pid)
      true
  """
  @spec ensure_breaker(atom(), map()) :: {:ok, pid()} | {:error, term()}
  def ensure_breaker(provider, config) do
    instance = Map.get(config, :instance, :main)
    name = breaker_name(instance, provider)
    threshold = Map.get(config, :threshold, 10)
    timeout = Map.get(config, :timeout, 30_000)

    case Arrea.CircuitBreaker.start_link(
           name: name,
           threshold: threshold,
           timeout: timeout
         ) do
      {:ok, pid} ->
        {:ok, pid}

      {:error, {:already_started, pid}} ->
        {:ok, pid}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Calcula el tiempo de espera del siguiente reintento.

  Backoff exponencial con jitter, acotado por `cap_ms` y **nunca** por encima
  del plazo que queda.

  ## Ejemplos

      iex> Gunther.Resilience.backoff_ms(1, 200, 5000, 10_000)
      200
  """
  @spec backoff_ms(pos_integer(), pos_integer(), pos_integer(), non_neg_integer()) :: non_neg_integer()
  def backoff_ms(attempt, base_ms, cap_ms, remaining_ms) when attempt >= 1 do
    raw = base_ms * Integer.pow(2, attempt - 1)
    capped = min(raw, cap_ms)
    # El backoff no se limita por lo que queda en negativo: si no queda
    # plazo, el backoff es 0 y quien decide es el pipeline (que no reintenta
    # sin margen). Un retraso negativo reventaria con `Process.sleep/1`.
    min(capped, max(remaining_ms, 0))
  end
end
