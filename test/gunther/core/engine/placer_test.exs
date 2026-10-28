defmodule Gunther.Engine.PlacerTest do
  use ExUnit.Case, async: true

  alias Gunther.Engine.Placer

  defp device(physical_id, opts \\ []) do
    %{
      physical_id: physical_id,
      node: Keyword.get(opts, :node, :local),
      backend: Keyword.get(opts, :backend, :cuda),
      usable: Keyword.get(opts, :usable, true),
      available_mib: Keyword.get(opts, :available_mib, 8000),
      reason: Keyword.get(opts, :reason)
    }
  end

  defp model(opts \\ []) do
    %{
      alias: Keyword.get(opts, :alias, "qwen_27b"),
      device: Keyword.get(opts, :device),
      reserved_mib: Keyword.get(opts, :reserved_mib, 4000),
      exclusive: Keyword.get(opts, :exclusive, false),
      resident: Keyword.get(opts, :resident, false)
    }
  end

  describe "elegir un device" do
    test "coloca en el que mas memoria libre tiene" do
      devices = [device("gpu0", available_mib: 2000), device("gpu1", available_mib: 9000)]

      assert {:ok, {:local, "gpu1"}} = Placer.place(model(), devices, margin_mib: 0)
    end

    test "el desempate es por physical_id, alfabetico" do
      devices = [device("gpu1", available_mib: 5000), device("gpu0", available_mib: 5000)]

      assert {:ok, {:local, "gpu0"}} = Placer.place(model(), devices, margin_mib: 0)
    end

    test "si el modelo fija un device, se usa ese" do
      # gpu0 tiene mas memoria libre, pero el modelo pide gpu1.
      devices = [device("gpu0", available_mib: 9000), device("gpu1", available_mib: 5000)]

      assert {:ok, {:local, "gpu1"}} = Placer.place(model(device: "gpu1"), devices, margin_mib: 0)
    end

    test "si el device fijado no existe, es :device_unusable" do
      assert {:error, :device_unusable} = Placer.place(model(device: "gpu9"), [device("gpu0")], margin_mib: 0)
    end

    test "sin devices es :no_gpu" do
      assert {:error, :no_gpu} = Placer.place(model(), [])
    end

    test "un device que no se puede usar no se elige" do
      devices = [
        device("gpu0", usable: false, reason: :foreign_unknown),
        device("gpu1", available_mib: 9000)
      ]

      assert {:ok, {:local, "gpu1"}} = Placer.place(model(), devices, margin_mib: 0)
    end

    test "si solo hay devices que no se pueden usar, es :device_unusable" do
      devices = [device("gpu0", usable: false, reason: :foreign_unknown)]

      assert {:error, :device_unusable} = Placer.place(model(), devices, margin_mib: 0)
    end
  end

  describe "que no quepa" do
    test "es :no_room" do
      devices = [device("gpu0", available_mib: 1000)]

      assert {:error, :no_room} = Placer.place(model(reserved_mib: 4000), devices, margin_mib: 0)
    end

    test "un device que no se ha medido es :memory_unknown" do
      # Sin medida no se sabe si cabe: no se puede adivinar.
      devices = [device("gpu0", usable: true, available_mib: nil)]

      assert {:error, :memory_unknown} = Placer.place(model(), devices, margin_mib: 0)
    end
  end

  describe "el orden entre nodos" do
    test "sin prefer, el local va primero" do
      # Los dos caben; el local va primero aunque el otro tenga mas libre.
      devices = [
        device("gpu0", node: :nodo1, available_mib: 9000),
        device("gpu1", node: :local, available_mib: 5000)
      ]

      assert {:ok, {:local, "gpu1"}} = Placer.place(model(), devices, margin_mib: 0)
    end

    test "prefer manda sobre la memoria libre" do
      devices = [
        device("gpu0", node: :nodo1, available_mib: 9000),
        device("gpu1", node: :local, available_mib: 5000)
      ]

      assert {:ok, {:nodo1, "gpu0"}} =
               Placer.place(model(), devices, margin_mib: 0, prefer: ["nodo1", "local"])
    end

    test "el orden de prefer es el que se da" do
      devices = [
        device("gpu0", node: :nodo1, available_mib: 9000),
        device("gpu1", node: :nodo2, available_mib: 8000)
      ]

      assert {:ok, {:nodo2, "gpu1"}} =
               Placer.place(model(), devices, margin_mib: 0, prefer: ["nodo2", "nodo1"])
    end
  end

  describe "el margen" do
    test "la reserva es el peso mas el margen" do
      # El margen por defecto de `vram_margin_mib` es 1024, que es el
      # margen por defecto de `--fit-target` en `llama-server`.
      assert Placer.reserved_mib(%{reserved_mib: 4000}) == 5024
      assert Placer.reserved_mib(%{reserved_mib: 4000}, margin_mib: 0) == 4000
    end

    test "un device que solo cabe sin el margen no se elige" do
      devices = [device("gpu0", available_mib: 4000)]

      assert {:error, :no_room} = Placer.place(model(reserved_mib: 4000), devices)
    end
  end

  describe "el tope por conteo" do
    test "se respeta el maximo de modelos cargados" do
      # El nodo local ya tiene dos modelos cargados y el tope es dos.
      loaded = %{local: ["a", "b"]}

      assert {:error, :no_room} =
               Placer.place(model(), [device("gpu0")], margin_mib: 0, max_loaded_models: 2, loaded: loaded)
    end

    test "un modelo resident cuenta para el tope" do
      loaded = %{local: ["a", "b"]}

      assert {:error, :no_room} =
               Placer.place(model(resident: true), [device("gpu0")],
                 margin_mib: 0,
                 max_loaded_models: 2,
                 loaded: loaded
               )
    end

    test "sin tope (0) solo manda la memoria" do
      loaded = %{local: ["a", "b", "c"]}

      assert {:ok, {:local, "gpu0"}} =
               Placer.place(model(), [device("gpu0")], margin_mib: 0, max_loaded_models: 0, loaded: loaded)
    end
  end
end
