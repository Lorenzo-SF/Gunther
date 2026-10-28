defmodule Gunther.RouterCacheTest do
  use ExUnit.Case, async: true

  alias Gunther.Router

  # Una cache de mentira. El router corre en el proceso del test, asi que
  # el mapa vive en el process dictionary de ese proceso.
  defmodule FakeCache do
    def get(key), do: Map.fetch(store(), key)

    def put(key, value) do
      Process.put(:fake_cache, Map.put(store(), key, value))
      :ok
    end

    def keys, do: Map.keys(store())

    defp store, do: Process.get(:fake_cache) || %{}
  end

  defp model(alias, attrs \\ []) do
    Map.merge(
      %{
        alias: alias,
        provider: :p,
        model_id: "id",
        locality: :cloud,
        node: nil,
        capabilities: [],
        modalities: [],
        context_window: 4096,
        max_concurrency: 1,
        tags: []
      },
      Map.new(attrs)
    )
  end

  defp catalog(models) do
    %{version: 1, models: Map.new(models, &{&1.alias, &1}), providers: %{}, nodes: %{}}
  end

  defp opts(extra) do
    Keyword.merge(
      [
        catalog: catalog([model(:a), model(:b)]),
        consumer: :default,
        rules: [],
        consumer_rules: [],
        fallback_strategy: :least_used,
        catalog_hash: "hash-1"
      ],
      extra
    )
  end

  defp start_cache do
    Process.put(:fake_cache, %{})
    :ok
  end

  defp with_cache(_name, extra \\ []) do
    Keyword.merge(opts(extra), cache: FakeCache)
  end

  defp message(text \\ "hola"), do: [%{role: :user, content: text}]

  describe "capa :cache" do
    test "un miss corre el fallback y guarda el ranking" do
      cache = start_cache()

      {:ok, decision} = Router.route(message(), with_cache(cache))

      assert decision.chosen == :a
      assert decision.reason == :fallback
      assert decision.layers_ran == [:fallback]

      assert [_key] = FakeCache.keys()
    end

    test "un hit resuelve con reason :cache y sin correr el fallback" do
      cache = start_cache()

      {:ok, first} = Router.route(message(), with_cache(cache))
      {:ok, second} = Router.route(message(), with_cache(cache))

      assert first.chosen == :a
      assert second.chosen == :a
      assert second.reason == :cache
      assert second.layers_ran == [:cache]
      assert second.ranked == [:a, :b]
    end

    test "la clave cambia con el texto" do
      cache = start_cache()

      Router.route(message("uno"), with_cache(cache))
      Router.route(message("dos"), with_cache(cache))

      assert length(FakeCache.keys()) == 2
    end

    test "la clave cambia con el consumer" do
      cache = start_cache()

      Router.route(message(), with_cache(cache))
      Router.route(message(), with_cache(cache, consumer: :otro))

      assert length(FakeCache.keys()) == 2
    end

    test "la clave cambia con la firma de requisitos" do
      cache = start_cache()

      Router.route(message(), with_cache(cache))
      Router.route(message(), with_cache(cache, requirements: %{tools: [:a]}))

      assert length(FakeCache.keys()) == 2
    end

    test "la clave cambia con el hash del catalogo" do
      cache = start_cache()

      Router.route(message(), with_cache(cache))
      Router.route(message(), with_cache(cache, catalog_hash: "hash-2"))

      assert length(FakeCache.keys()) == 2
    end

    test "sin hash de catalogo la cache no se usa" do
      cache = start_cache()

      opts = Keyword.delete(with_cache(cache), :catalog_hash)

      {:ok, decision} = Router.route(message(), opts)

      assert decision.reason == :fallback
      assert FakeCache.keys() == []
    end

    test "la cache desactivada no se usa" do
      cache = start_cache()

      {:ok, decision} = Router.route(message(), with_cache(cache, cache_enabled: false))

      assert decision.reason == :fallback
      assert FakeCache.keys() == []
    end

    test "un veto se aplica aunque haya un hit de cache" do
      cache = start_cache()

      rules = [%{name: "v", when: nil, action: :veto, target: %{models: [:a]}, weight: nil}]

      {:ok, _first} = Router.route(message(), with_cache(cache, rules: rules))
      {:ok, second} = Router.route(message(), with_cache(cache, rules: rules))

      # El veto se aplica siempre: el hit de cache no lo salta.
      assert second.chosen == :b
      refute second.ranked == [:a, :b]
    end

    test "un veto que deja el conjunto vacio da :no_candidates aunque haya hit" do
      cache = start_cache()

      rules = [%{name: "v", when: nil, action: :veto, target: %{models: [:a, :b]}, weight: nil}]

      Router.route(message(), with_cache(cache, rules: rules))
      {:error, error} = Router.route(message(), with_cache(cache, rules: rules))

      assert error.code == :no_candidates
    end

    test "un pin gana a la cache" do
      cache = start_cache()

      Router.route(message(), with_cache(cache))
      {:ok, decision} = Router.route(message(), with_cache(cache, pin: :b))

      assert decision.chosen == :b
      assert decision.reason == :pin
    end
  end
end
