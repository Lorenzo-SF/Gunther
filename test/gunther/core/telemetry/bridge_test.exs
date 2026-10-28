defmodule Gunther.Telemetry.BridgeTest do
  use ExUnit.Case, async: false

  alias Gunther.Telemetry.Bridge

  defp unique(prefix), do: :"#{prefix}_#{System.unique_integer([:positive])}"

  describe "el prefijo reservado de la coral (G6)" do
    test "un puente con el prefijo reservado no arranca" do
      name = unique(:bridge)

      assert {:error, {:reserved_prefix, [:gunther, :coral]}} =
               Bridge.start_link(name: name, prefix: [:gunther, :coral])
    end

    test "un prefijo que empieza por el reservado tambien se rechaza" do
      name = unique(:bridge)

      assert {:error, {:reserved_prefix, prefix}} =
               Bridge.start_link(name: name, prefix: [:gunther, :coral, :run])

      assert prefix == [:gunther, :coral, :run]
    end

    test "reserved?/1 distingue el reservado del resto" do
      assert Bridge.reserved?([:gunther, :coral])
      assert Bridge.reserved?([:gunther, :coral, :anything])
      refute Bridge.reserved?([:gunther])
      refute Bridge.reserved?([:gunther, :cache])
      refute Bridge.reserved?([:arrea, :coral])
    end

    test "un puente con un prefijo normal si arranca" do
      name = unique(:bridge)

      assert {:ok, _pid} = Bridge.start_link(name: name, prefix: [:otro])
    end
  end
end
