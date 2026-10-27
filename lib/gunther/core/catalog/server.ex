defmodule Gunther.Catalog.Server do
  @moduledoc """
  Modelos, providers y nodos; snapshots inmutables versionados (SPEC §2.3).

  El catálogo se reconstruye desde `Gunther.Config.Server` (§2.3) y se
  recarga con `Gunther.Catalog.reload/0`, que conserva el snapshot anterior
  si la nueva configuración no valida (§4.4).
  """

  use GenServer

  alias Gunther.Catalog

  @type t :: %__MODULE__{catalog: Catalog.t() | nil, version: non_neg_integer()}

  defstruct [:catalog, version: 0]

  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: Keyword.get(opts, :name, __MODULE__))
  end

  @impl GenServer
  def init(_opts), do: {:ok, %__MODULE__{}}

  @doc """
  El catálogo activo, o `nil` si aún no se ha construido.
  """
  @spec get(GenServer.server()) :: Catalog.t() | nil
  def get(server \\ __MODULE__) do
    GenServer.call(server, :get)
  end

  @impl GenServer
  def handle_call(:get, _from, state), do: {:reply, state.catalog, state}
end
