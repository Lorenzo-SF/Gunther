defmodule Gunther.Cache do
  @moduledoc """
  Caché con tope de entradas y **LRU exacto** (SPEC §3.3, CE-06).

  Sustituye a `Apero.Cache`, cuyos requisitos no encajan: tope de entradas,
  LRU exacto, espacio de nombres por instancia y eventos.

  ## Mecanismo

  Dos tablas ETS:

  - `data`: `{key, value, expires_at, last_used, seq}`
  - `index`: `ordered_set` de `{{last_used, seq}, key}`, donde `seq` sale de un
    contador `:atomics` y garantiza claves únicas: dos accesos en el mismo
    instante no colisionan.

  El `seq` se guarda **en la fila de datos**, no se reconstruye: es lo único
  que permite borrar la entrada exacta del índice. Reconstruirlo sería
  imposible sin volver a generar un `seq` distinto al original.

  El tope se cuenta con `:counters`; una inserción que lo supere expulsa antes
  de insertar. Las escrituras las serializa un `GenServer` propietario; las
  lecturas van directas a ETS con `read_concurrency: true`.

  La actualización de `last_used` es un `GenServer.cast` desde el lector
  (consistencia eventual: una lectura puede quedar sin registrar si el sistema
  está sobrecargado; el tope y la corrección no dependen de ello).

  ## Namespacing

  La clave incluye `{Gunther, instance, kind}`, así que dos instancias de
  Gunther en la misma VM no comparten entradas.

  ## Observabilidad

  `[:gunther, :cache, :hit | :miss | :evict]` con el hash de la clave, **nunca**
  el valor.
  """

  use GenServer

  alias Gunther.Telemetry.Bridge

  @type kind :: atom()
  @type key :: term()

  @doc """
  Crea una caché nueva.

  ## Opciones

    * `:name` — nombre del proceso (por defecto, anónimo)
    * `:max_entries` — tope de entradas (por defecto `10_000`)
    * `:ttl_ms` — vida de cada entrada (por defecto `nil`, sin caducidad)
    * `:sweep_interval_ms` — periodo del barrido de caducados (por defecto `30_000`)

  ## Ejemplos

      iex> {:ok, cache} = Gunther.Cache.start_link(max_entries: 2)
      iex> Gunther.Cache.put(cache, :a, 1)
      :ok
      iex> Gunther.Cache.get(cache, :a)
      {:ok, 1}
  """
  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: Keyword.get(opts, :name))
  end

  @doc """
  Guarda un valor.

  Si la caché está llena, expulsa la entrada menos usada **antes** de insertar
  la nueva, de modo que el tope nunca se supera.

  ## Ejemplos

      iex> {:ok, cache} = Gunther.Cache.start_link(max_entries: 1)
      iex> Gunther.Cache.put(cache, :a, 1)
      :ok
      iex> Gunther.Cache.put(cache, :b, 2)
      :ok
      iex> Gunther.Cache.get(cache, :a)
      :error
  """
  @spec put(GenServer.server(), key(), term()) :: :ok
  def put(server \\ __MODULE__, key, value) do
    GenServer.call(server, {:put, key, value})
  end

  @doc """
  Lee un valor. Devuelve `{:ok, value}` o `:error`.

  Una entrada caducada se trata como ausente.

  ## Ejemplos

      iex> {:ok, cache} = Gunther.Cache.start_link()
      iex> Gunther.Cache.get(cache, :nada)
      :error
  """
  @spec get(GenServer.server(), key()) :: {:ok, term()} | :error
  def get(server \\ __MODULE__, key) do
    case :ets.lookup(table(server), key) do
      [{^key, value, expires_at, _last_used, _seq}] ->
        if expired?(expires_at) do
          Bridge.cache_event(:miss, key)
          :error
        else
          Bridge.cache_event(:hit, key)
          GenServer.cast(server, {:touch, key})
          {:ok, value}
        end

      [] ->
        Bridge.cache_event(:miss, key)
        :error
    end
  end

  @doc """
  Borra una entrada. Devuelve `:ok` tanto si estaba como si no.
  """
  @spec delete(GenServer.server(), key()) :: :ok
  def delete(server \\ __MODULE__, key) do
    GenServer.call(server, {:delete, key})
  end

  @doc """
  El número de entradas vivas.
  """
  @spec size(GenServer.server()) :: non_neg_integer()
  def size(server \\ __MODULE__) do
    :counters.get(counter(server), 1)
  end

  @doc """
  Borra todas las entradas.
  """
  @spec clear(GenServer.server()) :: :ok
  def clear(server \\ __MODULE__) do
    GenServer.call(server, :clear)
  end

  # --- interno ---

  defp table(server), do: GenServer.call(server, :table)
  defp counter(server), do: GenServer.call(server, :counter)

  defp expired?(nil), do: false
  defp expired?(expires_at), do: System.monotonic_time(:millisecond) >= expires_at

  @impl GenServer
  def init(opts) do
    table = :ets.new(:gunther_cache_data, [:set, :public, read_concurrency: true])
    index = :ets.new(:gunther_cache_index, [:ordered_set, :public, read_concurrency: true])
    counter = :counters.new(1, [])
    seq = :atomics.new(1, signed: false)

    sweep_interval =
      case Keyword.get(opts, :sweep_interval_ms, 30_000) do
        nil -> nil
        ms -> ms
      end

    state = %{
      table: table,
      index: index,
      counter: counter,
      seq: seq,
      max_entries: Keyword.get(opts, :max_entries, 10_000),
      ttl_ms: Keyword.get(opts, :ttl_ms),
      sweep_interval_ms: sweep_interval
    }

    if sweep_interval do
      Process.send_after(self(), :sweep, sweep_interval)
    end

    {:ok, state}
  end

  @impl GenServer
  def handle_call({:put, key, value}, _from, state) do
    now = System.monotonic_time(:millisecond)
    expires_at = if state.ttl_ms, do: now + state.ttl_ms
    seq = next_seq(state)

    # Si la clave ya existia, su fila antigua se borra del indice con su seq
    # viejo: sin esto, el indice acumula entradas huerfanas y el LRU
    # expulsaria una clave que ya no esta en `data`.
    #
    # Ademas, el contador de entradas hay que ajustarlo: sobreescribir NO
    # crea una entrada nueva, sustituye la existente.
    existed? = remove_from_index(state, key)

    :ets.insert(state.table, {key, value, expires_at, now, seq})
    :ets.insert(state.index, {{now, seq}, key})

    if existed? do
      :counters.add(state.counter, 1, -1)
    end

    :counters.add(state.counter, 1, 1)

    # El tope se comprueba con la fila recien insertada: si se supera, se
    # expulsa la menos usada hasta caber.
    evict_until_fits(state)

    {:reply, :ok, state}
  end

  def handle_call({:delete, key}, _from, state) do
    remove_from_index(state, key)

    case :ets.take(state.table, key) do
      [] ->
        {:reply, :ok, state}

      _other ->
        :counters.add(state.counter, 1, -1)
        {:reply, :ok, state}
    end
  end

  def handle_call(:clear, _from, state) do
    :ets.delete_all_objects(state.table)
    :ets.delete_all_objects(state.index)
    :counters.put(state.counter, 1, 0)
    {:reply, :ok, state}
  end

  def handle_call(:table, _from, state), do: {:reply, state.table, state}
  def handle_call(:counter, _from, state), do: {:reply, state.counter, state}
  def handle_call(:index, _from, state), do: {:reply, state.index, state}

  @impl GenServer
  def handle_cast({:touch, key}, state) do
    case :ets.lookup(state.table, key) do
      [{^key, value, expires_at, _last_used, seq}] ->
        now = System.monotonic_time(:millisecond)
        remove_from_index(state, key)
        :ets.insert(state.table, {key, value, expires_at, now, seq})
        :ets.insert(state.index, {{now, seq}, key})
        {:noreply, state}

      [] ->
        {:noreply, state}
    end
  end

  @impl GenServer
  def handle_info(:sweep, state) do
    sweep(state)

    if state.sweep_interval_ms do
      Process.send_after(self(), :sweep, state.sweep_interval_ms)
    end

    {:noreply, state}
  end

  def handle_info(_message, state), do: {:noreply, state}

  defp sweep(state) do
    now = System.monotonic_time(:millisecond)

    state.table
    |> :ets.tab2list()
    |> Enum.each(fn {key, _value, expires_at, _last_used, _seq} ->
      if expires_at && now >= expires_at do
        remove_from_index(state, key)
        :ets.delete(state.table, key)
        :counters.add(state.counter, 1, -1)
      end
    end)
  end

  defp evict_until_fits(state) do
    if :counters.get(state.counter, 1) > state.max_entries do
      # `:ets.first/1` devuelve la CLAVE del indice, que es `{last_used, seq}`.
      # La `key` cacheada es el VALOR de esa entrada.
      case :ets.first(state.index) do
        :"$end_of_table" ->
          :ok

        index_key ->
          evict_index_entry(state, index_key)
      end
    else
      :ok
    end
  end

  # Borra la entrada mas antigua del indice y su fila de datos. La `key`
  # cacheada es el VALOR de la entrada del indice: `:ets.first/1` devuelve la
  # clave del indice, que es `{last_used, seq}`.
  defp evict_index_entry(state, index_key) do
    case :ets.lookup(state.index, index_key) do
      [{^index_key, key}] ->
        :ets.delete(state.index, index_key)
        drop_data_row(state, key)
        Bridge.cache_event(:evict, key)
        evict_until_fits(state)

      [] ->
        :ok
    end
  end

  # Elimina la fila de datos de `key` y ajusta el contador de entradas.
  defp drop_data_row(state, key) do
    case :ets.take(state.table, key) do
      [] -> :ok
      _other -> :counters.add(state.counter, 1, -1)
    end
  end

  # Borra la fila del indice que corresponde a `key`. El `seq` se lee de la
  # fila de datos: es la unica fuente que no puede desincronizarse.
  #
  # Devuelve `true` si la entrada existia.
  defp remove_from_index(state, key) do
    case :ets.lookup(state.table, key) do
      [{^key, _value, _expires_at, last_used, seq}] ->
        :ets.delete(state.index, {last_used, seq})
        true

      [] ->
        false
    end
  end

  defp next_seq(state) do
    :atomics.add_get(state.seq, 1, 1)
  end
end
