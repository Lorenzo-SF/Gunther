defmodule Gunther.Router do
  @moduledoc """
  El motor de decisiones (SPEC §6).

  `route/2` decide a qué modelo va una petición. No llama a ningún modelo
  salvo que la capa `:llm` esté activa: las capas caras van después de las
  baratas y la primera que resuelve corta las siguientes.

  Las capas y su orden (§6.1):

    1. `:cache` — una lectura de ETS
    2. `:pin` — el consumer fijó un modelo
    3. `:rule` — las reglas de la configuración
    4. `:embedding` — similitud prompt ↔ skills
    5. `:llm` — el modelo de decisión especializado
    6. `:fallback` — el modelo normal

  La precedencia (§6.2) es la eje A: `veto` (seguridad) → `force` (operador) →
  `pin` → capas blandas → `fallback`. Un `veto` gana a un `pin`, y un `force`
  tambien.

  ## Ejemplos

      iex> catalog = %{version: 1, models: %{a: %{alias: :a, provider: :p, locality: :cloud, capabilities: [], tags: []}}, providers: %{}, nodes: %{}}
      iex> opts = [catalog: catalog, consumer: :default, rules: [], consumer_rules: [], fallback_strategy: :least_used]
      iex> {:ok, decision} = Gunther.Router.route([%{role: :user, content: "hola"}], opts)
      iex> decision.chosen
      :a
  """

  alias Gunther.Decision
  alias Gunther.Error
  alias Gunther.Router.Rules

  @type opts :: [
          catalog: map(),
          consumer: atom(),
          rules: [Rules.rule()],
          consumer_rules: [Rules.rule()],
          fallback_strategy: atom(),
          model: atom() | nil,
          pin: atom() | nil
        ]

  @doc """
  Decide a qué modelo va una petición.

  Devuelve `{:ok, decision}` o `{:error, error}`. Los errores son valores
  (§4.13): `:invalid_request` para una petición mal formada, `:no_candidates`
  cuando no queda ningún modelo elegible.

  ## Ejemplos

      iex> catalog = %{version: 1, models: %{a: %{alias: :a, provider: :p, locality: :cloud, capabilities: [], tags: []}}, providers: %{}, nodes: %{}}
      iex> opts = [catalog: catalog, consumer: :default, rules: [], consumer_rules: [], fallback_strategy: :least_used]
      iex> {:ok, decision} = Gunther.Router.route([%{role: :user, content: "hola"}], opts)
      iex> decision.reason
      :fallback
  """
  @spec route([map()], opts()) :: {:ok, Decision.t()} | {:error, Error.t()}
  def route(messages, opts) do
    started = System.monotonic_time(:millisecond)

    with :ok <- validate_messages(messages),
         {:ok, text} <- extract_text(messages),
         catalog = Keyword.get(opts, :catalog),
         candidates = eligible(catalog),
         {:ok, decision} <- decide(candidates, text, opts) do
      {:ok, %{decision | duration_ms: System.monotonic_time(:millisecond) - started}}
    end
  end

  @doc """
  La traza de una decisión (SPEC §6.6).

  **Sin traza no hay enrutado**: la traza dice qué capas corrieron, cuántos
  candidatos vio cada una, por que se eligio el que se eligio y que se
  descarto.

  ## Ejemplos

      iex> catalog = %{version: 1, models: %{a: %{alias: :a, provider: :p, locality: :cloud, capabilities: [], tags: []}}, providers: %{}, nodes: %{}}
      iex> opts = [catalog: catalog, consumer: :default, rules: [], consumer_rules: [], fallback_strategy: :least_used]
      iex> {:ok, decision} = Gunther.Router.route([%{role: :user, content: "hola"}], opts)
      iex> Gunther.Router.trace(decision).chosen
      :a
  """
  @spec trace(Decision.t()) :: map()
  def trace(%Decision{} = decision) do
    %{
      layers_ran: decision.layers_ran,
      candidates_per_layer: decision.candidates_per_layer,
      chosen: decision.chosen,
      ranked: decision.ranked,
      reason: decision.reason,
      duration_ms: decision.duration_ms,
      degraded: decision.degraded,
      filtered: decision.filtered,
      decision_model: decision.decision_model,
      consumer_rules_applied: decision.consumer_rules_applied,
      global_rules_applied: decision.global_rules_applied
    }
  end

  # --- la decisión ---

  defp decide(candidates, text, opts) do
    consumer = Keyword.get(opts, :consumer, :default)
    global_rules = Keyword.get(opts, :rules, [])
    consumer_rules = Keyword.get(opts, :consumer_rules, [])

    # Eje A: `veto` y `force` son deterministas y se evaluan ANTES que
    # cualquier capa blanda. Un veto gana a un pin y a un force (SPEC §6.2).
    {after_rules, filtered, applied_consumer, applied_global, forced?, preferred?, vetoed?} =
      apply_rules(candidates, text, global_rules, consumer_rules)

    if after_rules == [] do
      {:error,
       Error.new(:no_candidates, "no queda ningun modelo elegible", details: %{filtered: filtered, consumer: consumer})}
    else
      pin = Keyword.get(opts, :model) || Keyword.get(opts, :pin)

      cond do
        # Un `force` fija el destino y gana al pin (§6.2).
        forced? ->
          resolve(after_rules, :rule, [:rule], opts, filtered, applied_consumer, applied_global)

        # Un `veto` o un `prefer` no fijan el destino: restringen o ponderan.
        # Si no hay pin, el destino lo elige la capa :rule.
        (vetoed? or preferred?) and pin == nil ->
          resolve(after_rules, :rule, [:rule], opts, filtered, applied_consumer, applied_global)

        pin != nil ->
          pin_model(after_rules, pin, filtered, consumer, applied_consumer, applied_global)

        true ->
          fallback(after_rules, opts, [], filtered, applied_consumer, applied_global)
      end
    end
  end

  # El modelo pineado, si sigue siendo elegible. Un veto o un force pueden
  # haberselo carried fuera.
  defp pin_model(candidates, pin, filtered, consumer, applied_consumer, applied_global) do
    case Enum.find(candidates, &(&1.alias == pin)) do
      nil ->
        {:error,
         Error.new(:no_candidates, "el modelo fijado no es elegible",
           details: %{model: pin, filtered: filtered, consumer: consumer}
         )}

      model ->
        {:ok, build(model, :pin, [:pin], [model.alias], filtered, applied_consumer, applied_global)}
    end
  end

  # La capa de fallback: el modelo normal, ordenado por `fallback_strategy`.
  defp fallback(candidates, opts, layers_ran, filtered, applied_consumer, applied_global) do
    strategy = Keyword.get(opts, :fallback_strategy, :least_used)
    ranked = order(candidates, strategy)

    case ranked do
      [] ->
        {:error, Error.new(:no_candidates, "no queda ningun modelo elegible", details: %{filtered: filtered})}

      [chosen | rest] ->
        model = Enum.find(candidates, &(&1.alias == chosen))

        {:ok,
         build(
           model,
           :fallback,
           layers_ran ++ [:fallback],
           [chosen | rest],
           filtered,
           applied_consumer,
           applied_global
         )}
    end
  end

  # La capa :rule resuelve: el conjunto se ha restringido y el destino lo
  # fija la regla, no el fallback. Entre los que quedan, el `prefer` pesa.
  defp resolve(candidates, reason, layers_ran, opts, filtered, applied_consumer, applied_global) do
    strategy = Keyword.get(opts, :fallback_strategy, :least_used)
    ranked = order(candidates, strategy, prefer_weights(opts, candidates))

    case ranked do
      [] ->
        {:error, Error.new(:no_candidates, "no queda ningun modelo elegible", details: %{filtered: filtered})}

      [chosen | rest] ->
        model = Enum.find(candidates, &(&1.alias == chosen))

        {:ok, build(model, reason, layers_ran, [chosen | rest], filtered, applied_consumer, applied_global)}
    end
  end

  defp apply_rules(candidates, text, global_rules, consumer_rules) do
    # Las reglas de consumer van primero: si ambas eliminan al mismo
    # candidato, el motivo registrado es el del consumer (§6.8.1).
    {eligible, filtered, applied} = Rules.apply(candidates, global_rules, text, consumer_rules)

    {consumer_applied, global_applied} = split_applied(applied, consumer_rules, global_rules)

    forced? = Enum.any?(applied, &action_applied?(&1, :force, global_rules, consumer_rules))
    preferred? = Enum.any?(applied, &action_applied?(&1, :prefer, global_rules, consumer_rules))
    vetoed? = Enum.any?(applied, &action_applied?(&1, :veto, global_rules, consumer_rules))

    {eligible, filtered, consumer_applied, global_applied, forced?, preferred?, vetoed?}
  end

  defp action_applied?(name, action, global_rules, consumer_rules) do
    Enum.any?(global_rules ++ consumer_rules, fn rule ->
      to_string(rule["name"] || rule[:name]) == name and
        (rule["action"] || rule[:action]) == action
    end)
  end

  # Los nombres de las reglas aplicadas se separan por su origen: una regla
  # de consumer y una global pueden llamarse igual.
  defp split_applied(applied, consumer_rules, global_rules) do
    consumer_names = Enum.map(consumer_rules, &to_string(&1["name"] || &1[:name]))
    global_names = Enum.map(global_rules, &to_string(&1["name"] || &1[:name]))

    consumer_applied = Enum.filter(applied, &(&1 in consumer_names))
    global_applied = Enum.filter(applied, &(&1 in global_names and &1 not in consumer_names))

    {consumer_applied, global_applied}
  end

  defp build(model, reason, layers_ran, ranked, filtered, applied_consumer, applied_global) do
    %Decision{
      chosen: model.alias,
      provider: model.provider,
      node: model.node,
      ranked: ranked,
      reason: reason,
      layers_ran: layers_ran,
      candidates_per_layer: [
        %{layer: List.last(layers_ran), before: length(ranked), after: length(ranked)}
      ],
      filtered: filtered,
      consumer_rules_applied: applied_consumer,
      global_rules_applied: applied_global,
      trace_id: trace_id(),
      timestamp: DateTime.utc_now()
    }
  end

  # El orden del fallback (SPEC §6.7). `least_used` y `round_robin` dependen
  # del estado del router, que no existe todavia: por defecto se ordenan
  # por alias, de forma determinista.
  defp order(candidates, strategy, weights \\ %{}) do
    candidates
    |> Enum.sort_by(&{-Map.get(weights, &1.alias, 0.0), &1.alias})
    |> Enum.map(& &1.alias)
    |> apply_strategy(strategy)
  end

  # `prefer` pondera el orden; la estrategia decide el desempate.
  defp apply_strategy(aliases, :last), do: Enum.reverse(aliases)
  defp apply_strategy(aliases, :first), do: aliases
  defp apply_strategy(aliases, _strategy), do: aliases

  # Los pesos que acumulan las reglas `prefer`.
  defp prefer_weights(opts, candidates) do
    rules = Keyword.get(opts, :rules, []) ++ Keyword.get(opts, :consumer_rules, [])
    Rules.preferences(candidates, rules)
  end

  defp eligible(catalog), do: catalog |> Map.get(:models, %{}) |> Map.values() |> Enum.sort_by(& &1.alias)

  # --- la peticion ---

  defp validate_messages(messages) when is_list(messages) and messages != [] do
    if Enum.all?(messages, &valid_message?/1) do
      :ok
    else
      {:error,
       Error.new(:invalid_request, "los mensajes deben tener un rol :user, :system o :assistant",
         details: %{roles: Enum.map(messages, &Map.get(&1, :role))}
       )}
    end
  end

  defp validate_messages(_messages) do
    {:error, Error.new(:invalid_request, "la peticion necesita al menos un mensaje")}
  end

  defp valid_message?(message) when is_map(message) do
    Map.get(message, :role) in [:user, :system, :assistant]
  end

  defp valid_message?(_message), do: false

  # El texto que se evalua para las reglas es el del ultimo mensaje de
  # usuario: es el que expresa la intencion.
  defp extract_text(messages) do
    case Enum.reverse(messages) do
      [%{role: :user} = message | _rest] ->
        {:ok, content_text(Map.get(message, :content, ""))}

      _other ->
        {:ok, ""}
    end
  end

  defp content_text(content) when is_binary(content), do: content

  defp content_text(parts) when is_list(parts) do
    parts
    |> Enum.filter(&(is_map(&1) and Map.get(&1, :type) == :text))
    |> Enum.map_join("\n", &Map.get(&1, :text, ""))
  end

  defp content_text(_content), do: ""

  defp trace_id do
    Base.encode16(:crypto.strong_rand_bytes(8), case: :lower)
  end
end
