defmodule Gunther.Resource.Ledger do
  @moduledoc """
  El ledger de recursos de GPU (SPEC §11.3, D-48, D-65, CE-23).

  ## Propio, no `Arrea.Resource`

  La semántica de `foreign` y `available` es **específica de GPU** (medida
  por proceso, quiescencia, memoria unificada). `Arrea.Resource` no la tiene y
  añadirla es trabajo que pertenece a este proyecto (Q-14, D-48).

  ## Indexado por `physical_id`

  El ledger se indexa por `physical_id` (D-65), no por el nombre del backend:
  dos backends pueden ver el mismo GPU físico, y contarlo dos veces sería
  doble conteo (H-08).

  ## Una sola fuente de medida por device (D-28, D-89)

  La fórmula miente si `capacity` y `free` salen de fuentes distintas, así
  que cada device usa **una** de dos convenciones y nunca las mezcla.

  | Convención | `capacity` y `free`                    | `foreign`                             |
  | ---------- | ------------------------------------- | ------------------------------------- |
  | A (defecto) | los del motor (`--list-devices`)     | regla de quiescencia                  |
  | B          | los del sistema, **de la misma herramienta** | suma por proceso (si hay atribución) |

  La convención B **exige** `overhead_mib`: sin él, la capacidad sería
  falsa, y el device queda `device_unusable` con `:overhead_unknown`.

  ## La memoria ajena (`foreign`)

  | Caso                                                          | `foreign`                                                    |
  | ------------------------------------------------------------- | ------------------------------------------------------------ |
  | Convencion B con `attribution: :per_process`                  | Suma de los procesos cuyo `pid` no es un engine de Gunther    |
  | Convencion A, o B sin atribucion, y **ningun** engine esta en `:reserved` (quiescente) | `max(0, capacity − free_medido − Σ reserved de los engines en `:running`)` |
  | Igual, pero hay un engine en transicion                       | Se **congela** el ultimo valor medido en quiescencia          |
  | Nunca medido en quiescencia                                    | `device_unusable` con `:foreign_unknown`                      |

  ## Disponible

      available = max(0, min(capacity − foreign − gunther_used, free_medido_ahora))

  El `min` es **seguro en ambos sentidos**: con una reserva pendiente
  (aún no asignada en el device) gana el primer término, que ya la
  descuenta; con memoria ajena que crece tras la ultima medida gana el
  segundo.

  ## Los holders

  El `holder` es `{alias, port, make_ref()}`. **No hay titular `:system`**:
  la memoria ajena se mide aparte, no se disfraza de una reserva.

  ## Ejemplos

      iex> Gunther.Resource.Ledger.reset()
      :ok
  """

  use GenServer

  @typedoc "Un device adoptado, con su convencion de medida."
  @type device :: %{
          physical_id: String.t(),
          node: atom(),
          convention: :a | :b,
          kind: :discrete | :unified,
          capacity_mib: non_neg_integer(),
          free_mib: non_neg_integer() | nil,
          attribution: :per_process | :none,
          overhead_mib: non_neg_integer() | nil,
          max_mib: non_neg_integer() | nil,
          reserve_mib: non_neg_integer() | nil
        }

  @typedoc "Una medida del device, tal y como la da el Detector."
  @type measurement :: %{
          total_mib: non_neg_integer(),
          free_mib: non_neg_integer(),
          attribution: :per_process | :none,
          source: :engine | :system,
          processes: [%{pid: integer(), mib: non_neg_integer()}] | nil
        }

  @doc """
  Arranca el ledger.
  """
  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: Keyword.get(opts, :name, __MODULE__))
  end

  @doc """
  Vacia el ledger. Para tests.
  """
  @spec reset() :: :ok
  def reset, do: GenServer.call(__MODULE__, :reset)

  @doc """
  Adopta un device: registra su identidad física, su convención de medida y
  su capacidad.

  ## Ejemplos

      iex> Gunther.Resource.Ledger.reset()
      :ok
  """
  @spec adopt(device()) :: :ok
  def adopt(device), do: GenServer.call(__MODULE__, {:adopt, device})

  @doc """
  Adquiere `reserved_mib` para un holder en un device.

  `{:error, :no_room}` si no cabe; `{:error, :device_unusable}` si el
  device no se puede usar.

  ## Ejemplos

      iex> Gunther.Resource.Ledger.reset()
      :ok
  """
  @spec acquire(String.t(), term(), non_neg_integer()) ::
          :ok | {:error, :no_room | :device_unusable}
  def acquire(physical_id, holder, reserved_mib) do
    GenServer.call(__MODULE__, {:acquire, physical_id, holder, reserved_mib})
  end

  @doc """
  Libera la reserva de un holder. Es idempotente.
  """
  @spec release(String.t(), term()) :: :ok
  def release(physical_id, holder) do
    GenServer.call(__MODULE__, {:release, physical_id, holder})
  end

  @doc """
  La memoria libre de un device, en MiB.

  `nil` si no se conoce (D-04: «no lo sé» es un estado, no un 0).
  """
  @spec available(String.t()) :: non_neg_integer() | nil
  def available(physical_id), do: GenServer.call(__MODULE__, {:available, physical_id})

  @doc """
  La capacidad de un device, en MiB.
  """
  @spec capacity(String.t()) :: non_neg_integer() | nil
  def capacity(physical_id), do: GenServer.call(__MODULE__, {:capacity, physical_id})

  @doc """
  Lo que usan los holders de un device, en MiB.
  """
  @spec used(String.t()) :: non_neg_integer()
  def used(physical_id), do: GenServer.call(__MODULE__, {:used, physical_id})

  @doc """
  La memoria ajena (de otros procesos) en un device, en MiB.

  `nil` si nunca se ha medido en quiescencia.
  """
  @spec foreign(String.t()) :: non_neg_integer() | nil
  def foreign(physical_id), do: GenServer.call(__MODULE__, {:foreign, physical_id})

  @doc """
  Los holders de un device.
  """
  @spec holders(String.t()) :: [term()]
  def holders(physical_id), do: GenServer.call(__MODULE__, {:holders, physical_id})

  @doc """
  ¿Se puede usar este device?
  """
  @spec usable?(String.t()) :: boolean()
  def usable?(physical_id), do: GenServer.call(__MODULE__, {:usable?, physical_id})

  @doc """
  Por qué no se puede usar el device, si no se puede.
  """
  @spec reason(String.t()) :: atom() | nil
  def reason(physical_id), do: GenServer.call(__MODULE__, {:reason, physical_id})

  @doc """
  Re-mide un device.

  La medida viene del Detector (§5.12). Si la convencion es B con
  atribucion por proceso, `own_pids` son los pids de los engines de
  Gunther: el resto se cuenta como memoria ajena.

  ## Ejemplos

      iex> Gunther.Resource.Ledger.reset()
      :ok
  """
  @spec resync(String.t(), measurement(), keyword()) :: :ok
  def resync(physical_id, measurement, opts \\ []) do
    GenServer.call(__MODULE__, {:resync, physical_id, measurement, opts})
  end

  @doc """
  Cambia el estado de un holder: `:reserved` o `:running`.

  El estado decide si el device esta en **quiescencia**: un engine
  reservado, arrancando o parando hace que la memoria ajena se congele.
  """
  @spec set_holder_state(String.t(), term(), :reserved | :running) :: :ok
  def set_holder_state(physical_id, holder, state) do
    GenServer.call(__MODULE__, {:set_holder_state, physical_id, holder, state})
  end

  @doc """
  Corrige la reserva de un holder: el engine usa mas de lo reservado.
  """
  @spec correct_reserve(String.t(), term(), non_neg_integer()) :: :ok
  def correct_reserve(physical_id, holder, actual_mib) do
    GenServer.call(__MODULE__, {:correct_reserve, physical_id, holder, actual_mib})
  end

  @doc """
  Se suscribe a los cambios de un device, o de todos con `:all`.
  """
  @spec subscribe(String.t() | :all, pid()) :: :ok
  def subscribe(physical_id, pid \\ self()), do: GenServer.call(__MODULE__, {:subscribe, physical_id, pid})

  @impl GenServer
  def init(_opts) do
    {:ok, new_state()}
  end

  @impl GenServer
  def handle_call(:reset, _from, _state) do
    {:reply, :ok, new_state()}
  end

  def handle_call({:adopt, device}, _from, state) do
    state = put_in(state.devices[device.physical_id], new_device(device))
    {:reply, :ok, recompute(state)}
  end

  def handle_call({:acquire, physical_id, holder, reserved_mib}, _from, state) do
    case Map.get(state.devices, physical_id) do
      nil ->
        {:reply, {:error, :device_unusable}, state}

      device ->
        if device.usable do
          reserve(device, physical_id, holder, reserved_mib, state)
        else
          {:reply, {:error, :device_unusable}, state}
        end
    end
  end

  def handle_call({:release, physical_id, holder}, _from, state) do
    # Solo se libera lo que esta en ese device: liberar con el device
    # equivocado no toca nada.
    state =
      case Map.get(state.holders, holder) do
        %{physical_id: ^physical_id} -> %{state | holders: Map.delete(state.holders, holder)}
        _other -> state
      end

    {:reply, :ok, recompute(state)}
  end

  def handle_call({:available, physical_id}, _from, state) do
    case Map.get(state.devices, physical_id) do
      nil ->
        {:reply, nil, state}

      device ->
        {:reply, compute_available(device, used_of(state, physical_id), device.foreign_mib, device.free_mib), state}
    end
  end

  def handle_call({:capacity, physical_id}, _from, state) do
    {:reply, device_capacity(Map.get(state.devices, physical_id)), state}
  end

  def handle_call({:used, physical_id}, _from, state) do
    {:reply, used_of(state, physical_id), state}
  end

  def handle_call({:foreign, physical_id}, _from, state) do
    case Map.get(state.devices, physical_id) do
      nil -> {:reply, nil, state}
      device -> {:reply, device.foreign_mib, state}
    end
  end

  def handle_call({:holders, physical_id}, _from, state) do
    holders =
      state.holders
      |> Enum.filter(fn {_holder, info} -> info.physical_id == physical_id end)
      |> Enum.map(fn {holder, _info} -> holder end)
      |> Enum.sort()

    {:reply, holders, state}
  end

  def handle_call({:usable?, physical_id}, _from, state) do
    case Map.get(state.devices, physical_id) do
      nil -> {:reply, false, state}
      device -> {:reply, device.usable, state}
    end
  end

  def handle_call({:reason, physical_id}, _from, state) do
    case Map.get(state.devices, physical_id) do
      nil -> {:reply, nil, state}
      device -> {:reply, device.reason, state}
    end
  end

  def handle_call({:resync, physical_id, measurement, opts}, _from, state) do
    case Map.get(state.devices, physical_id) do
      nil ->
        {:reply, :ok, state}

      device ->
        own_pids = Keyword.get(opts, :own_pids, [])

        measurement =
          Map.merge(
            %{
              attribution: :none,
              source: :engine,
              processes: nil
            },
            measurement
          )

        device = %{
          device
          | free_mib: measurement.free_mib,
            attribution: measurement.attribution,
            measured_foreign_mib: measured_foreign(device, measurement, own_pids)
        }

        state = put_in(state.devices[physical_id], device)
        {:reply, :ok, recompute(state)}
    end
  end

  def handle_call({:set_holder_state, _physical_id, holder, holder_state}, _from, state) do
    case Map.get(state.holders, holder) do
      nil ->
        {:reply, :ok, state}

      info ->
        holders = Map.put(state.holders, holder, %{info | state: holder_state})
        state = %{state | holders: holders}
        {:reply, :ok, recompute(state)}
    end
  end

  def handle_call({:correct_reserve, physical_id, holder, actual_mib}, _from, state) do
    case Map.get(state.holders, holder) do
      %{physical_id: ^physical_id} = info ->
        holders =
          Map.put(state.holders, holder, %{info | reserved_mib: actual_mib})

        state = %{state | holders: holders}

        :telemetry.execute(
          [:gunther, :resource, :reserve_exceeded],
          %{delta_mib: actual_mib - info.reserved_mib},
          %{physical_id: physical_id, holder: holder}
        )

        {:reply, :ok, recompute(state)}

      _other ->
        {:reply, :ok, state}
    end
  end

  def handle_call({:subscribe, physical_id, pid}, _from, state) do
    subscribers =
      if physical_id == :all do
        Map.update(state.subscribers, :all, [pid], &[pid | &1])
      else
        Map.update(state.subscribers, physical_id, [pid], &[pid | &1])
      end

    {:reply, :ok, %{state | subscribers: subscribers}}
  end

  # La reserva: si cabe, se anota; si no, no hay sitio.
  defp reserve(device, physical_id, holder, reserved_mib, state) do
    used = used_of(state, physical_id)
    available = compute_available(device, used, device.foreign_mib, device.free_mib)

    if reserved_mib <= available do
      holders =
        Map.put(state.holders, holder, %{
          physical_id: physical_id,
          reserved_mib: reserved_mib,
          state: :reserved
        })

      {:reply, :ok, recompute(%{state | holders: holders})}
    else
      {:reply, {:error, :no_room}, state}
    end
  end

  # --- el estado ---------------------------------------------------------

  defp new_state do
    %{devices: %{}, holders: %{}, subscribers: %{}}
  end

  defp new_device(device) do
    %{
      physical_id: Map.fetch!(device, :physical_id),
      node: Map.get(device, :node, :local),
      convention: Map.get(device, :convention, :a),
      kind: Map.get(device, :kind, :discrete),
      capacity_mib: Map.fetch!(device, :capacity_mib),
      free_mib: Map.get(device, :free_mib),
      attribution: Map.get(device, :attribution, :none),
      overhead_mib: Map.get(device, :overhead_mib),
      max_mib: Map.get(device, :max_mib),
      reserve_mib: Map.get(device, :reserve_mib),
      measured_foreign_mib: nil,
      foreign_mib: nil,
      usable: true,
      reason: nil
    }
  end

  # Recalcula `foreign` y la usabilidad de cada device.
  defp recompute(state) do
    devices =
      Map.new(state.devices, fn {physical_id, device} ->
        holders = holders_of(state, physical_id)
        {physical_id, compute_device(device, holders)}
      end)

    %{state | devices: devices}
  end

  defp compute_device(device, holders) do
    cond do
      device.kind == :unified and (is_nil(device.max_mib) or is_nil(device.reserve_mib)) ->
        %{device | usable: false, reason: :unified_limit_required, foreign_mib: 0}

      device.convention == :b and is_nil(device.overhead_mib) ->
        %{device | usable: false, reason: :overhead_unknown, foreign_mib: 0}

      not is_nil(device.free_mib) and device.free_mib > device.capacity_mib ->
        %{device | usable: false, reason: :free_gt_total, foreign_mib: 0}

      true ->
        foreign = compute_foreign(device, holders)

        if is_nil(foreign) do
          %{device | usable: false, reason: :foreign_unknown}
        else
          %{device | usable: true, reason: nil, foreign_mib: foreign}
        end
    end
  end

  # La memoria ajena, segun la convencion.
  defp compute_foreign(device, holders) do
    if device.convention == :b and device.attribution == :per_process do
      device.measured_foreign_mib
    else
      compute_foreign_a(device, holders)
    end
  end

  # La convencion A: lo ajeno es lo que no es de Gunther, medido por la
  # diferencia entre la capacidad y la libre.
  defp compute_foreign_a(device, holders) do
    if is_nil(device.free_mib) do
      # Nunca medido: no se puede saber cuanto es ajeno.
      nil
    else
      foreign_a(device, holders)
    end
  end

  defp foreign_a(device, holders) do
    if quiescent?(holders) do
      running = running_reserved(holders)
      max(0, device.capacity_mib - device.free_mib - running)
    else
      # Hay un engine en transicion: se congela el ultimo valor
      # medido en quiescencia.
      device.foreign_mib
    end
  end

  # Un device esta en quiescencia si ningun engine suyo esta reservado
  # (arrancando o parando).
  defp quiescent?(holders) do
    Enum.all?(holders, fn holder -> holder.state == :running end)
  end

  defp running_reserved(holders) do
    Enum.reduce(holders, 0, fn holder, acc ->
      if holder.state == :running, do: acc + holder.reserved_mib, else: acc
    end)
  end

  # La memoria ajena medida por proceso: la suma de los procesos que no son
  # engines de Gunther.
  defp measured_foreign(device, measurement, own_pids) do
    if device.convention == :b and measurement.attribution == :per_process do
      sum_foreign(measurement.processes, own_pids)
    else
      nil
    end
  end

  defp sum_foreign(nil, _own_pids), do: nil

  defp sum_foreign(processes, own_pids) do
    processes
    |> Enum.reject(fn process -> process.pid in own_pids end)
    |> Enum.reduce(0, fn process, acc -> acc + process.mib end)
  end

  defp device_capacity(nil), do: nil

  defp device_capacity(device) do
    case device.convention do
      :b -> max(0, device.capacity_mib - (device.overhead_mib || 0))
      :a -> device.capacity_mib
    end
  end

  defp compute_available(device, used, foreign, free) do
    cond do
      is_nil(free) ->
        nil

      device.kind == :unified ->
        max(0, min(device.max_mib - device.reserve_mib - used, free))

      true ->
        max(0, min(device_capacity(device) - (foreign || 0) - used, free))
    end
  end

  defp used_of(state, physical_id) do
    state.holders
    |> Enum.filter(fn {_holder, info} -> info.physical_id == physical_id end)
    |> Enum.reduce(0, fn {_holder, info}, acc -> acc + info.reserved_mib end)
  end

  defp holders_of(state, physical_id) do
    state.holders
    |> Enum.filter(fn {_holder, info} -> info.physical_id == physical_id end)
    |> Enum.map(fn {_holder, info} -> info end)
  end
end
