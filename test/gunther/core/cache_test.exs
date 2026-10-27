defmodule Gunther.CacheTest do
  use ExUnit.Case, async: true

  use ExUnitProperties

  alias Gunther.Cache

  describe "put/get" do
    test "guarda y lee" do
      {:ok, cache} = Cache.start_link()
      assert :ok = Cache.put(cache, :a, 1)
      assert {:ok, 1} = Cache.get(cache, :a)
    end

    test "una clave ausente es :error" do
      {:ok, cache} = Cache.start_link()
      assert :error = Cache.get(cache, :nada)
    end

    test "delete borra" do
      {:ok, cache} = Cache.start_link()
      :ok = Cache.put(cache, :a, 1)
      assert :ok = Cache.delete(cache, :a)
      assert :error = Cache.get(cache, :a)
    end

    test "sobreescribir no crece el contador" do
      {:ok, cache} = Cache.start_link()
      :ok = Cache.put(cache, :a, 1)
      :ok = Cache.put(cache, :a, 2)
      assert Cache.size(cache) == 1
      assert {:ok, 2} = Cache.get(cache, :a)
    end
  end

  describe "tope de entradas" do
    test "nunca se supera el tope" do
      {:ok, cache} = Cache.start_link(max_entries: 3)
      for i <- 1..10, do: :ok = Cache.put(cache, :"k#{i}", i)
      assert Cache.size(cache) <= 3
    end

    test "expulsa la menos usada" do
      {:ok, cache} = Cache.start_link(max_entries: 2)
      :ok = Cache.put(cache, :a, 1)
      :ok = Cache.put(cache, :b, 2)
      :ok = Cache.put(cache, :c, 3)

      assert :error = Cache.get(cache, :a)
      assert {:ok, 2} = Cache.get(cache, :b)
      assert {:ok, 3} = Cache.get(cache, :c)
    end
  end

  describe "TTL" do
    test "una entrada caducada se trata como ausente" do
      {:ok, cache} = Cache.start_link(ttl_ms: 30)
      :ok = Cache.put(cache, :a, 1)
      Process.sleep(60)
      assert :error = Cache.get(cache, :a)
    end
  end

  describe "propiedades" do
    property "el tope se respeta siempre" do
      check all(
              max_entries <- integer(1..10),
              count <- integer(1..40),
              items <- list_of({integer(), integer()}, max_length: 40)
            ) do
        {:ok, cache} = Cache.start_link(max_entries: max_entries)

        Enum.each(items, fn {key, value} -> :ok = Cache.put(cache, key, value) end)
        for i <- 1..count, do: :ok = Cache.put(cache, :"extra#{i}", i)

        assert Cache.size(cache) <= max_entries
      end
    end

    property "lo que se guarda, se lee" do
      check all(items <- list_of({term(), integer()}, max_length: 20)) do
        {:ok, cache} = Cache.start_link(max_entries: 1000)

        Enum.each(items, fn {key, value} -> :ok = Cache.put(cache, key, value) end)

        # Con la misma clave varias veces, gana el ULTIMO valor escrito.
        expected = Map.new(items, fn {key, value} -> {key, value} end)

        for {key, value} <- expected do
          assert {:ok, ^value} = Cache.get(cache, key)
        end
      end
    end
  end
end
