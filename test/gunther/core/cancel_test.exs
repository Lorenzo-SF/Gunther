defmodule Gunther.CancelTest do
  use ExUnit.Case, async: true

  doctest Gunther.Cancel

  test "un token nuevo no esta cancelado" do
    refute Gunther.Cancel.cancelled?(Gunther.Cancel.new())
  end

  test "cancelar cambia el estado" do
    token = Gunther.Cancel.new()
    assert :ok = Gunther.Cancel.cancel(token)
    assert Gunther.Cancel.cancelled?(token)
  end

  test "cancelar es idempotente" do
    token = Gunther.Cancel.new()
    :ok = Gunther.Cancel.cancel(token)
    :ok = Gunther.Cancel.cancel(token)
    assert Gunther.Cancel.cancelled?(token)
  end

  test "el token es valido entre procesos" do
    token = Gunther.Cancel.new()

    task = Task.async(fn -> Gunther.Cancel.cancelled?(token) end)
    refute Task.await(task)

    :ok = Gunther.Cancel.cancel(token)

    task = Task.async(fn -> Gunther.Cancel.cancelled?(token) end)
    assert Task.await(task)
  end

  test "check_fun devuelve una funcion de aridad 0" do
    token = Gunther.Cancel.new()
    check = Gunther.Cancel.check_fun(token)
    assert is_function(check, 0)
    refute check.()
    :ok = Gunther.Cancel.cancel(token)
    assert check.()
  end
end
