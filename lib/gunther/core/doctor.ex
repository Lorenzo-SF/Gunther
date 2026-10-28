defmodule Gunther.Doctor do
  @moduledoc """
  Las calibraciones que necesita la configuracion (SPEC §11.3).

  ## `calibrate_overhead/2`

  La **convencion B** de la medida (la del sistema) necesita un
  `overhead_mib` por backend: lo que el sistema dice que hay y el motor no
  puede usar. En una GPU discreta es pequeno (la reserva del driver); en una
  iGPU puede ser la mayor parte de la RAM.

  El overhead se **mide**, no se supone: es la diferencia entre el total que
  reporta la herramienta del sistema y el total que ve el motor para el
  **mismo** device fisico.

      overhead = max(0, total_sistema − total_motor)

  ## La procedencia

  Un numero sin procedencia no vale: la calibracion devuelve **de donde**
  sale cada valor (backend, las dos herramientas, los dos totales, y el
  instante). `calibrate_overhead/2` devuelve el numero —que es lo que pide
  el contrato— y `calibrate_overhead_detail/2` el numero con su
  procedencia.

  ## El emparejamiento

  Se calibra **un device fisico a la vez**, nunca la media de varios: si un
  device no tiene pareja inequivoca, el resultado es un error
  (`:mapping_required`), porque un device nunca mezcla fuentes (D-28,
  D-89).

  ## Ejemplos

      iex> Gunther.Doctor.calibrate_overhead(:cuda, engine_devices: [], system_devices: [])
      {:error, %Gunther.Error{code: :no_devices, message: "no hay devices que calibrar", retryable?: false, retry_after_ms: nil, details: %{}, cause: nil}}
  """

  alias Gunther.Detector
  alias Gunther.Error

  @type backend :: :cuda | :rocm | :vulkan | :metal

  @doc """
  Calibra el `overhead_mib` de un backend (la convencion B).

  ## Opciones

    * `:engine_devices` — los devices como los ve el motor.
    * `:system_devices` — los devices como los ve el sistema.
    * `:mapping` — el emparejamiento `nombre_del_motor => id_fisico`, tal
      como esta en `[[devices]]`.
    * `:allow` — la lista de permitidos de los comandos.

  ## Ejemplos

      iex> Gunther.Doctor.calibrate_overhead(:cuda, engine_devices: [], system_devices: [])
      {:error, %Gunther.Error{code: :no_devices, message: "no hay devices que calibrar", retryable?: false, retry_after_ms: nil, details: %{}, cause: nil}}
  """
  @spec calibrate_overhead(backend(), keyword()) :: {:ok, non_neg_integer()} | {:error, Error.t()}
  def calibrate_overhead(backend, opts) do
    case calibrate_overhead_detail(backend, opts) do
      {:ok, %{mib: mib}} -> {:ok, mib}
      {:error, error} -> {:error, error}
    end
  end

  @doc """
  Como `calibrate_overhead/2`, pero con la **procedencia** del numero.

  ## Ejemplos

      iex> Gunther.Doctor.calibrate_overhead_detail(:cuda, engine_devices: [], system_devices: [])
      {:error, %Gunther.Error{code: :no_devices, message: "no hay devices que calibrar", retryable?: false, retry_after_ms: nil, details: %{}, cause: nil}}
  """
  @spec calibrate_overhead_detail(backend(), keyword()) ::
          {:ok, %{mib: non_neg_integer(), provenance: map()}} | {:error, Error.t()}
  def calibrate_overhead_detail(backend, opts) do
    with {:ok, engine} <- engine_devices(opts),
         {:ok, system} <- system_devices(backend, opts),
         {:ok, pairs} <- pair(engine, system, opts) do
      measurements = Enum.map(pairs, &measure_pair(&1, backend, system))

      # El overhead por backend es el **peor caso**: si un device tiene mas
      # overhead que otro, la capacidad que se puede garantizar es la del
      # que peor se comporta.
      mib = measurements |> Enum.map(& &1.overhead_mib) |> Enum.max(fn -> 0 end)

      provenance = %{
        backend: backend,
        measured_at: DateTime.utc_now(),
        devices: measurements,
        method: "max(0, total_sistema - total_motor)"
      }

      {:ok, %{mib: mib, provenance: provenance}}
    end
  end

  # --- internos ---------------------------------------------------------

  defp engine_devices(opts) do
    case Keyword.get(opts, :engine_devices) do
      nil -> {:error, Error.new(:no_devices, "no hay devices del motor para calibrar")}
      [] -> {:error, Error.new(:no_devices, "no hay devices que calibrar")}
      devices -> {:ok, devices}
    end
  end

  defp system_devices(backend, opts) do
    case Keyword.get(opts, :system_devices) do
      nil ->
        Detector.Fabricante.devices(Keyword.put(opts, :backend, backend))

      [] ->
        {:error, Error.new(:no_devices, "no hay devices del sistema para calibrar")}

      devices ->
        {:ok, devices}
    end
  end

  # El emparejamiento: explicito si esta; por posicion si hay **un solo**
  # device fisico (§11.8); si no, error.
  defp pair(engine, system, opts) do
    mapping = Keyword.get(opts, :mapping, %{})

    pairs =
      Enum.map(engine, fn device ->
        id =
          Map.get(mapping, device.name) ||
            Map.get(mapping, device.physical_id) ||
            if length(system) == 1, do: List.first(system).physical_id

        {device, id}
      end)

    case Enum.find(pairs, fn {_device, id} -> is_nil(id) end) do
      nil ->
        {:ok, pairs}

      {device, _id} ->
        {:error,
         Error.new(:mapping_required, "el device #{device.name} no tiene pareja inequivoca",
           details: %{device: device.name}
         )}
    end
  end

  defp measure_pair({engine_device, id}, backend, system) do
    system_device = Enum.find(system, &(&1.physical_id == id))

    total_sistema = system_device && system_device.capacity_mib
    total_motor = engine_device.capacity_mib

    overhead =
      if is_nil(total_sistema) do
        0
      else
        max(0, total_sistema - total_motor)
      end

    %{
      engine_device: engine_device.name,
      system_device: id,
      backend: backend,
      total_sistema_mib: total_sistema,
      total_motor_mib: total_motor,
      overhead_mib: overhead
    }
  end
end
