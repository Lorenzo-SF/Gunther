defmodule Gunther.Provider.MockTest do
  use ExUnit.Case, async: true

  alias Gunther.Provider.Mock

  defp messages, do: [%{role: :user, content: "hola"}]

  describe "chat/2" do
    test "responde con el texto del ultimo mensaje de usuario" do
      assert {:ok, result} = Mock.chat(messages(), [])

      assert result.content == "hola"
      assert result.finish_reason == :stop
      assert result.reasoning == nil
      assert result.tool_calls == nil
    end

    test "el texto se puede fijar" do
      assert {:ok, result} = Mock.chat(messages(), mock: %{text: "fijo"})

      assert result.content == "fijo"
    end

    test "informa el uso" do
      assert {:ok, result} = Mock.chat(messages(), [])

      assert result.usage.input_tokens > 0
      assert result.usage.output_tokens > 0
    end

    test "la misma peticion da la misma respuesta" do
      {:ok, one} = Mock.chat(messages(), [])
      {:ok, two} = Mock.chat(messages(), [])

      assert one == two
    end

    test "un error configurado se devuelve" do
      assert {:error, :reventado} = Mock.chat(messages(), mock: %{error: :reventado})
    end

    test "una entrada mala no lanza" do
      assert {:error, _reason} = Mock.chat([], [])
    end

    test "la cancelacion aborta" do
      assert {:error, :cancelled} = Mock.chat(messages(), cancelled?: fn -> true end)
    end

    test "la cancelacion interrumpe una llamada lenta" do
      task = Task.async(fn -> Mock.chat(messages(), mock: %{delay_ms: 2_000}, cancelled?: fn -> true end) end)

      assert {:error, :cancelled} = Task.await(task, 1_000)
    end
  end

  describe "stream/3" do
    test "entrega el delta y el fin" do
      parent = self()

      on_chunk = fn chunk -> send(parent, {:chunk, chunk}) end

      assert {:ok, result} = Mock.stream(messages(), [], on_chunk)

      assert result.content == "hola"
      assert_received {:chunk, %{delta: "hola"}}
      assert_received {:chunk, %{finish_reason: :stop}}
    end
  end

  describe "embed/2" do
    test "devuelve un vector por texto" do
      assert {:ok, [one, two]} = Mock.embed(["a", "b"], [])

      assert length(one) == 8
      assert length(two) == 8
    end

    test "el mismo texto da el mismo vector" do
      {:ok, [one]} = Mock.embed(["a"], [])
      {:ok, [two]} = Mock.embed(["a"], [])

      assert one == two
    end

    test "una entrada mala no lanza" do
      assert {:error, _reason} = Mock.embed(:no_una_lista, [])
    end
  end

  describe "el resto del contrato" do
    test "declara sus modelos" do
      assert Mock.models() == [:mock]
    end

    test "declara las capacidades" do
      assert :tools in Mock.capabilities(:mock)
    end

    test "declara las modalidades" do
      assert Mock.modalities(:mock) == [:text]
    end

    test "dice que soporta lo que soporta" do
      assert Mock.supports?(:tools, :mock)
      assert Mock.supports?(:streaming, :mock)
      refute Mock.supports?(:logprobs, :mock)
    end

    test "no tiene precios" do
      assert Mock.pricing(:mock) == nil
    end
  end
end
