defmodule Gunther.Supervisor do
  @moduledoc """
  La raíz del árbol de supervisión de Gunther (SPEC §2.3).

  ```
  Gunther.Supervisor (one_for_one, hijos en este orden)
  ├── Config.Server          valida y guarda la config; swap atómico de snapshot
  ├── Catalog.Server         modelos, providers, nodos; snapshots inmutables versionados
  ├── TaskSupervisor         Task.Supervisor para fan-out, clasificadores, streams
  ├── Telemetry.Bridge       reenvía eventos selectivos de Arrea y Apero (§3.5)
  ├── Memory.Server          KV en ETS
  ├── Cache.Decisions        caché propia con tope y LRU exacto (CE-06)
  ├── Selector.Server        estado del reparto por consumer (CE-09)
  ├── Tools.Server           tabla única de tools
  ├── Resilience.Supervisor  breakers, bulkheads y rate limiters por provider y modelo
  ├── Resource.Ledger        ledger de recursos (D-48), indexado por physical_id (D-65)
  ├── Placement.Registry      direcciona el semáforo de colocación por nodo (§11.4)
  ├── Placement.Supervisor    semáforos de colocación, uno por nodo (§11.4)
  ├── Node.Supervisor        DynamicSupervisor: una conexión por nodo remoto (§18)
  ├── Engine.Supervisor      DynamicSupervisor: un engine por modelo cargado
  ├── Session.Supervisor     DynamicSupervisor
  ├── MCP.Client.Supervisor  DynamicSupervisor
  ├── Agent.Supervisor       DynamicSupervisor
  └── Coral.Supervisor       solo con `[coral] enabled = true` (§22)
  ```

  **Estrategia**: raíz `one_for_one`; los `DynamicSupervisor`, `one_for_one`.
  `rest_for_one` no se implementa (D-19).

  Sin `rest_for_one`, la consistencia sale de la rehidratación (§2.3): cada
  hijo con estado debe poder reconstruirse tras un reinicio.
  """

  use Supervisor

  @doc """
  Arranca la raiz de supervision.
  """
  @spec start_link(keyword()) :: Supervisor.on_start()
  def start_link(opts \\ []) do
    Supervisor.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl Supervisor
  def init(_opts) do
    children = [
      # F1
      Gunther.Config.Server,
      Gunther.Catalog.Server,
      Gunther.Registry,
      {Task.Supervisor, name: Gunther.TaskSupervisor},
      Gunther.Telemetry.Bridge,
      Gunther.Memory.Server,
      Gunther.Cache.Decisions,
      Gunther.Selector.Server,
      # F5
      Gunther.Resilience.Supervisor,
      # F2
      Gunther.Resource.Ledger,
      Gunther.Placement,
      # El semaforo de colocacion (§11.4) es un proceso por nodo: el
      # `Registry` direcciona por nodo y el `DynamicSupervisor` los arranca
      # bajo demanda, porque los nodos no se conocen de antemano.
      {Registry, keys: :unique, name: Gunther.Engine.Placement.Registry},
      Gunther.Engine.Placement.Supervisor,
      # F15
      {DynamicSupervisor, name: Gunther.Node.Supervisor, strategy: :one_for_one},
      # F6
      {DynamicSupervisor, name: Gunther.Engine.Supervisor, strategy: :one_for_one},
      # F8
      {DynamicSupervisor, name: Gunther.Session.Supervisor, strategy: :one_for_one},
      # F13
      {DynamicSupervisor, name: Gunther.MCP.Client.Supervisor, strategy: :one_for_one},
      # F14
      {DynamicSupervisor, name: Gunther.Agent.Supervisor, strategy: :one_for_one}
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end
end
