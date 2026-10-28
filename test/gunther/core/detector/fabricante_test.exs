defmodule Gunther.Detector.FabricanteTest do
  use ExUnit.Case, async: true

  alias Gunther.Detector.Fabricante

  # El detector ejecuta `nvidia-smi` por `Gunther.Command`. Aqui se sustituye
  # el runner por uno que devuelve una salida fija: la forma de la salida se
  # comprueba contra la documentacion de la herramienta, no contra una GPU.

  defp runner(pairs) do
    mapa = Map.new(pairs)

    fn cmd, args, _opts ->
      case Map.fetch(mapa, {cmd, args}) do
        {:ok, output} -> {:ok, %{stdout: output, stderr: "", exit_status: 0}}
        :error -> {:error, :command_failed}
      end
    end
  end

  defp nvidia_args do
    ["--query-gpu=index,name,uuid,memory.total,memory.free", "--format=csv,noheader,nounits"]
  end

  defp nvidia_processes_args do
    ["--query-compute-apps=pid,used_memory", "--format=csv,noheader,nounits"]
  end

  describe "CUDA" do
    test "la identidad fisica es el UUID" do
      # §11.7: el `physical_id` de CUDA es el UUID de `nvidia-smi`, no el
      # nombre del motor (`CUDA0`).
      output = "0, NVIDIA GeForce RTX 5080 Laptop GPU, GPU-1234abcd-5678, 15109, 12000\n"
      opts = [backend: :cuda, runner: runner([{{"nvidia-smi", nvidia_args()}, output}])]

      assert {:ok, [device]} = Fabricante.devices(opts)
      assert device.physical_id == "GPU-1234abcd-5678"
      assert device.capacity_mib == 15_109
      assert device.free_mib == 12_000
      assert device.backend == :cuda
    end

    test "el nombre con comas no rompe el CSV" do
      output = "0, \"NVIDIA GeForce RTX 5080, Laptop GPU\", GPU-abc, 15109, 12000\n"
      opts = [backend: :cuda, runner: runner([{{"nvidia-smi", nvidia_args()}, output}])]

      assert {:ok, [device]} = Fabricante.devices(opts)
      assert device.name == "NVIDIA GeForce RTX 5080, Laptop GPU"
      assert device.physical_id == "GPU-abc"
    end

    test "la atribucion es por proceso" do
      output = "0, NVIDIA RTX 5080, GPU-abc, 15109, 12000\n"
      opts = [backend: :cuda, runner: runner([{{"nvidia-smi", nvidia_args()}, output}])]

      assert {:ok, [device]} = Fabricante.devices(opts)
      assert device.attribution == :per_process
    end

    test "la medida trae los procesos" do
      devices = "0, NVIDIA RTX 5080, GPU-abc, 15109, 12000\n"
      procesos = "1234, 2048\n5678, 512\n"

      opts = [
        backend: :cuda,
        runner:
          runner([
            {{"nvidia-smi", nvidia_args()}, devices},
            {{"nvidia-smi", nvidia_processes_args()}, procesos}
          ])
      ]

      assert {:ok, measurement} = Fabricante.measure("GPU-abc", opts)
      assert measurement.total_mib == 15_109
      assert measurement.attribution == :per_process
      assert measurement.source == :system
      assert measurement.processes == [%{pid: 1234, mib: 2048}, %{pid: 5678, mib: 512}]
    end

    test "un device que no existe es un error" do
      output = "0, NVIDIA RTX 5080, GPU-abc, 15109, 12000\n"
      opts = [backend: :cuda, runner: runner([{{"nvidia-smi", nvidia_args()}, output}])]

      assert {:error, :device_not_found} = Fabricante.measure("GPU-inexistente", opts)
    end
  end

  describe "los backends sin atribucion" do
    test "Vulkan y Metal no dan devices de fabricante" do
      # §11.7: no hay id neutral, y la atribucion es `:none`.
      assert {:ok, []} = Fabricante.devices(backend: :vulkan)
      assert {:ok, []} = Fabricante.devices(backend: :metal)
    end

    test "un backend desconocido es un error de configuracion" do
      assert {:error, error} = Fabricante.devices(backend: :sycl)
      assert error.code == :config_error
    end
  end

  describe "sin la herramienta" do
    test "si el comando falla, el error es un valor" do
      opts = [backend: :cuda, runner: runner([])]

      assert {:error, :command_failed} = Fabricante.devices(opts)
    end
  end
end
