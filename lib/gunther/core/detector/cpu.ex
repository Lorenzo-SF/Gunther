defmodule Gunther.Detector.Cpu do
  @moduledoc """
  La CPU la **sintetiza** este detector (SPEC §11.7).

  ## Por que un detector propio

  La CPU **no aparece** en `--list-devices`: el motor filtra los devices de
  CPU. Pero el motor puede cargar un modelo en CPU, asi que Gunther tiene que
  conocerla: su capacidad es la **memoria del sistema**.

  ## No se reserva en el ledger de VRAM

  Un device de CPU tiene `reservable: false`. El ledger de VRAM (§11.3) lleva
  la memoria de las GPU; la RAM del sistema no se reparte por reservas: se
  compete por ella como por cualquier otro recurso del sistema, y meterla
  en el mismo ledger mezclaria dos cosas que no se mezclan.

  ## Root

  Correr como root se avisa, pero no es un error: un contenedor suele
  arrancar como root y eso no invalida la medida.

  ## Ejemplos

      iex> {:ok, [device]} = Gunther.Detector.Cpu.devices([])
      iex> device.physical_id
      "cpu"
  """

  @behaviour Gunther.Detector

  alias Trebejo.OS

  @impl Gunther.Detector
  def devices(_opts) do
    root? = OS.root?()

    if root? do
      require Logger

      Logger.warning("Gunther: el proceso corre como root; la medida de la CPU sigue siendo valida")
    end

    {:ok,
     [
       %{
         physical_id: "cpu",
         name: "CPU",
         description: "CPU del sistema",
         backend: :cpu,
         backend_name: "CPU",
         # La CPU no es memoria unificada de GPU: es la del sistema (§11.8).
         kind: :discrete,
         capacity_mib: OS.total_memory_mb(),
         free_mib: nil,
         usable: true,
         reason: nil,
         # La CPU no se reserva en el ledger de VRAM (§11.7).
         reservable: false,
         arch: OS.arch(),
         cpu_count: OS.cpu_count(),
         root?: root?
       }
     ]}
  end

  @impl Gunther.Detector
  def measure("cpu", _opts) do
    {:ok,
     %{
       total_mib: OS.total_memory_mb(),
       free_mib: nil,
       attribution: :none,
       source: :system,
       processes: nil
     }}
  end

  def measure(_physical_id, _opts), do: {:error, :device_not_found}
end
