defmodule Gunther.Router.RequirementsTest do
  use ExUnit.Case, async: true

  alias Gunther.Router.Requirements

  describe "signature/1" do
    test "una peticion sin requisitos da una firma vacia" do
      assert Requirements.signature(%{}) == %{}
    end

    test "la firma no depende del orden de las listas" do
      a = Requirements.signature(%{tools: [:b, :a], modalities: [:text, :image]})
      b = Requirements.signature(%{tools: [:a, :b], modalities: [:image, :text]})

      assert a == b
    end

    test "la firma no tiene duplicados" do
      a = Requirements.signature(%{tools: [:a, :a, :b]})
      b = Requirements.signature(%{tools: [:a, :b]})

      assert a == b
    end

    test "cambiar las herramientas cambia la firma" do
      refute Requirements.signature(%{tools: [:a]}) == Requirements.signature(%{tools: [:b]})
    end

    test "cambiar las modalidades cambia la firma" do
      refute Requirements.signature(%{modalities: [:text]}) ==
               Requirements.signature(%{modalities: [:text, :image]})
    end

    test "cambiar el response_format cambia la firma" do
      refute Requirements.signature(%{response_format: :json}) ==
               Requirements.signature(%{response_format: :text})
    end

    test "cambiar las skills cambia la firma" do
      refute Requirements.signature(%{skills: [:code]}) == Requirements.signature(%{skills: [:reasoning]})
    end

    test "cambiar el rag cambia la firma" do
      refute Requirements.signature(%{rag: true}) == Requirements.signature(%{rag: false})
    end

    test "los atomos y las cadenas son la misma cosa" do
      assert Requirements.signature(%{tools: [:a]}) == Requirements.signature(%{tools: ["a"]})
    end

    test "los booleanos se quedan como booleanos" do
      assert Requirements.signature(%{rag: true}) == %{rag: true}
    end

    test "una clave desconocida se conserva" do
      assert Requirements.signature(%{raro: 1}) == %{raro: 1}
    end
  end
end
