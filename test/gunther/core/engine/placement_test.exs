defmodule Gunther.Engine.PlacementTest do
  use ExUnit.Case, async: false

  # El registro que direcciona por nodo y el supervisor de los semaforos
  # estan en el arbol de la app (SPEC §2.3): aqui ya estan arrancados. Cada
  # test usa un nodo distinto, para no depender del estado que deja otro.
  alias Gunther.Engine.Placement

  describe "el turno" do
    test "una llamada sola pasa" do
      assert {:ok, :hecho} = Placement.with_node("nodo-a", fn -> :hecho end)
    end

    test "dos llamadas al mismo nodo no se solapan" do
      # El segundo espera al primero: sin el, dos arranques medirian la
      # misma memoria libre.
      parent = self()

      primero =
        Task.async(fn ->
          Placement.with_node("nodo-b", fn ->
            send(parent, :dentro)

            receive do
              :sigue -> :primero
            end
          end)
        end)

      assert_receive :dentro, 500

      segundo =
        Task.async(fn ->
          Placement.with_node("nodo-b", fn -> :segundo end)
        end)

      # El segundo no puede entrar mientras el primero tiene el turno.
      refute_receive {:visto, :segundo}, 100

      send(primero.pid, :sigue)
      assert {:ok, :primero} = Task.await(primero, 1_000)
      assert {:ok, :segundo} = Task.await(segundo, 1_000)
    end

    test "nodos distintos no se bloquean" do
      # Un nodo ocupado no bloquea a los demas.
      parent = self()

      ocupado =
        Task.async(fn ->
          Placement.with_node("nodo-c", fn ->
            send(parent, :dentro_c)

            receive do
              :sigue -> :listo
            end
          end)
        end)

      assert_receive :dentro_c, 500

      assert {:ok, :otro} =
               Task.await(
                 Task.async(fn -> Placement.with_node("nodo-d", fn -> :otro end) end),
                 500
               )

      send(ocupado.pid, :sigue)
      assert {:ok, :listo} = Task.await(ocupado, 1_000)
    end
  end

  describe "la muerte del titular" do
    test "si el titular muere, el turno se libera" do
      # El turno del nodo lo tiene un proceso que muere: el siguiente tiene
      # que poder entrar.
      parent = self()

      pid =
        spawn(fn ->
          Placement.with_node("nodo-e", fn ->
            send(parent, :dentro_e)
            Process.sleep(:infinity)
          end)
        end)

      assert_receive :dentro_e, 500

      Process.exit(pid, :kill)

      assert {:ok, :despues} =
               Placement.with_node("nodo-e", fn -> :despues end)
    end

    test "si el que espera muere, su peticion se descarta" do
      # El que espera en la cola se va: su peticion no debe ejecutarse mas
      # tarde y no debe bloquear a los siguientes.
      parent = self()

      primero =
        Task.async(fn ->
          Placement.with_node("nodo-f", fn ->
            send(parent, :dentro_f)

            receive do
              :sigue -> :primero
            end
          end)
        end)

      assert_receive :dentro_f, 500

      esperando =
        Task.async(fn ->
          Placement.with_node("nodo-f", fn ->
            send(parent, :nunca_deberia_entrar)
            :nunca
          end)
        end)

      Process.sleep(50)
      Task.shutdown(esperando, :brutal_kill)

      send(primero.pid, :sigue)
      assert {:ok, :primero} = Task.await(primero, 1_000)

      refute_receive :nunca_deberia_entrar, 200

      # Y el nodo sigue siendo usable.
      assert {:ok, :final} = Placement.with_node("nodo-f", fn -> :final end)
    end
  end

  describe "los errores" do
    test "un turno que no llega a tiempo es un timeout" do
      parent = self()

      _ocupado =
        Task.async(fn ->
          Placement.with_node("nodo-g", fn ->
            send(parent, :dentro_g)

            receive do
              :sigue -> :listo
            end
          end)
        end)

      assert_receive :dentro_g, 500

      assert {:error, error} = Placement.with_node("nodo-g", fn -> :nunca end, timeout_ms: 50)
      assert error.code == :timeout
    end
  end
end
