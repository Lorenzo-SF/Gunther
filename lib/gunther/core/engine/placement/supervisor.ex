defmodule Gunther.Engine.Placement.Supervisor do
  @moduledoc """
  El supervisor de los semaforos de colocacion: uno por nodo (SPEC §11.4).

  Los procesos se arrancan **bajo demanda** (`Placement.with_node/3` los
  pide) y viven hasta que el supervisor para. Un `DynamicSupervisor` y nada
  mas: un semaforo por nodo, y los nodos no se conocen de antemano.
  """

  use DynamicSupervisor

  @doc false
  @spec start_link(keyword()) :: Supervisor.on_start()
  def start_link(opts \\ []) do
    DynamicSupervisor.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc false
  @impl DynamicSupervisor
  def init(_opts) do
    DynamicSupervisor.init(strategy: :one_for_one)
  end

  @doc false
  @spec start_child({module(), term()}) :: DynamicSupervisor.on_start_child()
  def start_child(child_spec) do
    DynamicSupervisor.start_child(__MODULE__, child_spec)
  end
end
