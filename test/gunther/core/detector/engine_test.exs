defmodule Gunther.Detector.EngineTest do
  use ExUnit.Case, async: true

  alias Gunther.Detector.Engine

  # El binario del engine y la lista de permitidos se pasan en las
  # opciones: el detector no los inventa (SPEC §3.4, §5.12).
  defp opts(stdout) do
    [
      binary: "/usr/bin/llama-server",
      allow: ["/usr/bin/llama-server"],
      runner: fn _cmd, _args, _opts -> {:ok, %{stdout: stdout, stderr: "", exit_status: 0}} end
    ]
  end

  describe "los devices" do
    test "se leen de la salida del binario" do
      raw = """
      Available devices:
        CUDA0: NVIDIA GeForce RTX 5080 (15109 MiB, 12000 MiB free)
      """

      assert {:ok, [device]} = Engine.devices(opts(raw))
      assert device.physical_id == "CUDA0"
      assert device.capacity_mib == 15_109
    end

    test "el binario se ejecuta por la puerta de ejecucion" do
      # `Gunther.Command` es la unica puerta (SPEC §3.4): el detector no
      # puede llamar a `System.cmd` por su cuenta.
      raw = """
      Available devices:
        CUDA0: NVIDIA (100 MiB, 50 MiB free)
      """

      me = self()

      runner = fn cmd, args, _opts ->
        send(me, {:ran, cmd, args})
        {:ok, %{stdout: raw, stderr: "", exit_status: 0}}
      end

      opts = Keyword.put(opts(raw), :runner, runner)

      assert {:ok, [_device]} = Engine.devices(opts)

      assert_received {:ran, "/usr/bin/llama-server", ["--list-devices"]}
    end

    test "si el comando falla, el error es un valor" do
      opts =
        Keyword.put(opts(""), :runner, fn _cmd, _args, _opts ->
          {:error, :command_failed}
        end)

      assert {:error, :command_failed} = Engine.devices(opts)
    end

    test "una salida que no es la lista es un error" do
      assert {:error, :not_a_device_list} = Engine.devices(opts("otra cosa\n"))
    end
  end

  describe "medir un device" do
    test "devuelve el total y la libre" do
      raw = """
      Available devices:
        CUDA0: NVIDIA (15109 MiB, 12000 MiB free)
      """

      assert {:ok, measurement} = Engine.measure("CUDA0", opts(raw))
      assert measurement.total_mib == 15_109
      assert measurement.free_mib == 12_000
      assert measurement.source == :engine
      assert measurement.attribution == :none
    end

    test "un device que no esta es un error" do
      raw = """
      Available devices:
        CUDA0: NVIDIA (15109 MiB, 12000 MiB free)
      """

      assert {:error, :device_not_found} = Engine.measure("CUDA9", opts(raw))
    end
  end
end
