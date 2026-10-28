defmodule Gunther.Detector.CpuTest do
  use ExUnit.Case, async: true

  import ExUnit.CaptureLog

  alias Gunther.Detector.Cpu

  # Un doble de la lectura del sistema, **como modulo**: el detector llama
  # `os.arch()`, `os.cpu_count()`, `os.total_memory_mb()` y `os.root?()`, y
  # un mapa no se puede usar para eso sin ambiguedad.
  #
  # Los tests del detector **no** pueden depender de la maquina en la que se
  # corren: `Trebejo.OS` ejecuta por un shell, y si ese shell escribe algo
  # en la salida (el error de un `.bashrc` que no existe, por ejemplo) los
  # valores se contaminan.
  defmodule LecturaOk do
    def arch, do: :x86_64
    def cpu_count, do: 8
    def total_memory_mb, do: 16_384
    def root?, do: false
  end

  defmodule LecturaRoot do
    def arch, do: :x86_64
    def cpu_count, do: 8
    def total_memory_mb, do: 16_384
    def root?, do: true
  end

  # La lectura que no se pudo hacer: `Trebejo.OS` devuelve `:unknown` cuando
  # su comando falla, y eso no es una arquitectura.
  defmodule LecturaFallida do
    def arch, do: :unknown
    def cpu_count, do: 1
    def total_memory_mb, do: 0
    def root?, do: false
  end

  defmodule LecturaArm do
    def arch, do: :arm64
    def cpu_count, do: 12
    def total_memory_mb, do: 16_384
    def root?, do: false
  end

  defmodule LecturaSinMemoria do
    def arch, do: :x86_64
    def cpu_count, do: 8
    def total_memory_mb, do: 0
    def root?, do: false
  end

  describe "los devices" do
    test "la CPU se sintetiza con un id fijo" do
      assert {:ok, [device]} = Cpu.devices(os: LecturaOk)
      assert device.physical_id == "cpu"
      assert device.backend == :cpu
      assert device.usable == true
    end

    test "la capacidad es la memoria del sistema" do
      assert {:ok, [device]} = Cpu.devices(os: LecturaOk)
      assert device.capacity_mib == 16_384
    end

    test "la CPU no se reserva en el ledger de VRAM" do
      # §11.7: la capacidad es la memoria del sistema, pero no se reparte por
      # reservas: el ledger de VRAM es de las GPU.
      assert {:ok, [device]} = Cpu.devices(os: LecturaOk)
      assert device.reservable == false
    end

    test "detecta la arquitectura y el numero de nucleos" do
      assert {:ok, [device]} = Cpu.devices(os: LecturaArm)
      assert device.arch == :arm64
      assert device.cpu_count == 12
    end

    test "avisa si corre como root, pero no es un error" do
      # `with_log` y NO `capture_log`: `capture_log` captura el log de **todo**
      # el arbol de procesos durante la ventana, y con los tests en paralelo
      # se cuela el log de otros tests. Entonces `log` podia ser cualquier
      # cosa, y el aserto de abajo fallaba de forma intermitente.
      # `with_log` solo captura el del proceso actual, y devuelve el
      # resultado de la funcion **junto con** el log.
      {_resultado, log} =
        with_log(fn ->
          assert {:ok, [_device]} = Cpu.devices(os: LecturaRoot)
        end)

      assert log =~ "root",
             "corriendo como root tiene que haber aviso: #{inspect(log)}"
    end

    test "sin root no avisa" do
      {_resultado, log} =
        with_log(fn ->
          assert {:ok, [_device]} = Cpu.devices(os: LecturaOk)
        end)

      assert log == "", "sin root no hay nada que avisar: #{inspect(log)}"
    end

    test "una lectura que no se pudo hacer no se publica como si fuera verdad" do
      # `Trebejo.OS` devuelve `:unknown` cuando su comando falla: eso no es
      # una arquitectura, es una lectura que no se pudo hacer.
      assert {:ok, [device]} = Cpu.devices(os: LecturaFallida)

      assert device.usable == false
      assert device.reason == :memory_unknown
      # Lo que no se pudo leer no se inventa.
      assert device.cpu_count == nil
      assert device.root? == nil
    end

    test "sin memoria el device no es usable" do
      assert {:ok, [device]} = Cpu.devices(os: LecturaSinMemoria)

      assert device.usable == false
      assert device.reason == :memory_unknown
    end

    test "un device no usable no se reparte" do
      # La consecuencia de marcarlo no usable: el Placer lo deja fuera, de
      # modo que un dato falso no llega a ninguna decision.
      assert {:ok, [device]} = Cpu.devices(os: LecturaFallida)
      assert device.reservable == false
    end
  end

  describe "medir" do
    test "la CPU se mide con la memoria del sistema" do
      assert {:ok, measurement} = Cpu.measure("cpu", os: LecturaOk)
      assert measurement.total_mib == 16_384
      assert measurement.source == :system
      assert measurement.attribution == :none
    end

    test "sin memoria la medida es un error, no un cero" do
      assert {:error, :memory_unknown} =
               Cpu.measure("cpu", os: LecturaSinMemoria)
    end

    test "un device que no es la CPU no existe" do
      assert {:error, :device_not_found} = Cpu.measure("gpu0", os: LecturaOk)
    end
  end
end
