defmodule Gunther.Config.Server do
  @moduledoc """
  Guarda la configuración activa y la intercambia de forma atómica (SPEC §2.3, §14.4).

  El snapshot es **inmutable**: nadie lo muta. Un cambio de configuración
  valida el fichero nuevo **entero**; si falla, se conserva el snapshot
  anterior; si pasa, se intercambia.

  La recarga en caliente la vigila `Trebejo.File` (opcional, §14.4).
  """

  use GenServer

  alias Gunther.Config
  alias Gunther.Error

  @type t :: %__MODULE__{config: Config.t() | nil, version: non_neg_integer()}

  defstruct [:config, version: 0]

  @doc """
  Arranca el servidor de configuración.

  Con `:config` se le da una configuración ya cargada (mapa o ruta); sin ella,
  arranca vacío y `reload/0` la carga desde la ruta por defecto.
  """
  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: Keyword.get(opts, :name, __MODULE__))
  end

  @impl GenServer
  def init(opts) do
    state = %__MODULE__{}

    case Keyword.get(opts, :config) do
      nil ->
        {:ok, state}

      config ->
        case Config.load(config) do
          {:ok, loaded} -> {:ok, %{state | config: loaded, version: 1}}
          {:error, %Error{} = error} -> {:stop, error}
        end
    end
  end

  @doc """
  La configuración activa, o `nil` si aún no se ha cargado ninguna.

  Si el servidor no está arrancado, tampoco hay configuración: `nil`, no una
  excepción. Quien pregunta decide qué hacer con la ausencia.
  """
  @spec get(GenServer.server()) :: Config.t() | nil
  def get(server \\ __MODULE__) do
    case Process.whereis(server) do
      nil -> nil
      _pid -> GenServer.call(server, :get)
    end
  end

  @doc """
  La versión del snapshot activo. Cambia en cada intercambio.
  """
  @spec version(GenServer.server()) :: non_neg_integer()
  def version(server \\ __MODULE__) do
    GenServer.call(server, :version)
  end

  @impl GenServer
  def handle_call(:get, _from, state), do: {:reply, state.config, state}
  def handle_call(:version, _from, state), do: {:reply, state.version, state}
end
