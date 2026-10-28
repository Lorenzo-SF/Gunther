defmodule Gunther.Catalog.Server do
  @moduledoc """
  Modelos, providers y nodos; snapshots inmutables versionados (SPEC §2.3).

  El catálogo se reconstruye desde el `Gunther.Config.Server` (§2.3) y se
  recarga con `Gunther.Catalog.reload/0`, que conserva el snapshot anterior
  si la nueva configuración no valida (§4.4).

  La recarga **vacía la caché de decisiones** (§6.5): el hash del catálogo
  cambia y los rankings cacheados dejan de valer.
  """

  use GenServer

  alias Gunther.Catalog
  alias Gunther.Config
  alias Gunther.Error

  @type t :: %__MODULE__{
          catalog: Catalog.t() | nil,
          config: Config.t() | nil,
          config_server: GenServer.server(),
          cache_server: GenServer.server(),
          version: non_neg_integer()
        }

  defstruct [:catalog, :config, config_server: Config.Server, cache_server: Gunther.Cache.Decisions, version: 0]

  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: Keyword.get(opts, :name, __MODULE__))
  end

  @impl GenServer
  def init(opts) do
    config_server = Keyword.get(opts, :config_server, Config.Server)
    cache_server = Keyword.get(opts, :cache_server, Gunther.Cache.Decisions)

    state = %__MODULE__{config_server: config_server, cache_server: cache_server}

    case Keyword.get(opts, :config) do
      nil ->
        {:ok, state}

      config ->
        case Config.load(config) do
          {:ok, loaded} ->
            {:ok, %{state | config: loaded, catalog: Catalog.build(loaded), version: 1}}

          {:error, %Error{} = error} ->
            {:stop, error}
        end
    end
  end

  @doc """
  El catálogo activo, o `nil` si aún no se ha construido.
  """
  @spec get(GenServer.server()) :: Catalog.t() | nil
  def get(server \\ __MODULE__) do
    GenServer.call(server, :get)
  end

  @doc """
  Recarga el catálogo desde la configuración activa.

  Si la nueva configuración no valida, **se conserva el snapshot anterior**
  (§4.4) y se devuelve el error. Si valida, el catálogo se reconstruye, la
  versión sube y **la caché de decisiones se vacía** (§6.5).
  """
  @spec reload(GenServer.server(), GenServer.server()) :: :ok | {:error, Error.t()}
  def reload(server \\ __MODULE__, config_server \\ nil) do
    GenServer.call(server, {:reload, config_server})
  end

  @doc """
  El hash del catálogo activo, que forma parte de la clave de la caché de
  decisiones (§6.5). Es `""` si no hay catálogo.
  """
  @spec hash(GenServer.server()) :: binary()
  def hash(server \\ __MODULE__) do
    GenServer.call(server, :hash)
  end

  @impl GenServer
  def handle_call(:get, _from, state), do: {:reply, state.catalog, state}

  def handle_call(:hash, _from, state) do
    {:reply, hash_of(state), state}
  end

  def handle_call({:reload, override}, _from, state) do
    config_server = override || state.config_server

    case fetch_config(config_server) do
      nil ->
        {:reply, {:error, Error.new(:config_error, "no hay ninguna configuracion activa para recargar")}, state}

      config ->
        catalog = Catalog.build(config)
        # El hash del catalogo cambia, asi que los rankings cacheados dejan
        # de valer (§6.5).
        clear_cache(state)
        {:reply, :ok, %{state | config: config, catalog: catalog, version: state.version + 1}}
    end
  end

  # La cache de decisiones se vacia. Si el servidor no esta arrancado, no
  # hay nada que vaciar.
  defp clear_cache(%{cache_server: server}) do
    case Process.whereis(server) do
      nil -> :ok
      _pid -> Gunther.Cache.Decisions.clear(server)
    end
  end

  # La configuracion activa, o `nil` si el servidor de configuracion no esta
  # arrancado. Que no este no es una excepcion: es un `config_error`.
  defp fetch_config(config_server) do
    case Process.whereis(config_server) do
      nil -> nil
      _pid -> Config.Server.get(config_server)
    end
  end

  defp hash_of(%{catalog: nil}), do: ""

  defp hash_of(%{catalog: catalog, config: config}) do
    Catalog.hash(catalog, config)
  end
end
