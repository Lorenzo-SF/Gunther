defmodule Gunther.Router.Embedding do
  @moduledoc """
  La capa `:embedding` del router (SPEC §6.1, §6.11).

  Compara el prompt con las **skills** de los candidatos elegibles y ordena
  por similitud. Sin embedder registrado **la capa no existe** (§6.10) y el
  router sigue con la siguiente.

  ## Qué se compara

  El prompt (el último mensaje de usuario) y el nombre de cada skill. La
  puntuación de un modelo es la **mayor** similitud con sus skills: un modelo
  que sabe de código y de visión vale lo que valga su mejor skill.

  El texto de una skill es su nombre en prosa (`:code` → `"code"`). La
  taxonomía de skills es cerrada (D-02), así que el nombre es su
  descripción.

  ## La similitud

  El coseno. Con la normalización L2 de los dos vectores, es el producto
  escalar divided por el producto de las normas.

  ## El umbral

  `router.embedding.min_similarity` (defecto `0.0`, D-92) es el mínimo que
  tiene que alcanzar la mejor puntuación. Por debajo, la capa **se salta**:
  no hay opinion suficiente para elegir.

  ## La verificación

  La capa está sujeta al mismo ciclo que los decisores (§6.11): si no está
  verificada, **no actúa**. Con `router.allow_unverified` (defecto `false`)
  actúa igualmente y deja el aviso `:classifier_unverified`.
  """

  @type outcome ::
          {:ok, [atom()]}
          | {:skip, :no_skills | :below_min_similarity | {:embedder_error, term()}}

  @doc """
  Ordena los candidatos por la similitud de sus skills con el prompt.

  ## Ejemplos

      iex> Gunther.Router.Embedding.rank([], "hola", nil, %{})
      {:skip, :no_skills}
  """
  @spec rank([map()], binary(), module() | nil, map()) :: outcome()
  def rank(candidates, text, embedder, opts) do
    skills = skills_of(candidates)

    cond do
      embedder == nil ->
        {:skip, :no_skills}

      skills == [] ->
        {:skip, :no_skills}

      true ->
        embed_and_score(candidates, text, skills, embedder, opts)
    end
  end

  # Los textos que se embeben: el prompt y cada skill, sin repetir.
  defp embed_and_score(candidates, text, skills, embedder, opts) do
    texts = Enum.uniq([text | skills])

    case embedder.embed(texts, Map.get(opts, :embedder_opts, [])) do
      {:ok, vectors} when length(vectors) == length(texts) ->
        scored = score(candidates, text, skills, vectors, texts)
        threshold = Map.get(opts, :min_similarity, 0.0)

        case scored do
          [{_alias, best} | _rest] when best >= threshold ->
            {:ok, Enum.map(scored, &elem(&1, 0))}

          _none ->
            {:skip, :below_min_similarity}
        end

      {:ok, _other} ->
        # El embedder devolvio otra cosa: no se inventa el resultado.
        {:skip, {:embedder_error, :bad_shape}}

      {:error, reason} ->
        {:skip, {:embedder_error, reason}}
    end
  end

  # La puntuación de cada candidato: su mejor skill.
  defp score(candidates, text, _skills, vectors, texts) do
    prompt = vector_of(text, vectors, texts)

    candidates
    |> Enum.map(fn candidate ->
      best =
        candidate
        |> skills_of()
        |> Enum.map(fn skill -> similarity(prompt, vector_of(skill, vectors, texts)) end)
        |> Enum.max(fn -> -1.0 end)

      {candidate.alias, best}
    end)
    |> Enum.sort_by(fn {alias, score} -> {-score, alias} end)
  end

  defp vector_of(text, vectors, texts) do
    case Enum.find_index(texts, &(&1 == text)) do
      nil -> []
      index -> Enum.at(vectors, index)
    end
  end

  # Las skills de un candidato, en prosa.
  defp skills_of(candidates) when is_list(candidates) do
    candidates
    |> Enum.flat_map(&skills_of(&1))
    |> Enum.uniq()
  end

  defp skills_of(%{capabilities: capabilities}) when is_list(capabilities) do
    Enum.map(capabilities, &skill_text/1)
  end

  defp skills_of(_other), do: []

  defp skill_text(skill) when is_atom(skill), do: Atom.to_string(skill)
  defp skill_text(skill) when is_binary(skill), do: skill

  # El coseno entre dos vectores.
  @doc """
  La similitud del coseno entre dos vectores.

  Dos vectores de distinta longitud no son comparables: se devuelve `0.0`.

  ## Ejemplos

      iex> Gunther.Router.Embedding.similarity([1.0, 0.0], [1.0, 0.0])
      1.0

      iex> Gunther.Router.Embedding.similarity([1.0, 0.0], [0.0, 1.0])
      0.0
  """
  @spec similarity([float()], [float()]) :: float()
  def similarity(a, b) when is_list(a) and is_list(b) and length(a) == length(b) do
    norm_a = norm(a)
    norm_b = norm(b)

    if norm_a == 0.0 or norm_b == 0.0 do
      0.0
    else
      dot(a, b) / (norm_a * norm_b)
    end
  end

  def similarity(_a, _b), do: 0.0

  defp dot(a, b) do
    Enum.reduce(Enum.zip(a, b), 0.0, fn {x, y}, acc -> acc + x * y end)
  end

  defp norm(vector) do
    :math.sqrt(Enum.reduce(vector, 0.0, fn x, acc -> acc + x * x end))
  end

  # El embedder puede ser `nil`: la capa no existe.
  @doc """
  Si hay un embedder registrado.

  ## Ejemplos

      iex> Gunther.Router.Embedding.available?(nil)
      false
  """
  @spec available?(module() | nil) :: boolean()
  def available?(nil), do: false
  def available?(embedder), do: function_exported?(embedder, :embed, 2)
end
