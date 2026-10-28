defmodule Gunther.Memory.ServerTest do
  use ExUnit.Case, async: true

  alias Gunther.Memory.Server

  # El servidor de memoria vive en el arbol de supervision de la app, asi que
  # ya esta arrancado. Cada test usa su propio `consumer` para no depender
  # del orden.

  defp consumer(name), do: "test-#{name}"

  describe "put" do
    test "guarda un valor" do
      assert :ok = Server.put("clave", "valor", consumer: consumer("put"))
      assert Server.get("clave", nil, consumer: consumer("put")) == "valor"
    end

    test "sobrescribe una clave que ya existe" do
      consumer = consumer("put-sobrescribe")

      assert :ok = Server.put("clave", "uno", consumer: consumer)
      assert :ok = Server.put("clave", "dos", consumer: consumer)
      assert Server.get("clave", nil, consumer: consumer) == "dos"
    end

    test "sin condicion de version, la version sube" do
      consumer = consumer("put-version")

      assert :ok = Server.put("clave", "uno", consumer: consumer)
      assert Server.version("clave", consumer: consumer) == 1

      assert :ok = Server.put("clave", "dos", consumer: consumer)
      assert Server.version("clave", consumer: consumer) == 2
    end
  end

  describe "put con if_version" do
    test "escribe si la version coincide" do
      consumer = consumer("if-version-ok")

      assert :ok = Server.put("clave", "uno", consumer: consumer)
      assert :ok = Server.put("clave", "dos", consumer: consumer, if_version: 1)
      assert Server.get("clave", nil, consumer: consumer) == "dos"
    end

    test "falla si la version no coincide" do
      consumer = consumer("if-version-ko")

      assert :ok = Server.put("clave", "uno", consumer: consumer)

      assert {:error, error} = Server.put("clave", "dos", consumer: consumer, if_version: 7)
      assert error.code == :version_conflict
      assert error.details.expected == 7
      assert error.details.actual == 1

      # Y el valor no cambia.
      assert Server.get("clave", nil, consumer: consumer) == "uno"
    end

    test "una clave nueva con if_version 0 se puede escribir" do
      consumer = consumer("if-version-nueva")

      assert :ok = Server.put("nueva", "valor", consumer: consumer, if_version: 0)
      assert Server.get("nueva", nil, consumer: consumer) == "valor"
    end
  end

  describe "put_new" do
    test "no sobrescribe" do
      consumer = consumer("put-new")

      assert :ok = Server.put_new("clave", 1, consumer: consumer)
      assert {:error, :exists} = Server.put_new("clave", 2, consumer: consumer)
      assert Server.get("clave", nil, consumer: consumer) == 1
    end
  end

  describe "supersede" do
    test "marca la entrada antigua como sustituida" do
      consumer = consumer("supersede")

      assert :ok = Server.put("vieja", 1, consumer: consumer)
      assert :ok = Server.put("nueva", 2, consumer: consumer)
      assert :ok = Server.supersede("vieja", "nueva", consumer: consumer)

      assert Server.get("vieja", nil, consumer: consumer) == 1
    end
  end

  describe "las claves" do
    test "estan ordenadas" do
      consumer = consumer("keys")

      assert :ok = Server.put("b", 1, consumer: consumer)
      assert :ok = Server.put("a", 2, consumer: consumer)

      assert Server.keys(consumer: consumer) == ["a", "b"]
    end
  end
end
