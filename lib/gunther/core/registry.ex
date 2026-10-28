defmodule Gunther.Registry do
  @moduledoc """
  El registro de behaviours (SPEC §5, §5.14).

  Trece tipos registrables en v1, más `Gunther.Agent`, que **es** un behaviour
  pero **no se registra**: se pasa como `module:` en `%Gunther.Agent{}`.

  ## Desde el TOML

  `[embedders.local] module = MyApp.Embedder` registra el módulo sin
  recompilar (SPEC §5.14).

  ## Ejemplos

      iex> Gunther.Registry.register(:selector, Gunther.Selector.RoundRobin)
      :ok
      iex> Gunther.Registry.list(:selector)
      [Gunther.Selector.RoundRobin]
  """

  use GenServer

  @types %{
    provider: Gunther.Provider,
    embedder: Gunther.Embedder,
    chunker: Gunther.Chunker,
    retriever: Gunther.Retriever,
    reranker: Gunther.Reranker,
    rewriter: Gunther.QueryRewriter,
    classifier: Gunther.Classifier,
    selector: Gunther.Selector,
    store: Gunther.Store,
    guardrail: Gunther.Guardrail,
    tokenizer: Gunther.Tokenizer,
    detector: Gunther.Detector,
    session_store: Gunther.SessionStore
  }

  @doc """
  Los tipos de behaviour registrables.

  ## Ejemplos

      iex> :provider in Gunther.Registry.types()
      true
      iex> :agent in Gunther.Registry.types()
      false
  """
  @spec types() :: [atom()]
  def types, do: Map.keys(@types)

  @doc """
  El behaviour de un tipo, o `nil` si el tipo no existe.

  ## Ejemplos

      iex> Gunther.Registry.behaviour(:provider) == Gunther.Provider
      true
  """
  @spec behaviour(atom()) :: module() | nil
  def behaviour(type), do: Map.get(@types, type)

  @doc """
  Registra un módulo para un tipo de behaviour.

  ## Opciones

    * `:opts` — opciones que recibe el behaviour al construirlo

  ## Ejemplos

      iex> Gunther.Registry.register(:selector, Gunther.Selector.RoundRobin)
      :ok
  """
  @spec register(atom(), module(), keyword()) :: :ok
  def register(type, module, opts \\ []) do
    GenServer.call(__MODULE__, {:register, type, module, opts})
  end

  @doc """
  Quita un módulo del registro.
  """
  @spec unregister(atom(), module()) :: :ok
  def unregister(type, module) do
    GenServer.call(__MODULE__, {:unregister, type, module})
  end

  @doc """
  Los módulos registrados de un tipo.

  ## Ejemplos

      iex> Gunther.Registry.list(:provider)
      []
  """
  @spec list(atom()) :: [module()]
  def list(type) do
    GenServer.call(__MODULE__, {:list, type})
  end

  @doc """
  Resuelve un módulo registrado de un tipo, con sus opciones.

  ## Ejemplos

      iex> Gunther.Registry.resolve(:provider, Gunther.Provider.Mock)
      :error
  """
  @spec resolve(atom(), module()) :: {:ok, keyword()} | :error
  def resolve(type, module) do
    GenServer.call(__MODULE__, {:resolve, type, module})
  end

  # --- proceso ---

  @doc false
  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: Keyword.get(opts, :name, __MODULE__))
  end

  @impl GenServer
  def init(_opts) do
    {:ok, %{registry: %{}}}
  end

  @impl GenServer
  def handle_call({:register, type, module, opts}, _from, state) do
    entry = {module, opts}
    registry = Map.update(state.registry, type, %{module => entry}, &Map.put(&1, module, entry))
    {:reply, :ok, %{state | registry: registry}}
  end

  def handle_call({:unregister, type, module}, _from, state) do
    registry =
      case Map.get(state.registry, type) do
        nil -> state.registry
        entries -> Map.put(state.registry, type, Map.delete(entries, module))
      end

    {:reply, :ok, %{state | registry: registry}}
  end

  def handle_call({:list, type}, _from, state) do
    entries =
      state.registry
      |> Map.get(type, %{})
      |> Map.keys()
      |> Enum.sort()

    {:reply, entries, state}
  end

  def handle_call({:resolve, type, module}, _from, state) do
    case state.registry |> Map.get(type, %{}) |> Map.get(module) do
      nil -> {:reply, :error, state}
      {_module, opts} -> {:reply, {:ok, opts}, state}
    end
  end
end
