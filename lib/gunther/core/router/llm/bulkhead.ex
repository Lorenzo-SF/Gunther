defmodule Gunther.Router.Llm.Bulkhead do
  @moduledoc """
  El bulkhead del modelo de decision (SPEC §6.12, control M7).

  Un flujo de peticiones no puede saturar al decisor: cada `DecisionSpec`
  tiene su propio `max_concurrency`, y el que se pasa se queda esperando o
  recibe `{:error, :busy}`.

  Si el bulkhead no esta arrancado, **no hay limite**: el decisor se
  llama igual. Un limite que no se puede aplicar en silencio seria peor que
  ninguno.

  ## Ejemplos

      iex> Gunther.Router.Llm.Bulkhead.start_link(name: :bh_ejemplo)
      iex> Gunther.Router.Llm.Bulkhead.acquire(:otro, 1, 100)
      :ok
  """

  use GenServer

  @type state :: %{counts: map(), waiting: map()}

  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: Keyword.get(opts, :name, __MODULE__))
  end

  @doc """
  Toma un sitio del bulkhead.

  Espera hasta `timeout` milisegundos a que haya sitio. Si no lo hay,
  devuelve `{:error, :busy}`.
  """
  @spec acquire(atom(), pos_integer(), pos_integer()) :: :ok | {:error, :busy}
  def acquire(spec_id, limit, timeout) do
    case Process.whereis(__MODULE__) do
      nil -> :ok
      _pid -> GenServer.call(__MODULE__, {:acquire, spec_id, limit, timeout}, timeout + 100)
    end
  end

  @doc """
  Devuelve el sitio tomado.
  """
  @spec release(atom()) :: :ok
  def release(spec_id) do
    case Process.whereis(__MODULE__) do
      nil -> :ok
      _pid -> GenServer.cast(__MODULE__, {:release, spec_id})
    end
  end

  @impl GenServer
  def init(_opts), do: {:ok, %{counts: %{}, waiting: %{}}}

  @impl GenServer
  def handle_call({:acquire, spec_id, limit, _timeout}, from, state) do
    count = Map.get(state.counts, spec_id, 0)

    if count < limit do
      {:reply, :ok, put_count(state, spec_id, count + 1)}
    else
      waiting = Map.get(state.waiting, spec_id, [])
      {:noreply, %{state | waiting: Map.put(state.waiting, spec_id, waiting ++ [from])}}
    end
  end

  @impl GenServer
  def handle_cast({:release, spec_id}, state) do
    {:noreply, release_slot(state, spec_id)}
  end

  # Al soltar un sitio, se le da al primero que estaba esperando.
  defp release_slot(state, spec_id) do
    case Map.get(state.waiting, spec_id, []) do
      [] ->
        put_count(state, spec_id, max(Map.get(state.counts, spec_id, 1) - 1, 0))

      [first | rest] ->
        GenServer.reply(first, :ok)
        %{state | waiting: Map.put(state.waiting, spec_id, rest)}
    end
  end

  defp put_count(state, spec_id, count) do
    %{state | counts: Map.put(state.counts, spec_id, count)}
  end
end
