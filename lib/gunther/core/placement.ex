defmodule Gunther.Placement do
  @moduledoc """
  Los semáforos de colocación, uno por nodo (SPEC §2.3, §11.4).

  El `Placer` (§11.4) reparte: decide qué modelo se carga en qué nodo, con
  expulsión y tope por conteo (`placement.max_loaded_models`).

  Este módulo mantiene el estado de colocación: qué modelos están cargados en
  qué nodo, y cuántos.
  """

  use GenServer

  @doc """
  Arranca el proceso de colocación.
  """
  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: Keyword.get(opts, :name, __MODULE__))
  end

  @impl GenServer
  def init(_opts) do
    {:ok, %{loaded: %{}, max_loaded_models: 0}}
  end

  @doc """
  Registra un modelo cargado en un nodo.

  ## Ejemplos

      iex> Gunther.Placement.start_link()
      {:ok, pid}
  """
  @spec track(atom(), String.t()) :: :ok
  def track(model_alias, node) do
    GenServer.call(__MODULE__, {:track, model_alias, node})
  end

  @doc """
  Quita un modelo del registro de cargados.

  ## Ejemplos

      iex> Gunther.Placement.start_link()
      {:ok, pid}
  """
  @spec untrack(atom()) :: :ok
  def untrack(model_alias) do
    GenServer.call(__MODULE__, {:untrack, model_alias})
  end

  @doc """
  Los modelos cargados en un nodo.

  ## Ejemplos

      iex> Gunther.Placement.start_link()
      {:ok, pid}
  """
  @spec loaded_in(String.t()) :: [atom()]
  def loaded_in(node) do
    GenServer.call(__MODULE__, {:loaded_in, node})
  end

  @doc """
  ¿Se puede cargar otro modelo en este nodo?

  `max_loaded_models = 0` significa «sin tope por conteo»: solo manda la
  memoria.

  ## Ejemplos

      iex> Gunther.Placement.start_link()
      {:ok, pid}
  """
  @spec can_load?(String.t()) :: boolean()
  def can_load?(node) do
    GenServer.call(__MODULE__, {:can_load?, node})
  end

  @impl GenServer
  def handle_call({:track, model_alias, node}, _from, state) do
    loaded = Map.put(state.loaded, model_alias, node)
    {:reply, :ok, %{state | loaded: loaded}}
  end

  def handle_call({:untrack, model_alias}, _from, state) do
    {:reply, :ok, %{state | loaded: Map.delete(state.loaded, model_alias)}}
  end

  def handle_call({:loaded_in, node}, _from, state) do
    models =
      state.loaded
      |> Enum.filter(fn {_alias, loaded_node} -> loaded_node == node end)
      |> Enum.map(fn {model_alias, _node} -> model_alias end)
      |> Enum.sort()

    {:reply, models, state}
  end

  def handle_call({:can_load?, node}, _from, state) do
    if state.max_loaded_models == 0 do
      {:reply, true, state}
    else
      count = Enum.count(state.loaded, fn {_alias, loaded_node} -> loaded_node == node end)
      {:reply, count < state.max_loaded_models, state}
    end
  end
end
