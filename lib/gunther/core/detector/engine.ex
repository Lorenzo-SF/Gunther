defmodule Gunther.Detector.Engine do
  @moduledoc """
  Detecta los devices con el binario del engine (SPEC §5.12, D-59).

  ## Por que el binario

  El detector **mide**; la config **declara** (§11.3). La capacidad y la
  libre de un device salen de `--list-devices` del propio motor, que es la
  convencion A: una sola fuente de medida, la del motor.

  ## Por que `Gunther.Command`

  `Gunther.Command` es la **unica puerta de ejecucion** (§3.4). El detector
  no llama a `System.cmd`: pasa por la puerta, con su lista de permitidos.
  Eso lo comprueba `scripts/check_boundaries.sh`, que CI ejecuta.

  ## La convencion B

  La convencion B (la del sistema: `nvidia-smi`, `rocm-smi`, ...) es otra
  herramienta y exige `Doctor.calibrate_overhead/2` para el `overhead_mib`.
  No esta aqui: es la puerta G-11, y se implementa cuando se sepa el
  emparejamiento entre el identificador del sistema y el nombre del motor.

  ## Ejemplos

      iex> Gunther.Detector.Engine.devices([])
      {:error, :binary_required}

      iex> {:error, error} = Gunther.Detector.Engine.devices(binary: "/x", allow: ["/x"])
      iex> error.code
      :command_blocked
  """

  @behaviour Gunther.Detector

  alias Gunther.Detector.LlamaCpp

  @impl Gunther.Detector
  def devices(opts) do
    with {:ok, binary} <- binary(opts),
         {:ok, output} <- run(binary, opts) do
      LlamaCpp.parse(output)
    end
  end

  @impl Gunther.Detector
  def measure(physical_id, opts) do
    with {:ok, binary} <- binary(opts),
         {:ok, output} <- run(binary, opts),
         {:ok, devices} <- LlamaCpp.parse(output) do
      case Enum.find(devices, &(&1.physical_id == physical_id)) do
        nil ->
          {:error, :device_not_found}

        device ->
          {:ok,
           %{
             total_mib: device.capacity_mib,
             free_mib: device.free_mib,
             attribution: :none,
             source: :engine,
             processes: nil
           }}
      end
    end
  end

  # El binario del engine. Sin el, no se puede medir: no se adivina.
  defp binary(opts) do
    case Keyword.get(opts, :binary) do
      binary when is_binary(binary) and binary != "" -> {:ok, binary}
      _other -> {:error, :binary_required}
    end
  end

  # La ejecucion. El `:runner` permite probar el detector sin el binario
  # (y sin una GPU): por defecto, la puerta de ejecucion.
  defp run(binary, opts) do
    result =
      case Keyword.get(opts, :runner) do
        runner when is_function(runner, 3) ->
          runner.(binary, ["--list-devices"], opts)

        _other ->
          Gunther.Command.run(binary, ["--list-devices"],
            allow: Keyword.get(opts, :allow, []),
            timeout_ms: Keyword.get(opts, :timeout_ms, 30_000)
          )
      end

    case result do
      {:ok, %{stdout: output}} -> {:ok, output}
      {:ok, output} when is_binary(output) -> {:ok, output}
      {:error, error} -> {:error, error}
    end
  end
end
