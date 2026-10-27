defmodule Gunther.Selector.Server do
  @moduledoc """
  El estado del reparto por consumer (SPEC §5.8, CE-09).

  Vive en ETS con tope `selector.max_states` (10 000) y LRU de
  `Gunther.Cache`.

  ## La clave

  `{consumer, sha256(candidatos ordenados)}`. Un consumer con mucho tráfico no
  desplaza el reparto de otro, porque su clave es distinta.

  ## Ejemplos

      iex> Gunther.Selector.Server.state_key(:default, [:a, :b]) |> elem(0)
      :default
  """

  use GenServer

  @doc """
  Arranca el servidor del selector.
  """
  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: Keyword.get(opts, :name, __MODULE__))
  end

  @impl GenServer
  def init(opts) do
    table = :ets.new(:gunther_selector, [:set, :public, read_concurrency: true])

    state = %{
      table: table,
      max_states: Keyword.get(opts, :max_states, 10_000),
      aging_step_ms: Keyword.get(opts, :aging_step_ms, 1000)
    }

    {:ok, state}
  end

  @doc """
  La clave de estado: `{consumer, hash}`.

  ## Ejemplos

      iex> {consumer, hash} = Gunther.Selector.Server.state_key(:default, [:a, :b])
      iex> consumer
      :default
      iex> is_binary(hash)
      true
  """
  @spec state_key(atom(), [atom()]) :: {atom(), binary()}
  def state_key(consumer, candidates) do
    hash =
      candidates
      |> Enum.sort()
      |> :erlang.term_to_binary()
      |> then(&:crypto.hash(:sha256, &1))
      |> Base.encode16(case: :lower)

    {consumer, hash}
  end

  @doc """
  El estado de reparto de un consumer para un conjunto de candidatos.

  ## Ejemplos

      iex> Gunther.Selector.Server.get_state(:default, [:a])
      %{}
  """
  @spec get_state(atom(), [atom()]) :: map()
  def get_state(consumer, candidates) do
    table = GenServer.call(__MODULE__, :table)
    {consumer, hash} = state_key(consumer, candidates)

    case :ets.lookup(table, {consumer, hash}) do
      [{_key, state}] -> state
      [] -> %{}
    end
  end

  @doc """
  Guarda el estado de reparto.

  ## Ejemplos

      iex> Gunther.Selector.Server.put_state(:default, [:a], %{index: 1})
      :ok
  """
  @spec put_state(atom(), [atom()], map()) :: :ok
  def put_state(consumer, candidates, state) do
    GenServer.call(__MODULE__, {:put_state, consumer, candidates, state})
  end

  @doc """
  El número de estados guardados.
  """
  @spec size() :: non_neg_integer()
  def size do
    table = GenServer.call(__MODULE__, :table)
    :ets.info(table, :size)
  end

  @impl GenServer
  def handle_call({:put_state, consumer, candidates, state}, _from, server_state) do
    {consumer, hash} = state_key(consumer, candidates)
    key = {consumer, hash}

    if :ets.info(server_state.table, :size) >= server_state.max_states and
         :ets.lookup(server_state.table, key) == [] do
      evict_one(server_state.table)
    end

    :ets.insert(server_state.table, {key, state})
    {:reply, :ok, server_state}
  end

  def handle_call(:table, _from, state), do: {:reply, state.table, state}

  defp evict_one(table) do
    case :ets.first(table) do
      :"$end_of_table" -> :ok
      key -> :ets.delete(table, key)
    end
  end
end
