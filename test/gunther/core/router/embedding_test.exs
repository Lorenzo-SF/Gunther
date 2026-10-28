defmodule Gunther.Router.EmbeddingTest do
  use ExUnit.Case, async: true

  alias Gunther.Router
  alias Gunther.Router.Embedding

  # Un embedder de mentira: cada texto tiene su vector.
  defmodule Embedder do
    @vectors %{
      "hola" => [1.0, 0.0],
      "otro" => [0.0, 1.0],
      "neutro" => [0.7071, 0.7071],
      "code" => [1.0, 0.0],
      "vision" => [0.0, 1.0]
    }

    def embed(texts, _opts) do
      {:ok, Enum.map(texts, &Map.fetch!(@vectors, &1))}
    end

    def dimensions, do: 2
    def max_batch_size, do: 32
    def model_id, do: "test"
  end

  # Un embedder que siempre falla.
  defmodule BrokenEmbedder do
    def embed(_texts, _opts), do: {:error, :sin_memoria}
    def dimensions, do: 2
    def max_batch_size, do: 32
    def model_id, do: "roto"
  end

  defp model(alias, attrs) do
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

  defp opts(extra \\ []) do
    Keyword.merge(
      [
        catalog: catalog([model(:a, %{capabilities: [:code]}), model(:b, %{capabilities: [:vision]})]),
        consumer: :default,
        rules: [],
        consumer_rules: [],
        fallback_strategy: :least_used,
        catalog_hash: "hash-1",
        cache_enabled: false
      ],
      extra
    )
  end

  defp message(text), do: [%{role: :user, content: text}]

  defp embedding_opts(extra \\ []) do
    Keyword.merge([embedder: Embedder, embedding: %{verified: true, min_similarity: 0.5}], extra)
  end

  describe "rank/4" do
    test "ordena por la similitud con la skill mas afín" do
      {:ok, ranking} =
        Embedding.rank(
          [model(:a, %{capabilities: [:code]}), model(:b, %{capabilities: [:vision]})],
          "hola",
          Embedder,
          %{
            min_similarity: 0.5
          }
        )

      assert ranking == [:a, :b]
    end

    test "un prompt mas afín a otra skill cambia el orden" do
      {:ok, ranking} =
        Embedding.rank(
          [model(:a, %{capabilities: [:code]}), model(:b, %{capabilities: [:vision]})],
          "otro",
          Embedder,
          %{
            min_similarity: 0.5
          }
        )

      assert ranking == [:b, :a]
    end

    test "por debajo del umbral la capa se salta" do
      assert {:skip, :below_min_similarity} =
               Embedding.rank([model(:a, %{capabilities: [:code]})], "neutro", Embedder, %{min_similarity: 0.9})
    end

    test "un modelo sin skills va al final" do
      {:ok, ranking} =
        Embedding.rank(
          [model(:a, %{capabilities: []}), model(:b, %{capabilities: [:code]})],
          "hola",
          Embedder,
          %{min_similarity: 0.5}
        )

      assert ranking == [:b, :a]
    end

    test "sin skills la capa se salta" do
      assert {:skip, :no_skills} =
               Embedding.rank([model(:a, %{capabilities: []})], "hola", Embedder, %{min_similarity: 0.5})
    end

    test "un embedder que falla se salta con su error" do
      assert {:skip, {:embedder_error, :sin_memoria}} =
               Embedding.rank([model(:a, %{capabilities: [:code]})], "hola", BrokenEmbedder, %{min_similarity: 0.5})
    end
  end

  describe "la capa en el router" do
    test "sin embedder la capa no existe y gana el fallback" do
      {:ok, decision} = Router.route(message("hola"), opts())

      assert decision.reason == :fallback
      assert decision.layers_ran == [:fallback]
    end

    test "con embedder verificado elige por similitud" do
      {:ok, decision} = Router.route(message("otro"), opts(embedding_opts()))

      assert decision.chosen == :b
      assert decision.reason == :embedding
      assert decision.layers_ran == [:embedding]
      assert decision.ranked == [:b, :a]
    end

    test "un embedder sin verificar se salta con aviso" do
      {:ok, decision} =
        Router.route(message("hola"), opts(embedding_opts(embedding: %{verified: false, min_similarity: 0.5})))

      assert decision.reason == :fallback
      assert :classifier_unverified in decision.degraded
    end

    test "con allow_unverified el embedder sin verificar actua" do
      {:ok, decision} =
        Router.route(
          message("hola"),
          opts(embedding_opts(embedding: %{verified: false, min_similarity: 0.5}, allow_unverified: true))
        )

      assert decision.reason == :embedding
    end

    test "un embedder que falla se salta con el aviso de embedding" do
      {:ok, decision} =
        Router.route(message("hola"), opts(embedding_opts(embedder: BrokenEmbedder)))

      assert decision.reason == :fallback
      assert :embedding_unavailable in decision.degraded
    end

    test "por debajo del umbral se salta sin aviso" do
      {:ok, decision} =
        Router.route(
          message("neutro"),
          opts(embedding_opts(embedding: %{verified: true, min_similarity: 0.9}))
        )

      assert decision.reason == :fallback
      assert decision.degraded == []
    end

    test "un veto gana a la capa de embedding: la capa :rule corta" do
      rules = [%{name: "v", when: nil, action: :veto, target: %{models: [:b]}, weight: nil}]

      {:ok, decision} = Router.route(message("otro"), opts(embedding_opts(rules: rules)))

      # La capa :rule opino con el veto, asi que corta: :embedding y :llm no
      # corren (§6.10).
      assert decision.chosen == :a
      assert decision.reason == :veto
      assert decision.layers_ran == [:rule]
    end

    test "un pin gana a la capa de embedding" do
      {:ok, decision} = Router.route(message("otro"), opts(embedding_opts(pin: :a)))

      assert decision.chosen == :a
      assert decision.reason == :pin
    end
  end
end
