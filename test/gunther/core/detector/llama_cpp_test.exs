defmodule Gunther.Detector.LlamaCppTest do
  use ExUnit.Case, async: true

  alias Gunther.Detector.LlamaCpp

  # El formato exacto lo imprime `common_print_available_devices` en
  # `common/arg.cpp`:
  #
  #   printf("  %s: %s (%zu MiB, %zu MiB free)\n", name, description, total/MiB, free/MiB);
  #
  # y precede de `printf("Available devices:\n")`.

  defp output(lines) do
    Enum.join(["Available devices:" | lines], "\n") <> "\n"
  end

  describe "parsear la salida" do
    test "una linea de CUDA" do
      raw =
        output([
          "  CUDA0: NVIDIA GeForce RTX 5080 Laptop GPU (15109 MiB, 12000 MiB free)"
        ])

      assert {:ok, [device]} = LlamaCpp.parse(raw)
      assert device.physical_id == "CUDA0"
      assert device.backend == :cuda
      assert device.backend_name == "CUDA"
      assert device.capacity_mib == 15_109
      assert device.free_mib == 12_000
      assert device.usable == true
    end

    test "varios backends" do
      raw =
        output([
          "  CUDA0: NVIDIA GeForce RTX 5080 Laptop GPU (15109 MiB, 12000 MiB free)",
          "  Vulkan0: AMD Radeon RX 7900 XTX (24560 MiB, 24000 MiB free)",
          "  ROCm0: AMD Radeon RX 7900 XTX (24560 MiB, 23000 MiB free)",
          "  MTL0: Apple M4 Max (36864 MiB, 30000 MiB free)"
        ])

      assert {:ok, devices} = LlamaCpp.parse(raw)
      assert length(devices) == 4

      assert Enum.map(devices, & &1.backend) == [:cuda, :vulkan, :rocm, :metal]
      assert Enum.map(devices, & &1.physical_id) == ["CUDA0", "Vulkan0", "ROCm0", "MTL0"]
    end

    test "el indice del device va en su nombre" do
      raw =
        output([
          "  CUDA0: NVIDIA GeForce RTX 5080 (15109 MiB, 12000 MiB free)",
          "  CUDA1: NVIDIA GeForce RTX 5080 (15109 MiB, 13000 MiB free)"
        ])

      assert {:ok, devices} = LlamaCpp.parse(raw)
      assert Enum.map(devices, & &1.physical_id) == ["CUDA0", "CUDA1"]
    end

    test "la descripcion se conserva, con sus parentesis" do
      # Con devices virtuales, el backend anade " (dev p<fisico>/v<virtual>)"
      # a la descripcion: la descripcion puede contener parentesis.
      raw =
        output([
          "  CUDA1: NVIDIA GeForce RTX 4090 (dev p0/v1) (12282 MiB, 12000 MiB free)"
        ])

      assert {:ok, [device]} = LlamaCpp.parse(raw)
      assert device.description == "NVIDIA GeForce RTX 4090 (dev p0/v1)"
      assert device.capacity_mib == 12_282
      assert device.free_mib == 12_000
    end

    test "el nombre de Metal es MTL con indice" do
      raw = output(["  MTL0: Apple M2 Pro (20608 MiB, 19000 MiB free)"])

      assert {:ok, [device]} = LlamaCpp.parse(raw)
      assert device.physical_id == "MTL0"
      assert device.backend == :metal
      assert device.description == "Apple M2 Pro"
    end

    test "MUSA es un backend propio del nombre" do
      raw = output(["  MUSA0: Moore Threads MTT S80 (32768 MiB, 30000 MiB free)"])

      assert {:ok, [device]} = LlamaCpp.parse(raw)
      assert device.backend == :musa
      assert device.usable == true
    end

    test "sin devices" do
      assert {:ok, []} = LlamaCpp.parse(output(["  (none)"]))
    end

    test "una salida que no es la lista se rechaza" do
      assert {:error, :not_a_device_list} = LlamaCpp.parse("load_tensors: offloading 0 repeating layers\n")
    end

    test "una linea con formato raro se ignora, no revienta" do
      raw =
        output([
          "  CUDA0: NVIDIA GeForce RTX 5080 (15109 MiB, 12000 MiB free)",
          "  esto no es un device"
        ])

      assert {:ok, [device]} = LlamaCpp.parse(raw)
      assert device.physical_id == "CUDA0"
    end
  end

  describe "la usabilidad" do
    test "free mayor que total hace el device no usable" do
      # Es un caso real documentado en CUDA (SPEC §19, F2-AC).
      raw = output(["  CUDA0: NVIDIA GeForce (100 MiB, 200 MiB free)"])

      assert {:ok, [device]} = LlamaCpp.parse(raw)
      assert device.usable == false
      assert device.reason == :free_gt_total
    end

    test "memoria no declarada deja el device no usable" do
      # CUDA con `cudaMemGetInfo` fallido, o Metal en macOS antiguo: 0/0.
      raw = output(["  CUDA0: NVIDIA GeForce (0 MiB, 0 MiB free)"])

      assert {:ok, [device]} = LlamaCpp.parse(raw)
      assert device.usable == false
      assert device.reason == :no_memory_reported
    end

    test "libre igual a total es normal y el device es usable" do
      # Vulkan sin `VK_EXT_memory_budget` no sabe restar lo usado.
      raw = output(["  Vulkan0: NVIDIA GeForce RTX 4090 (24564 MiB, 24564 MiB free)"])

      assert {:ok, [device]} = LlamaCpp.parse(raw)
      assert device.usable == true
      assert device.reason == nil
    end

    test "un backend desconocido no es usable" do
      raw = output(["  Exotic0: algo (1024 MiB, 512 MiB free)"])

      assert {:ok, [device]} = LlamaCpp.parse(raw)
      assert device.usable == false
      assert device.reason == :unknown_backend
    end
  end
end
