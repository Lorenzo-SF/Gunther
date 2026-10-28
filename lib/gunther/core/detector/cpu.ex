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

  ## Una lectura que no se pudo hacer no es un dato

  `Trebejo.OS` ejecuta sus comandos por un shell. Si ese shell escribe algo
  en la salida (por ejemplo, el error de un `.bashrc` que no existe), el
  valor parseado queda **contaminado** y `Trebejo.OS` degrada en silencio:
  devuelve `:unknown` en vez de la arquitectura, el numero de cores del
  planificador en vez de los del sistema, y `false` en vez de `true` para
  root.

  Aqui eso **no se publica como si fuera verdad**. Si la lectura no es
  creible, el device sale con `usable: false` y `reason: :memory_unknown`, y
  los datos que no se pudieron leer van a `nil` (el tipo lo permite). Un
  device con `usable: false` no entra en el reparto, asi que un dato falso
  no llega a ninguna decision.

  ## Ejemplos

      iex> {:ok, [device]} = Gunther.Detector.Cpu.devices([])
      iex> device.physical_id
      "cpu"
  """

  @behaviour Gunther.Detector

  alias Trebejo.OS

  @impl Gunther.Detector
  def devices(opts) do
    # La lectura se puede sustituir para las pruebas: el detector no debe
    # depender de como sea la maquina en la que corre (el `docs/03-estrategia-
    # de-pruebas.md` pide un doble para las mediciones).
    os = Keyword.get(opts, :os, OS)

    arch = os.arch()
    capacity = os.total_memory_mb()
    cpu_count = os.cpu_count()
    root? = os.root?()

    # La lectura es creible si dice que arquitectura tiene y cuanta memoria.
    # Si no, no se publica ningun dato que no se haya podido leer.
    if credible?(arch, capacity) do
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
           capacity_mib: capacity,
           free_mib: nil,
           usable: true,
           reason: nil,
           # La CPU no se reserva en el ledger de VRAM (§11.7).
           reservable: false,
           arch: arch,
           cpu_count: cpu_count,
           root?: root?
         }
       ]}
    else
      {:ok,
       [
         %{
           physical_id: "cpu",
           name: "CPU",
           description: "CPU del sistema",
           backend: :cpu,
           backend_name: "CPU",
           kind: :discrete,
           capacity_mib: 0,
           free_mib: nil,
           # No se pudo leer el sistema: el device no es usable.
           usable: false,
           reason: :memory_unknown,
           reservable: false,
           arch: arch,
           # Lo que no se pudo leer no se inventa.
           cpu_count: nil,
           root?: nil
         }
       ]}
    end
  end

  @impl Gunther.Detector
  def measure("cpu", opts) do
    os = Keyword.get(opts, :os, OS)
    capacity = os.total_memory_mb()

    if capacity > 0 do
      {:ok,
       %{
         total_mib: capacity,
         free_mib: nil,
         attribution: :none,
         source: :system,
         processes: nil
       }}
    else
      {:error, :memory_unknown}
    end
  end

  def measure(_physical_id, _opts), do: {:error, :device_not_found}

  # Una lectura es creible cuando dice que arquitectura tiene y cuanta
  # memoria. `:unknown` es lo que devuelve `Trebejo.OS` cuando su comando
  # falla, no una arquitectura.
  defp credible?(arch, capacity), do: arch != :unknown and capacity > 0
end
