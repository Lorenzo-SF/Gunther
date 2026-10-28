defmodule Gunther.Router.Rules do
  @moduledoc """
  Las reglas del enrutador (SPEC §6.8): `veto`, `force` y `prefer`.

  Una regla tiene un `name`, un `action`, un `target` obligatorio y un `when`
  opcional. Sin `when` la regla aplica siempre.

  ## Ejemplos

      iex> Gunther.Router.Rules.when?(%{contains: "privado"}, "esto es PRIVADO")
      true
  """

  @type action :: :veto | :force | :prefer
  @type rule :: %{
          required(:name) => String.t(),
          required(:action) => action(),
          required(:target) => map(),
          optional(:when) => map() | nil,
          optional(:weight) => float()
        }

  @doc """
  Si la condición de una regla se cumple para el texto dado.

  Las condiciones son `{any: [...]}`, `{all: [...]}`, `{contains: _}` y
  `{regex: _}`. El texto y los patrones se normalizan (minusculas, sin
  diacriticos) antes de comparar.

  Una condicion desconocida, o una regex que no compila, **no se cumplen**:
  una regla mal escrita no puede dejar pasar lo que deberia vetar.

  ## Ejemplos

      iex> Gunther.Router.Rules.when?(%{contains: "privado"}, "esto es PRIVADO")
      true
      iex> Gunther.Router.Rules.when?(%{lang: "es"}, "hola")
      false
  """
  @spec when?(map() | nil, String.t()) :: boolean()
  def when?(nil, _text), do: true

  def when?(%{any: conditions}, text) when is_list(conditions) do
    Enum.any?(conditions, &when?(&1, text))
  end

  def when?(%{all: conditions}, text) when is_list(conditions) do
    Enum.all?(conditions, &when?(&1, text))
  end

  def when?(%{contains: pattern}, text) when is_binary(pattern) do
    String.contains?(normalize(text), normalize(pattern))
  end

  def when?(%{regex: %Regex{} = regex}, text) do
    Regex.match?(regex, normalize(text))
  end

  def when?(%{regex: pattern}, text) when is_binary(pattern) do
    case compile_regex(pattern) do
      {:ok, regex} -> Regex.match?(regex, normalize(text))
      :error -> false
    end
  end

  def when?(_other, _text), do: false

  @doc """
  Si el `target` de una regla casa con un modelo del catalogo.

  ## Ejemplos

      iex> model = %{alias: :a, provider: :p, locality: :cloud, capabilities: [], tags: []}
      iex> Gunther.Router.Rules.matches?(%{locality: "cloud"}, model)
      true
  """
  @spec matches?(map(), map()) :: boolean()
  def matches?(target, model) when is_map(target) and is_map(model) do
    Enum.any?(target, fn {key, value} -> target_matches?(key, value, model) end)
  end

  def matches?(_target, _model), do: false

  @doc """
  Aplica un conjunto de reglas a los candidatos.

  Devuelve `{eligible, filtered, applied}`:

    * `eligible` — los candidatos que quedan tras `veto` y `force`
    * `filtered` — los eliminados, con su motivo (`:veto` o `:force`)
    * `applied` — los nombres de las reglas que se aplicaron

  **El orden de las reglas no importa para `veto` y `force`**: todos los vetos
  se aplican antes que todos los forces, y un veto gana siempre. Lo que si
  depende del orden son los `prefer`, que suman.

  Las reglas de consumer van antes que las globales en la lista: asi, si
  ambas eliminan al mismo candidato, el motivo registrado es el del consumer.

  ## Ejemplos

      iex> models = [%{alias: :a, provider: :p, locality: :cloud, capabilities: [], tags: []}]
      iex> rules = [%{name: "v", action: :veto, target: %{locality: "cloud"}}]
      iex> {eligible, filtered, applied} = Gunther.Router.Rules.apply(models, rules, "texto", [])
      iex> {eligible, filtered, applied}
      {[], [%{model: :a, reason: :veto}], ["v"]}
  """
  @spec apply([map()], [rule()], String.t(), [rule()]) :: {[map()], [map()], [String.t()]}
  def apply(models, rules, text, consumer_rules \\ []) do
    all = consumer_rules ++ rules
    {matched, _unmatched} = Enum.split_with(all, &when?(&1["when"] || &1[:when], text))

    applied_names = Enum.map(matched, &name_of/1)

    vetoed = Enum.filter(matched, &(action_of(&1) == :veto))
    forced = Enum.filter(matched, &(action_of(&1) == :force))

    # 1. El veto elimina. El motivo registrado es el del consumer si hay uno:
    #    las reglas de consumer van primero en la lista.
    {after_veto, veto_filtered} = apply_veto(models, vetoed)

    # 2. El force restringe a los que casan con TODOS los forces.
    {after_force, force_filtered} = apply_force(after_veto, forced)

    filtered = veto_filtered ++ force_filtered
    {after_force, filtered, applied_names}
  end

  @doc """
  Los pesos que acumulan las reglas `prefer` para cada modelo.

  ## Ejemplos

      iex> models = [%{alias: :a, provider: :p, locality: :cloud, capabilities: [], tags: []}]
      iex> rules = [%{name: "p", action: :prefer, weight: 2.0, target: %{models: ["a"]}}]
      iex> Gunther.Router.Rules.preferences(models, rules)
      %{a: 2.0}
  """
  @spec preferences([map()], [rule()]) :: %{optional(atom()) => float()}
  def preferences(models, rules) do
    prefer = Enum.filter(rules, &(action_of(&1) == :prefer))

    Enum.reduce(models, %{}, fn model, acc ->
      total =
        prefer
        |> Enum.filter(&matches?(target_of(&1), model))
        |> Enum.map(&weight_of/1)
        |> Enum.sum()

      Map.put(acc, model.alias, total)
    end)
  end

  # --- internos ---

  defp apply_veto(models, vetoes) do
    if vetoes == [] do
      {models, []}
    else
      {kept, removed} = Enum.split_with(models, fn model -> not vetoed?(model, vetoes) end)

      filtered =
        removed
        |> Enum.map(&%{model: &1.alias, reason: :veto})
        |> order_by_input(models)

      {kept, filtered}
    end
  end

  defp apply_force(models, forces) do
    if forces == [] do
      {models, []}
    else
      {kept, removed} = Enum.split_with(models, fn model -> kept_by_force?(model, forces) end)

      filtered =
        removed
        |> Enum.map(&%{model: &1.alias, reason: :force})
        |> order_by_input(models)

      {kept, filtered}
    end
  end

  defp vetoed?(model, vetoes), do: Enum.any?(vetoes, &matches?(target_of(&1), model))

  # Dos forces en desacuerdo se intersectan: el modelo tiene que casar con
  # los dos, no con uno solo.
  defp kept_by_force?(model, forces) do
    Enum.all?(forces, &matches?(target_of(&1), model))
  end

  # El `filtered` sale en el orden de los candidatos, no en el de las reglas.
  defp order_by_input(filtered, models) do
    aliases = Enum.map(models, & &1.alias)
    Enum.sort_by(filtered, &Enum.find_index(aliases, fn a -> a == &1.model end))
  end

  # Las claves de un target pueden ser atomos (como las convierte el
  # validador de configuracion) o cadenas (como se escriben en el TOML).
  defp target_matches?(key, value, model) do
    case key do
      k when k in ["models", :models] ->
        matches_list?(value, &(to_string(&1) == to_string(model.alias)))

      k when k in ["provider", :provider] ->
        to_string(model.provider) == to_string(value)

      k when k in ["node", :node] ->
        to_string(model.node) == to_string(value)

      k when k in ["capability", :capability] ->
        matches_list?(model.capabilities, &(to_string(&1) == to_string(value)))

      k when k in ["locality", :locality] ->
        to_string(model.locality) == to_string(value)

      k when k in ["tags", :tags] ->
        matches_list?(model.tags, &(to_string(&1) == to_string(value)))

      _other ->
        false
    end
  end

  defp matches_list?(value, fun) when is_list(value), do: Enum.any?(value, fun)
  defp matches_list?(_value, _fun), do: false

  defp name_of(rule), do: to_string(rule["name"] || rule[:name])
  defp action_of(rule), do: rule["action"] || rule[:action]
  defp target_of(rule), do: rule["target"] || rule[:target]
  defp weight_of(rule), do: (rule["weight"] || rule[:weight] || 0.0) * 1.0

  # El texto y los patrones se comparan en minusculas y sin diacriticos: una
  # regla que busca "información" tiene que casar con "INFORMACIÓN".
  defp normalize(text) when is_binary(text) do
    text
    |> String.downcase()
    |> strip_diacritics()
  end

  # Los diacríticos se quitan con una tabla explicita, no con
  # `String.normalize/2`: esa depende de que la build traiga las categorias
  # Unicode completas, y sin ellas devuelve el texto sin descomponer. La
  # tabla cubre el castellano y el portugues, que es lo que aparece en los
  # prompts y en los patrones de las reglas.
  @diacritics %{
    "á" => "a",
    "à" => "a",
    "ä" => "a",
    "â" => "a",
    "ã" => "a",
    "å" => "a",
    "ā" => "a",
    "é" => "e",
    "è" => "e",
    "ë" => "e",
    "ê" => "e",
    "ē" => "e",
    "í" => "i",
    "ì" => "i",
    "ï" => "i",
    "î" => "i",
    "ī" => "i",
    "ó" => "o",
    "ò" => "o",
    "ö" => "o",
    "ô" => "o",
    "õ" => "o",
    "ø" => "o",
    "ō" => "o",
    "ú" => "u",
    "ù" => "u",
    "ü" => "u",
    "û" => "u",
    "ū" => "u",
    "ñ" => "n",
    "ç" => "c",
    "ß" => "ss",
    "æ" => "ae",
    "œ" => "oe",
    "ý" => "y",
    "ÿ" => "y"
  }

  defp strip_diacritics(text) do
    text
    |> String.graphemes()
    |> Enum.map_join("", fn grapheme -> Map.get(@diacritics, grapheme, grapheme) end)
  end

  defp compile_regex(pattern) do
    {:ok, Regex.compile!(pattern, "u")}
  rescue
    _error -> :error
  end
end
