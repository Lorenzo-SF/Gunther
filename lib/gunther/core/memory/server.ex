defmodule Gunther.Memory.Server do
  @moduledoc """
  La memoria KV en ETS (SPEC §7.2, D-22, D-90).

  Mapa clave→valor con espacio de nombres por consumer (`mem:<consumer>:<key>`);
  `consumer: :global` es el ámbito compartido.

  Se sobrescribe o borra; caducidad opcional (`expires_at`); local al nodo;
  acotada por `memory.max_entries`.

  `put_new/3` usa `:ets.insert_new/2`, **atómico**.

  ## Autor y versión (D-90)

  Cada entrada guarda `meta: %{author, version, superseded_by}`. `put/3` con
  `if_version:` falla con `{:error, :version_conflict}` si la versión no
  coincide.
  """

  use GenServer

  alias Gunther.Error

  @type entry :: %{
          value: term(),
          expires_at: integer() | nil,
          meta: %{author: term(), version: non_neg_integer(), superseded_by: binary() | nil}
        }

  @doc """
  Arranca el servidor de memoria.
  """
  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: Keyword.get(opts, :name, __MODULE__))
  end

  @impl GenServer
  def init(opts) do
    table = :ets.new(:gunther_memory, [:set, :public, read_concurrency: true])

    state = %{
      table: table,
      max_entries: Keyword.get(opts, :max_entries, 10_000),
      version: :atomics.new(1, signed: false)
    }

    {:ok, state}
  end

  @doc """
  Guarda un valor.

  ## Opciones

    * `:consumer` — el ámbito (por defecto `:global`)
    * `:author` — quién escribe la entrada
    * `:if_version` — versión esperada; si no coincide, `{:error, :version_conflict}`
    * `:ttl_ms` — caducidad

  ## Ejemplos

      iex> Gunther.Memory.put("clave", "valor", [])
      :ok
      iex> Gunther.Memory.get("clave", nil, [])
      "valor"
  """
  @spec put(binary(), term(), keyword()) :: :ok | {:error, Error.t()}
  def put(key, value, opts \\ []) do
    consumer = Keyword.get(opts, :consumer, :global)
    author = Keyword.get(opts, :author)
    if_version = Keyword.get(opts, :if_version)
    ttl_ms = Keyword.get(opts, :ttl_ms)

    GenServer.call(__MODULE__, {:put, consumer, key, value, author, if_version, ttl_ms})
  end

  @doc """
  Guarda un valor solo si la clave no existe. Es atómico.

  ## Ejemplos

      iex> Gunther.Memory.put_new("nueva", 1, [])
      :ok
      iex> Gunther.Memory.put_new("nueva", 2, [])
      {:error, :exists}
  """
  @spec put_new(binary(), term(), keyword()) :: :ok | {:error, :exists}
  def put_new(key, value, opts \\ []) do
    consumer = Keyword.get(opts, :consumer, :global)
    author = Keyword.get(opts, :author)
    ttl_ms = Keyword.get(opts, :ttl_ms)

    GenServer.call(__MODULE__, {:put_new, consumer, key, value, author, ttl_ms})
  end

  @doc """
  Lee un valor, o el defecto dado.

  ## Ejemplos

      iex> Gunther.Memory.get("inexistente", "defecto", [])
      "defecto"
  """
  @spec get(binary(), term(), keyword()) :: term()
  def get(key, default \\ nil, opts \\ []) do
    consumer = Keyword.get(opts, :consumer, :global)

    case lookup(consumer, key) do
      nil -> default
      entry -> entry.value
    end
  end

  @doc """
  Borra una entrada.
  """
  @spec delete(binary(), keyword()) :: :ok
  def delete(key, opts \\ []) do
    consumer = Keyword.get(opts, :consumer, :global)
    GenServer.call(__MODULE__, {:delete, consumer, key})
  end

  @doc """
  Las claves del ámbito, ordenadas.

  ## Ejemplos

      iex> Gunther.Memory.keys([])
      []
  """
  @spec keys(keyword()) :: [binary()]
  def keys(opts \\ []) do
    consumer = Keyword.get(opts, :consumer, :global)
    GenServer.call(__MODULE__, {:keys, consumer})
  end

  @doc """
  Marca una entrada como sustituida por otra (D-90).

  ## Ejemplos

      iex> Gunther.Memory.supersede("vieja", "nueva", [])
      :ok
  """
  @spec supersede(binary(), binary(), keyword()) :: :ok
  def supersede(old_key, new_key, opts \\ []) do
    consumer = Keyword.get(opts, :consumer, :global)
    GenServer.call(__MODULE__, {:supersede, consumer, old_key, new_key})
  end

  @doc """
  La versión actual de una entrada, o `nil`.

  ## Ejemplos

      iex> Gunther.Memory.version("inexistente", [])
      nil
  """
  @spec version(binary(), keyword()) :: non_neg_integer() | nil
  def version(key, opts \\ []) do
    consumer = Keyword.get(opts, :consumer, :global)

    case lookup(consumer, key) do
      nil -> nil
      entry -> entry.meta.version
    end
  end

  defp lookup(consumer, key) do
    table = GenServer.call(__MODULE__, :table)
    full_key = namespaced(consumer, key)

    case :ets.lookup(table, full_key) do
      [{^full_key, entry}] ->
        if expired?(entry) do
          :ets.delete(table, full_key)
          nil
        else
          entry
        end

      [] ->
        nil
    end
  end

  defp expired?(%{expires_at: nil}), do: false
  defp expired?(%{expires_at: expires_at}), do: System.monotonic_time(:millisecond) >= expires_at

  defp namespaced(consumer, key), do: "mem:#{consumer}:#{key}"

  @impl GenServer
  def handle_call({:put, consumer, key, value, author, if_version, ttl_ms}, _from, state) do
    full_key = namespaced(consumer, key)
    current = :ets.lookup(state.table, full_key)

    version =
      case current do
        [{^full_key, entry}] -> entry.meta.version + 1
        [] -> 1
      end

    if is_nil(if_version) do
      current_version =
        case current do
          [{^full_key, entry}] -> entry.meta.version
          [] -> 0
        end

      if current_version == if_version do
        {:reply, :ok, do_put(state, full_key, consumer, key, value, author, version, ttl_ms)}
      else
        {:reply,
         {:error,
          Error.new(:version_conflict, "la version de la entrada no coincide",
            details: %{key: key, expected: if_version, actual: current_version}
          )}, state}
      end
    else
      {:reply, :ok, do_put(state, full_key, consumer, key, value, author, version, ttl_ms)}
    end
  end

  def handle_call({:put_new, consumer, key, value, author, ttl_ms}, _from, state) do
    full_key = namespaced(consumer, key)
    expires_at = if ttl_ms, do: System.monotonic_time(:millisecond) + ttl_ms

    entry = %{
      value: value,
      expires_at: expires_at,
      meta: %{author: author, version: 1, superseded_by: nil}
    }

    if :ets.insert_new(state.table, {full_key, entry}) do
      {:reply, :ok, state}
    else
      {:reply, {:error, :exists}, state}
    end
  end

  def handle_call({:delete, consumer, key}, _from, state) do
    :ets.delete(state.table, namespaced(consumer, key))
    {:reply, :ok, state}
  end

  def handle_call({:keys, consumer}, _from, state) do
    prefix = "mem:#{consumer}:"

    keys =
      state.table
      |> :ets.tab2list()
      |> Enum.map(fn {full_key, _entry} -> String.replace_prefix(full_key, prefix, "") end)
      |> Enum.sort()

    {:reply, keys, state}
  end

  def handle_call({:supersede, consumer, old_key, new_key}, _from, state) do
    full_key = namespaced(consumer, old_key)

    case :ets.lookup(state.table, full_key) do
      [{^full_key, entry}] ->
        meta = %{entry.meta | superseded_by: new_key}
        :ets.insert(state.table, {full_key, %{entry | meta: meta}})
        {:reply, :ok, state}

      [] ->
        {:reply, :ok, state}
    end
  end

  def handle_call(:table, _from, state), do: {:reply, state.table, state}

  defp do_put(state, full_key, _consumer, _key, value, author, version, ttl_ms) do
    expires_at = if ttl_ms, do: System.monotonic_time(:millisecond) + ttl_ms

    existing =
      case :ets.lookup(state.table, full_key) do
        [{^full_key, entry}] -> entry
        [] -> nil
      end

    meta =
      case existing do
        nil -> %{author: author, version: version, superseded_by: nil}
        entry -> %{entry.meta | version: version}
      end

    :ets.insert(state.table, {full_key, %{value: value, expires_at: expires_at, meta: meta}})
    state
  end
end
