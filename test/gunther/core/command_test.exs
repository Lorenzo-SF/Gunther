defmodule Gunther.CommandTest do
  use ExUnit.Case, async: true

  alias Gunther.Command
  alias Gunther.Command.AllowList
  alias Gunther.Command.Spawner
  alias Gunther.Error

  setup do
    # Un ejecutable real yAllowed, para probar la lista de permitidos de verdad.
    bin = Path.join(System.tmp_dir!(), "gunther_test_#{System.unique_integer([:positive])}")
    File.write!(bin, "#!/bin/sh\necho hola\n")
    File.chmod!(bin, 0o755)
    on_exit(fn -> File.rm(bin) end)
    %{bin: bin}
  end

  describe "lista de permitidos (CE-18)" do
    test "un comando fuera de la lista no se ejecuta" do
      assert {:error, %Error{code: :command_blocked}} = Command.run("no-permitido", [], allow: [])
    end

    test "un comando de la lista se ejecuta" do
      allow = [%{name: "test_bin", path: System.fetch_env!("GUNTHER_TEST_BIN"), sha256: nil}]

      assert {:ok, result} = Command.run("test_bin", [], allow: allow)
      assert result.stdout =~ "hola"
      assert result.exit_status == 0
    end

    test "un sha256 que no coincide es config_error" do
      bin = System.fetch_env!("GUNTHER_TEST_BIN")
      allow = [%{name: "test_bin", path: bin, sha256: String.duplicate("0", 64)}]

      assert {:error, %Error{code: :config_error}} = Command.run("test_bin", [], allow: allow)
    end

    test "un sha256 que coincide se acepta" do
      bin = System.fetch_env!("GUNTHER_TEST_BIN")
      sha = :sha256 |> :crypto.hash(File.read!(bin)) |> Base.encode16(case: :lower)
      allow = [%{name: "test_bin", path: bin, sha256: sha}]

      assert {:ok, _result} = Command.run("test_bin", [], allow: allow)
    end

    test "un ejecutable inexistente es command_blocked" do
      allow = [%{name: "fantasma", path: "/no/existe/nada", sha256: nil}]
      assert {:error, %Error{code: :command_blocked}} = Command.run("fantasma", [], allow: allow)
    end
  end

  describe "argumentos" do
    test "un argumento con un caracter nulo se rechaza" do
      assert {:error, %Error{code: :command_blocked}} = AllowList.validate_args(["con\0nulo"])
    end

    test "los argumentos normales pasan" do
      assert {:ok, ["a", "b c"]} = AllowList.validate_args(["a", "b c"])
    end
  end

  describe "quoting POSIX" do
    test "un argumento con espacio se cita" do
      assert Command.quote("hola mundo") == "'hola mundo'"
    end

    test "una comilla simple se escapa" do
      assert Command.quote("it's") == "'it'\\''s'"
    end
  end

  describe "spawn (CE-20)" do
    test "un comando fuera de la lista no se lanza" do
      assert {:error, %Error{code: :command_blocked}} = Command.spawn("no-permitido", [], allow: [])
    end

    test "un proceso largo se lanza sin shell y entrega su salida" do
      bin = System.fetch_env!("GUNTHER_TEST_BIN")
      allow = [%{name: "test_bin", path: bin, sha256: nil}]

      assert {:ok, port} = Command.spawn("test_bin", [], allow: allow)

      # El mensaje llega como `{port, {:data, {:eol, linea}}}`: el port es el
      # proceso actual, asi que la tupla lleva su identidad.
      assert_receive {^port, {:data, {:eol, "hola"}}}, 5_000
      assert_receive {^port, {:exit_status, 0}}, 5_000

      # Cerrar un port cuyo proceso ya termino lanza `ArgumentError`: no es
      # un fallo, es que el port ya no existe.
      try do
        Port.close(port)
      rescue
        _other -> :ok
      end
    end
  end

  describe "reensamblado de :noeol (CE-20)" do
    test "los fragmentos se unen en un mensaje" do
      assert Spawner.reassemble([{:noeol, "a"}, {:noeol, "b"}, {:eol, "c"}]) == ["abc"]
    end

    test "varias lineas se separan" do
      assert Spawner.reassemble([{:eol, "a\n"}, {:eol, "b\n"}]) == ["a\n", "b\n"]
    end

    test "un final sin eol se devuelve como estaba" do
      assert Spawner.reassemble([{:noeol, "suelto"}]) == ["suelto"]
    end

    test "un mensaje mayor que el buffer de linea se reensambla en uno solo" do
      # El búfer de linea de un `Port` con `{:line, 65536}` son 65536 bytes.
      # Un mensaje mas largo llega en varios `{:noeol, fragmento}` y tiene que
      # salir como **un** mensaje (AC de F1, CE-20).
      big = String.duplicate("x", 100_000)

      # El troceado es a proposito: un patron binario de tamano fijo deja
      # fuera el resto, y ese resto es justo lo que hay que reensamblar.
      messages =
        big
        |> :erlang.binary_to_list()
        |> Enum.chunk_every(4096)
        |> Enum.map(fn chunk -> {:noeol, :erlang.list_to_binary(chunk)} end)

      assert [result] = Spawner.reassemble(messages)

      # Se comparan la longitud y el hash, no las cadenas: un assert sobre
      # 100.000 caracteres revienta el formateador de ExUnit y se pierde el
      # resumen de la suite, que es justo lo que hace falta ver.
      assert byte_size(result) == byte_size(big)
      assert :crypto.hash(:sha256, result) == :crypto.hash(:sha256, big)
    end
  end

  describe "stderr" do
    test "llama-server usa merge y MCP usa inherit" do
      assert Spawner.stderr_mode(:llama_server) == :merge
      assert Spawner.stderr_mode(:mcp_stdio) == :inherit
    end
  end

  setup %{bin: bin} do
    System.put_env("GUNTHER_TEST_BIN", bin)
    :ok
  end
end
