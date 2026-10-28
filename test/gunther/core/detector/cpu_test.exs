defmodule Gunther.Detector.CpuTest do
  use ExUnit.Case, async: true

  import ExUnit.CaptureLog

  alias Gunther.Detector.Cpu

  describe "los devices" do
    test "la CPU se sintetiza con un id fijo" do
      assert {:ok, [device]} = Cpu.devices([])
      assert device.physical_id == "cpu"
      assert device.backend == :cpu
      assert device.usable == true
    end

    test "la capacidad es la memoria del sistema" do
      assert {:ok, [device]} = Cpu.devices([])
      assert device.capacity_mib > 0
    end

    test "la CPU no se reserva en el ledger de VRAM" do
      # §11.7: la capacidad es la memoria del sistema, pero no se reparte por
      # reservas: el ledger de VRAM es de las GPU.
      assert {:ok, [device]} = Cpu.devices([])
      assert device.reservable == false
    end

    test "detecta la arquitectura y el numero de nucleos" do
      assert {:ok, [device]} = Cpu.devices([])
      assert device.arch in [:x86_64, :arm64, :arm, :i386, :unknown]
      assert device.cpu_count > 0
    end

    test "avisa si corre como root, pero no es un error" do
      log =
        capture_log(fn ->
          assert {:ok, [_device]} = Cpu.devices([])
        end)

      # El aviso depende de como corre la maquina: lo que se comprueba es
      # que el resultado es un device valido, no que avise o no.
      assert log == "" or log =~ "root"
    end
  end

  describe "medir" do
    test "la CPU se mide con la memoria del sistema" do
      assert {:ok, measurement} = Cpu.measure("cpu", [])
      assert measurement.total_mib > 0
      assert measurement.source == :system
      assert measurement.attribution == :none
    end

    test "un device que no es la CPU no existe" do
      assert {:error, :device_not_found} = Cpu.measure("gpu0", [])
    end
  end
end
