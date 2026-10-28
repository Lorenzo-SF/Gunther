defmodule Gunther.Cache.Decisions do
  @moduledoc """
  La caché de decisiones (SPEC §6.5, D-55).

  ## Qué se cachea

  Solo el **ranking puro** (lo que producen `:rule`, `:embedding` y `:llm`). La
  **disponibilidad** (breaker, bulkhead, ledger, estado de nodo) se reevalúa
  siempre.

  ## Clave

  `sha256` de la forma canónica de `{consumer, pin, force, firma de requisitos,
  hash del catálogo, último mensaje de usuario normalizado}`.

  La **firma de requisitos** incluye modalidades presentes, `tools`,
  `response_format`, skills pedidas y `rag`.

  El **hash del catálogo** cubre modelos, providers, nodos, **reglas (globales
  y de consumer)**, `DecisionSpec`s y su estado de verificación. Un cambio en
  `[[consumers.*.rules]]` invalida la caché (M-01).

  ## TTL y tope

  `router.cache.ttl_seconds` (300) y `router.cache.max_entries` (10 000) con
  la expulsión LRU de `Gunther.Cache`. Se apaga con `router.cache.enabled =
  false`.

  ## Ejemplos

      iex> Gunther.Cache.Decisions.key(consumer: :default, pin: nil, requirements: %{}, catalog_hash: "abc", text: "hola")
      "0e2b8b3f0a1c9d2e"
  """

  use GenServer

  alias Gunther.Telemetry.Bridge

  @doc """
  Arranca la caché de decisiones.
  """
  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: Keyword.get(opts, :name, __MODULE__))
  end

  @impl GenServer
  def init(opts) do
    # La cache interna es un proceso con nombre propio: las lecturas van
    # directas a su ETS sin pasar por este GenServer.
    cache_name = Keyword.get(opts, :cache_name, __MODULE__.Cache)

    case Gunther.Cache.start_link(
           name: cache_name,
           max_entries: Keyword.get(opts, :max_entries, 10_000),
           ttl_ms: Keyword.get(opts, :ttl_seconds, 300) * 1000
         ) do
      {:ok, pid} ->
        Process.link(pid)
        {:ok, %{cache: pid, cache_name: cache_name}}

      {:error, reason} ->
        {:stop, reason}
    end
  end

  @doc """
  La clave de la caché de decisiones.

  ## Opciones

    * `:consumer` — el consumer
    * `:pin` — el modelo fijado, o `nil`
    * `:force` — si hay un `force` activo
    * `:requirements` — la firma de requisitos
    * `:catalog_hash` — el hash del catálogo
    * `:text` — el último mensaje de usuario normalizado

  ## Ejemplos

      iex> Gunther.Cache.Decisions.key(consumer: :default, pin: nil, requirements: %{}, catalog_hash: "abc", text: "hola")
      "0e2b8b3f0a1c9d2e"
  """
  @spec key(keyword()) :: binary()
  def key(opts) do
    consumer = Keyword.get(opts, :consumer, :default)
    pin = Keyword.get(opts, :pin)
    force = Keyword.get(opts, :force, false)
    requirements = Keyword.get(opts, :requirements, %{})
    catalog_hash = Keyword.get(opts, :catalog_hash, "")
    text = Keyword.get(opts, :text, "")

    {consumer, pin, force, canonical(requirements), catalog_hash, normalize(text)}
    |> :erlang.term_to_binary()
    |> then(&:crypto.hash(:sha256, &1))
    |> Base.encode16(case: :lower)
    |> binary_part(0, 16)
  end

  # La firma de requisitos se ordena para que el mismo conjunto produzca
  # siempre la misma cadena, estee donde este el orden de las claves.
  defp canonical(requirements) when is_map(requirements) do
    Map.new(requirements, fn {key, value} -> {key, canonical_value(value)} end)
  end

  defp canonical(value), do: canonical_value(value)

  defp canonical_value(value) when is_list(value), do: Enum.map(value, &canonical_value/1)
  defp canonical_value(value) when is_map(value), do: canonical(value)
  defp canonical_value(value), do: value

  defp normalize(text) when is_binary(text), do: String.downcase(String.trim(text))
  defp normalize(text), do: text

  @doc """
  Lee un ranking cacheado.

  ## Ejemplos

      iex> Gunther.Cache.Decisions.get("clave-inexistente")
      :error
  """
  @spec get(binary()) :: {:ok, [atom()]} | :error
  def get(key) do
    case Gunther.Cache.get(cache(), key) do
      {:ok, ranking} ->
        Bridge.router_cache_event(:cache_hit, key)
        {:ok, ranking}

      :error ->
        Bridge.router_cache_event(:cache_miss, key)
        :error
    end
  end

  @doc """
  Guarda un ranking.

  ## Ejemplos

      iex> Gunther.Cache.Decisions.put("clave", [:a, :b])
      :ok
  """
  @spec put(binary(), [atom()]) :: :ok
  def put(key, ranking) do
    Gunther.Cache.put(cache(), key, ranking)
  end

  @doc """
  Vacía la caché. Lo llama `Catalog.reload/0` (SPEC §6.5).
  """
  @spec clear() :: :ok
  def clear do
    Gunther.Cache.clear(cache())
  end

  defp cache do
    GenServer.call(__MODULE__, :cache)
  end

  @impl GenServer
  def handle_call(:cache, _from, state), do: {:reply, state.cache, state}
end
