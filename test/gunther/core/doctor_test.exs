defmodule Gunther.DoctorTest do
  use ExUnit.Case, async: true

  alias Gunther.Doctor

  # Los devices del motor: es lo que ve `--list-devices`.
  defp engine(overrides \\ []) do
    base = %{
      physical_id: "CUDA0",
      name: "CUDA0",
      description: "NVIDIA GeForce RTX 5080",
      backend: :cuda,
      capacity_mib: 15_109,
      free_mib: 12_000,
      usable: true,
      reason: nil
    }

    [Map.merge(base, Map.new(overrides))]
  end

  # Los devices del sistema: es lo que ve `nvidia-smi`.
  defp system(overrides \\ []) do
    base = %{
      physical_id: "GPU-abc",
      name: "NVIDIA GeForce RTX 5080",
      description: "NVIDIA GeForce RTX 5080",
      backend: :cuda,
      capacity_mib: 16_000,
      free_mib: 12_500,
      usable: true,
      reason: nil
    }

    [Map.merge(base, Map.new(overrides))]
  end

  describe "calibrate_overhead/2" do
    test "el overhead es la diferencia entre el total del sistema y el del motor" do
      opts = [engine_devices: engine(), system_devices: system()]

      assert {:ok, overhead} = Doctor.calibrate_overhead(:cuda, opts)
      assert overhead == 16_000 - 15_109
    end

    test "si el motor ve mas que el sistema, el overhead es cero" do
      opts = [
        engine_devices: engine(%{capacity_mib: 16_000}),
        system_devices: system(%{capacity_mib: 15_109})
      ]

      assert {:ok, 0} = Doctor.calibrate_overhead(:cuda, opts)
    end

    test "sin devices no hay calibracion" do
      assert {:error, error} = Doctor.calibrate_overhead(:cuda, engine_devices: [], system_devices: [])
      assert error.code == :no_devices
    end

    test "un device sin pareja inequivoca es un error, no una media" do
      # Dos devices del sistema y dos del motor, sin mapeo: emparejar por
      # posicion seria suposicion. El device nunca mezcla fuentes (D-28).
      engine_devices = [
        %{physical_id: "CUDA0", name: "CUDA0", capacity_mib: 15_109},
        %{physical_id: "CUDA1", name: "CUDA1", capacity_mib: 15_109}
      ]

      system_devices = [
        %{physical_id: "GPU-a", name: "a", capacity_mib: 16_000},
        %{physical_id: "GPU-b", name: "b", capacity_mib: 16_000}
      ]

      assert {:error, error} =
               Doctor.calibrate_overhead(:cuda,
                 engine_devices: engine_devices,
                 system_devices: system_devices
               )

      assert error.code == :mapping_required
    end

    test "el mapeo explicito empareja" do
      engine_devices = [
        %{physical_id: "CUDA0", name: "CUDA0", capacity_mib: 15_109},
        %{physical_id: "CUDA1", name: "CUDA1", capacity_mib: 15_109}
      ]

      system_devices = [
        %{physical_id: "GPU-a", name: "a", capacity_mib: 16_000},
        %{physical_id: "GPU-b", name: "b", capacity_mib: 17_000}
      ]

      opts = [
        engine_devices: engine_devices,
        system_devices: system_devices,
        mapping: %{"CUDA0" => "GPU-a", "CUDA1" => "GPU-b"}
      ]

      assert {:ok, overhead} = Doctor.calibrate_overhead(:cuda, opts)
      # El peor caso: 17_000 - 15_109.
      assert overhead == 1_891
    end

    test "con un solo device fisico se empareja sin mapeo" do
      # §11.8: salvo un unico device fisico, el mapeo es obligatorio.
      opts = [engine_devices: engine(), system_devices: system()]

      assert {:ok, _overhead} = Doctor.calibrate_overhead(:cuda, opts)
    end
  end

  describe "la procedencia" do
    test "el detalle dice de donde sale el numero" do
      opts = [engine_devices: engine(), system_devices: system()]

      assert {:ok, %{mib: mib, provenance: provenance}} =
               Doctor.calibrate_overhead_detail(:cuda, opts)

      assert mib == 16_000 - 15_109
      assert provenance.backend == :cuda
      assert provenance.method == "max(0, total_sistema - total_motor)"
      assert [%{engine_device: "CUDA0", system_device: "GPU-abc", overhead_mib: 891}] = provenance.devices
    end

    test "la procedencia lleva el instante de la medida" do
      opts = [engine_devices: engine(), system_devices: system()]

      assert {:ok, %{provenance: provenance}} = Doctor.calibrate_overhead_detail(:cuda, opts)
      assert %DateTime{} = provenance.measured_at
    end
  end
end
