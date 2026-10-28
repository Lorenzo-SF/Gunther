defmodule Gunther.DecisionViewTest do
  use ExUnit.Case, async: true

  alias Gunther.DecisionView

  describe "new/1" do
    test "acepta una keyword list y un mapa" do
      from_keywords = DecisionView.new(text: "hola", roles: [:user])
      from_map = DecisionView.new(%{text: "hola", roles: [:user]})

      assert from_keywords.text == "hola"
      assert from_map.text == "hola"
      assert from_keywords.source_hash == from_map.source_hash
    end

    test "calcula el hash del texto" do
      view = DecisionView.new(text: "hola", roles: [:user])

      assert view.source_hash == DecisionView.hash("hola")
      assert byte_size(view.source_hash) == 16
    end

    test "rechaza un rol que no sea :user o :system" do
      # El moduledoc promete que el contenido `assistant` no entra en la
      # vista. Si el constructor aceptara cualquier rol, esa promesa
      # dependeria del que llama.
      assert_raise ArgumentError, ~r/son :user y :system/, fn ->
        DecisionView.new(text: "hola", roles: [:assistant])
      end
    end

    test "rechaza un texto que no sea una cadena" do
      assert_raise ArgumentError, ~r/el texto de una vista/, fn ->
        DecisionView.new(%{text: 42, roles: [:user]})
      end
    end

    test "rechaza un `truncated` que no sea booleano" do
      assert_raise ArgumentError, ~r/`truncated` es un booleano/, fn ->
        DecisionView.new(%{text: "hola", roles: [:user], truncated: "si"})
      end
    end

    test "exige el texto y los roles" do
      assert_raise KeyError, fn -> DecisionView.new(%{roles: [:user]}) end
      assert_raise KeyError, fn -> DecisionView.new(%{text: "hola"}) end
    end
  end

  describe "from_messages/2" do
    test "solo entra el texto de los roles permitidos" do
      messages = [
        %{role: :user, content: "pregunta"},
        %{role: :assistant, content: "respuesta anterior"},
        %{role: :system, content: "instruccion"}
      ]

      view = DecisionView.from_messages(messages, [:user])

      assert view.text == "pregunta"
    end

    test "une varios mensajes del mismo rol" do
      messages = [
        %{role: :user, content: "uno"},
        %{role: :user, content: "dos"}
      ]

      view = DecisionView.from_messages(messages, [:user])

      assert view.text == "uno\ndos"
    end

    test "excluye el contenido que no es de texto" do
      messages = [
        %{role: :user, content: [%{type: :text, text: "visible"}, %{type: :image, url: "x"}]}
      ]

      view = DecisionView.from_messages(messages, [:user])

      assert view.text == "visible"
    end

    test "una vista vacia es valida" do
      view = DecisionView.from_messages([], [:user])

      assert view.text == ""
      assert view.roles == [:user]
    end
  end

  describe "hash/1" do
    test "es estable y depende solo del texto" do
      assert DecisionView.hash("hola") == DecisionView.hash("hola")
      refute DecisionView.hash("hola") == DecisionView.hash("adios")
    end
  end
end
