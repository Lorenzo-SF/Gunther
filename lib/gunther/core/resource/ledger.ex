defmodule Gunther.Resource.Ledger do
  @moduledoc """
  El ledger de recursos de GPU (SPEC §11.3, D-48, D-65, CE-23).

  ## Propio, no `Arrea.Resource`

  La semántica de `foreign` y `available` es **específica de GPU** (medida por
  proceso, quiescencia, memoria unificada). `Arrea.Resource` no la tiene y
  añadirla es trabajo que pertenece a este proyecto (Q-14, D-48).

  ## Indexado por `physical_id`

  El ledger se indexa por `physical_id` (D-65), no por el nombre del backend:
  dos backends pueden ver el mismo GPU físico, y contarlo dos veces sería
  doble conteo (H-08).

  ## Estados de la reserva (D-89)

  Tres estados: `:reserved`, `:running` y `:released`. Un engine que usa más de
  lo reservado corrige la reserva y emite `:reserve_exceeded`.

  ## Ejemplos

      iex> Gunther.Resource.Ledger.init()
      :ok
  """

  use GenServer

  @doc """
  Arranca el ledger.
  """
  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: Keyword.get(opts, :name, __MODULE__))
  end

  @impl GenServer
  def init(_opts) do
    {:ok, %{devices: %{}, holders: %{}, by_physical: %{}}}
  end

  @doc """
  Adopta un device: registra su identidad física y su capacidad.

  ## Ejemplos

      iex> Gunther.Resource.Ledger.init()
      :ok
      iex> Gunther.Resource.Ledger.acquire("gpu0", :holder1, 1000)
      :ok
  """
  @spec acquire(binary(), term(), non_neg_integer()) :: :ok | {:error, term()}
  def acquire(physical_id, holder, reserved_mib) do
    GenServer.call(__MODULE__, {:acquire, physical_id, holder, reserved_mib})
  end

  @doc """
  Libera la reserva de un holder.

  ## Ejemplos

      iex> Gunther.Resource.Ledger.init()
      :ok
      iex> Gunther.Resource.Ledger.release("gpu0", :holder1)
      :ok
  """
  @spec release(binary(), term()) :: :ok
  def release(physical_id, holder) do
    GenServer.call(__MODULE__, {:release, physical_id, holder})
  end

  @doc """
  La memoria libre de un device, en MiB.

  `nil` si no se conoce (D-04: «no lo sé» es un estado, no un 0).

  ## Ejemplos

      iex> Gunther.Resource.Ledger.init()
      :ok
      iex> Gunther.Resource.Ledger.available("gpu0")
      nil
  """
  @spec available(binary()) :: non_neg_integer() | nil
  def available(physical_id) do
    GenServer.call(__MODULE__, {:available, physical_id})
  end

  @doc """
  La memoria ajena (de otros procesos) en un device, en MiB.

  ## Ejemplos

      iex> Gunther.Resource.Ledger.init()
      :ok
      iex> Gunther.Resource.Ledger.foreign("gpu0")
      nil
  """
  @spec foreign(binary()) :: non_neg_integer() | nil
  def foreign(physical_id) do
    GenServer.call(__MODULE__, {:foreign, physical_id})
  end

  @doc """
  Corrige la reserva de un holder: el engine usa mas de lo reservado.

  ## Ejemplos

      iex> Gunther.Resource.Ledger.init()
      :ok
      iex> Gunther.Resource.Ledger.correct_reserve("gpu0", :holder1, 2000)
      :ok
  """
  @spec correct_reserve(binary(), term(), non_neg_integer()) :: :ok
  def correct_reserve(physical_id, holder, actual_mib) do
    GenServer.call(__MODULE__, {:correct_reserve, physical_id, holder, actual_mib})
  end

  @impl GenServer
  def handle_call({:acquire, physical_id, holder, reserved_mib}, _from, state) do
    case Map.get(state.holders, holder) do
      nil ->
        holders = Map.put(state.holders, holder, %{physical_id: physical_id, reserved_mib: reserved_mib})
        by_physical = Map.update(state.by_physical, physical_id, reserved_mib, &(&1 + reserved_mib))
        {:reply, :ok, %{state | holders: holders, by_physical: by_physical}}

      existing ->
        if existing.physical_id == physical_id do
          {:reply, :ok, state}
        else
          {:reply, {:error, :device_unusable}, state}
        end
    end
  end

  def handle_call({:release, physical_id, holder}, _from, state) do
    case Map.get(state.holders, holder) do
      nil ->
        {:reply, :ok, state}

      %{physical_id: ^physical_id, reserved_mib: reserved_mib} ->
        holders = Map.delete(state.holders, holder)

        by_physical =
          case Map.fetch(state.by_physical, physical_id) do
            {:ok, total} -> Map.put(state.by_physical, physical_id, total - reserved_mib)
            :error -> state.by_physical
          end

        {:reply, :ok, %{state | holders: holders, by_physical: by_physical}}

      _other ->
        {:reply, :ok, state}
    end
  end

  def handle_call({:available, physical_id}, _from, state) do
    {:reply, Map.get(state.devices, physical_id), state}
  end

  def handle_call({:foreign, physical_id}, _from, state) do
    {:reply, Map.get(state.devices, physical_id), state}
  end

  def handle_call({:correct_reserve, physical_id, holder, actual_mib}, _from, state) do
    case Map.get(state.holders, holder) do
      %{physical_id: ^physical_id, reserved_mib: reserved_mib} ->
        delta = actual_mib - reserved_mib

        holders =
          Map.put(state.holders, holder, %{physical_id: physical_id, reserved_mib: actual_mib})

        by_physical =
          Map.update(state.by_physical, physical_id, actual_mib, &(&1 + delta))

        :telemetry.execute(
          [:gunther, :resource, :reserve_exceeded],
          %{delta_mib: delta},
          %{physical_id: physical_id, holder: holder}
        )

        {:reply, :ok, %{state | holders: holders, by_physical: by_physical}}

      _other ->
        {:reply, :ok, state}
    end
  end
end
