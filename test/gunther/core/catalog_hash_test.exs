defmodule Gunther.CatalogHashTest do
  use ExUnit.Case, async: true

  alias Gunther.Catalog
  alias Gunther.Config

  defp config(rules, consumers \\ []) do
    {:ok, config} =
      Config.load(%{
        "gunther" => %{"instance_id" => "main"},
        "models" => [%{"alias" => "a", "provider" => "llamacpp", "model_id" => "x"}],
        "rules" => rules,
        "consumers" => Map.new(consumers, fn {id, c} -> {id, c} end)
      })

    config
  end

  defp catalog(config), do: Catalog.build(config)

  defp rule(name, attrs \\ %{}) do
    Map.merge(
      %{
        "name" => name,
        "action" => "veto",
        "target" => %{"locality" => "cloud"}
      },
      Map.new(attrs)
    )
  end

  defp hash(rules, consumers \\ %{}) do
    config = config(rules, consumers)
    Catalog.hash(catalog(config), config)
  end

  describe "hash/2" do
    test "dos configuraciones iguales dan el mismo hash" do
      assert hash([rule("v")]) == hash([rule("v")])
    end

    test "una regla con otro nombre da otro hash" do
      refute hash([rule("v")]) == hash([rule("w")])
    end

    test "una regla con otro target da otro hash" do
      refute hash([rule("v", %{"target" => %{"locality" => "cloud"}})]) ==
               hash([rule("v", %{"target" => %{"locality" => "local"}})])
    end

    test "una regla con otra accion da otro hash" do
      refute hash([rule("v", %{"action" => "veto"})]) ==
               hash([rule("v", %{"action" => "force"})])
    end

    test "una regla con otra condicion da otro hash" do
      refute hash([rule("v", %{"when" => %{"contains" => "privado"}})]) ==
               hash([rule("v", %{"when" => %{"contains" => "secreto"}})])
    end

    test "una regla de consumer con otro target da otro hash" do
      a = hash([], %{"c1" => %{"default_model" => "a", "rules" => [rule("cv")]}})
      b = hash([], %{"c1" => %{"default_model" => "a", "rules" => [rule("cw")]}})
      c = hash([], %{"c1" => %{"default_model" => "a", "rules" => [rule("cv", %{"action" => "force"})]}})

      refute a == b
      refute a == c
    end

    test "una regla de consumer nueva da otro hash" do
      refute hash([]) == hash([], %{"c1" => %{"default_model" => "a", "rules" => [rule("cv")]}})
    end

    test "sin configuracion el hash solo cubre el catalogo" do
      config = config([rule("v")])

      assert is_binary(Catalog.hash(catalog(config), nil))
    end
  end
end
