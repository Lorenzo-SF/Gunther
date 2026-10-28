defmodule Gunther.Resource.LedgerTest do
  use ExUnit.Case, async: false
  use ExUnitProperties

  alias Gunther.Resource.Ledger

  setup do
    # El ledger ya lo arranca el supervisor de la aplicacion (el mismo
    # proceso que en produccion): el test solo lo deja limpio.
    Ledger.reset()
    :ok
  end

  # Un device de la convencion A (la del motor): la capacidad y la libre
  # salen de `--list-devices`.
  defp device_a(overrides \\ []) do
    Enum.into(overrides, %{
      physical_id: "gpu0",
      node: :local,
      convention: :a,
      kind: :discrete,
      capacity_mib: 16_000,
      free_mib: 16_000,
      attribution: :none
    })
  end

  describe "adoptar un device" do
    test "un device adoptado tiene su capacidad" do
      assert :ok = Ledger.adopt(device_a())

      assert Ledger.capacity("gpu0") == 16_000
      assert Ledger.used("gpu0") == 0
    end

    test "un device que no esta adoptado no tiene capacidad" do
      assert Ledger.capacity("desconocido") == nil
    end

    test "free mayor que total hace el device no usable" do
      # Es un caso real documentado en CUDA (SPEC §19, F2-AC).
      assert :ok = Ledger.adopt(device_a(%{capacity_mib: 100, free_mib: 200}))

      assert Ledger.usable?("gpu0") == false
      assert Ledger.reason("gpu0") == :free_gt_total
    end
  end

  describe "adquirir y liberar" do
    test "adquirir que cabe vale" do
      :ok = Ledger.adopt(device_a())
      assert :ok = Ledger.acquire("gpu0", {:modelo, 8080, make_ref()}, 1000)
      assert Ledger.used("gpu0") == 1000
    end

    test "adquirir lo que no cabe es :no_room" do
      :ok = Ledger.adopt(device_a(%{capacity_mib: 1000, free_mib: 1000}))

      assert {:error, :no_room} = Ledger.acquire("gpu0", {:modelo, 8080, make_ref()}, 2000)
      assert Ledger.used("gpu0") == 0
    end

    test "liberar es idempotente" do
      :ok = Ledger.adopt(device_a())
      holder = {:modelo, 8080, make_ref()}
      :ok = Ledger.acquire("gpu0", holder, 1000)

      assert :ok = Ledger.release("gpu0", holder)
      assert :ok = Ledger.release("gpu0", holder)
      assert :ok = Ledger.release("gpu0", holder)
      assert Ledger.used("gpu0") == 0
    end

    test "liberar un holder que no esta no cambia nada" do
      :ok = Ledger.adopt(device_a())
      assert :ok = Ledger.release("gpu0", :nadie)
      assert Ledger.used("gpu0") == 0
    end

    test "los holders de un device se listan" do
      :ok = Ledger.adopt(device_a())
      holder = {:modelo, 8080, make_ref()}
      :ok = Ledger.acquire("gpu0", holder, 1000)

      assert Ledger.holders("gpu0") == [holder]
    end

    test "no hay un titular :system" do
      # La memoria ajena se mide aparte; no se inventa un titular.
      :ok = Ledger.adopt(device_a())
      :ok = Ledger.acquire("gpu0", {:modelo, 8080, make_ref()}, 1000)

      refute Enum.any?(Ledger.holders("gpu0"), &(&1 == :system))
    end
  end

  describe "la memoria disponible" do
    test "es la capacidad menos lo usado" do
      :ok = Ledger.adopt(device_a(%{capacity_mib: 1000, free_mib: 1000}))
      :ok = Ledger.acquire("gpu0", {:m, 1, make_ref()}, 400)

      assert Ledger.available("gpu0") == 600
    end

    test "nunca supera la libre medida" do
      # `available` es el minimo de los dos terminos: con memoria ajena que
      # crece, manda la libre medida.
      :ok = Ledger.adopt(device_a(%{capacity_mib: 1000, free_mib: 300}))
      :ok = Ledger.acquire("gpu0", {:m, 1, make_ref()}, 100)

      assert Ledger.available("gpu0") == 200
    end

    test "un device con memoria ajena descuenta la ajena" do
      # Convencion A en quiescencia: foreign = capacity - free - running.
      :ok = Ledger.adopt(device_a(%{capacity_mib: 1000, free_mib: 700}))

      # Hay 300 MiB que no son ni libres ni de Gunther.
      assert Ledger.foreign("gpu0") == 300
      assert Ledger.available("gpu0") == 700
    end

    test "sin medicion de memoria ajena el device no es usable" do
      # Nunca se ha medido en quiescencia: no se puede saber.
      :ok = Ledger.adopt(device_a(%{free_mib: nil}))

      assert Ledger.usable?("gpu0") == false
      assert Ledger.reason("gpu0") == :foreign_unknown
    end
  end

  describe "la memoria ajena" do
    test "con un engine en transicion se congela el ultimo valor" do
      :ok = Ledger.adopt(device_a(%{capacity_mib: 1000, free_mib: 700}))
      # En quiescencia se midio 300 MiB ajenos.
      assert Ledger.foreign("gpu0") == 300

      # Ahora hay un engine reservado: el device no esta en quiescencia.
      :ok = Ledger.acquire("gpu0", {:m, 1, make_ref()}, 100)

      assert Ledger.foreign("gpu0") == 300
    end

    test "el valor congelado no se recalcula en transicion" do
      :ok = Ledger.adopt(device_a(%{capacity_mib: 1000, free_mib: 700}))
      :ok = Ledger.acquire("gpu0", {:m, 1, make_ref()}, 100)

      # La libre medida baja (el engine reserva), pero el valor congelado no.
      :ok = Ledger.resync("gpu0", %{total_mib: 1000, free_mib: 600})

      assert Ledger.foreign("gpu0") == 300
    end

    test "en la convencion B con atribucion por proceso, la ajena es la suma" do
      device = %{
        physical_id: "gpu0",
        node: :local,
        convention: :b,
        kind: :discrete,
        capacity_mib: 1000,
        free_mib: 800,
        attribution: :per_process,
        overhead_mib: 0
      }

      :ok = Ledger.adopt(device)

      :ok =
        Ledger.resync("gpu0", %{
          total_mib: 1000,
          free_mib: 800,
          attribution: :per_process,
          source: :system,
          processes: [%{pid: 111, mib: 150}, %{pid: 222, mib: 50}]
        })

      assert Ledger.foreign("gpu0") == 200
    end
  end

  describe "la convencion B" do
    test "sin overhead_mib el device no es usable" do
      # `overhead_mib` es obligatorio: sin el, la capacidad seria falsa.
      device = %{
        physical_id: "gpu0",
        node: :local,
        convention: :b,
        kind: :discrete,
        capacity_mib: 1000,
        free_mib: 800,
        attribution: :none,
        overhead_mib: nil
      }

      :ok = Ledger.adopt(device)

      assert Ledger.usable?("gpu0") == false
      assert Ledger.reason("gpu0") == :overhead_unknown
    end

    test "la capacidad es el total del sistema menos el overhead" do
      device = %{
        physical_id: "gpu0",
        node: :local,
        convention: :b,
        kind: :discrete,
        capacity_mib: 1000,
        free_mib: 800,
        attribution: :none,
        overhead_mib: 200
      }

      :ok = Ledger.adopt(device)

      assert Ledger.capacity("gpu0") == 800
    end
  end

  describe "la memoria unificada" do
    test "sin max_mib el device no es usable" do
      device = %{
        physical_id: "gpu0",
        node: :local,
        convention: :a,
        kind: :unified,
        capacity_mib: 1000,
        free_mib: 800,
        attribution: :none,
        max_mib: nil,
        reserve_mib: nil
      }

      :ok = Ledger.adopt(device)

      assert Ledger.usable?("gpu0") == false
      assert Ledger.reason("gpu0") == :unified_limit_required
    end

    test "la disponible descuenta el maximo y la reserva" do
      device = %{
        physical_id: "gpu0",
        node: :local,
        convention: :a,
        kind: :unified,
        capacity_mib: 36_000,
        free_mib: 30_000,
        attribution: :none,
        max_mib: 32_000,
        reserve_mib: 2_000
      }

      :ok = Ledger.adopt(device)
      :ok = Ledger.acquire("gpu0", {:m, 1, make_ref()}, 1000)

      # min(32000 - 2000 - 1000, 30000) = 29000
      assert Ledger.available("gpu0") == 29_000
    end
  end

  describe "los invariantes" do
    property "lo usado nunca supera la capacidad" do
      check all(
              capacity <- integer(1..10_000),
              reservations <- list_of(integer(1..5_000), max_length: 10)
            ) do
        Ledger.reset()

        device = device_a(%{capacity_mib: capacity, free_mib: capacity})
        :ok = Ledger.adopt(device)

        Enum.each(reservations, fn mib ->
          Ledger.acquire("gpu0", {System.unique_integer([:positive]), mib, make_ref()}, mib)
        end)

        assert Ledger.used("gpu0") <= capacity
      end
    end

    property "liberar repetido no cambia nada" do
      check all(mib <- integer(1..5_000)) do
        Ledger.reset()

        :ok = Ledger.adopt(device_a())
        holder = {System.unique_integer([:positive]), mib, make_ref()}
        :ok = Ledger.acquire("gpu0", holder, mib)

        used = Ledger.used("gpu0")

        Enum.each(1..3, fn _release -> assert :ok = Ledger.release("gpu0", holder) end)

        assert Ledger.used("gpu0") == 0
        assert used == mib
      end
    end

    property "la disponible nunca supera la libre medida" do
      check all(
              free <- integer(0..10_000),
              mib <- integer(0..10_000)
            ) do
        Ledger.reset()

        :ok = Ledger.adopt(device_a(%{capacity_mib: 10_000, free_mib: free}))

        # Si no cabe, no se acquires: la disponible es 0, que tambien
        # cumple la cota.
        case Ledger.acquire("gpu0", {System.unique_integer([:positive]), mib, make_ref()}, mib) do
          :ok -> :ok
          {:error, :no_room} -> :ok
        end

        assert Ledger.available("gpu0") <= free
      end
    end
  end
end
