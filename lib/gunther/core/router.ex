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

  El `reason` de la decision dice **por que** se eligio el que se eligio
  (§4.13): `:veto` cuando un veto decidio el conjunto, `:force` cuando el
  operador fijo el destino, `:rule` cuando solo hubo un `prefer` que
  pondero, y `:cache`, `:pin`, `:embedding`, `:llm` o `:fallback` segun la
  capa que resolvio. El `layers_ran` dice **que capas** corrieron: son dos
  cosas distintas.

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
          pin: atom() | nil,
          requirements: map(),
          catalog_hash: binary(),
          cache: module(),
          cache_enabled: boolean()
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
         {:ok, decision} <- decide(candidates, messages, text, opts) do
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

  defp decide(candidates, messages, text, opts) do
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
          resolve(after_rules, :force, [:rule], opts, filtered, applied_consumer, applied_global)

        # El pin es eje A: gana a las capas blandas (§6.2).
        pin != nil ->
          pin_model(after_rules, pin, filtered, consumer, applied_consumer, applied_global)

        true ->
          soft_layers(
            after_rules,
            messages,
            text,
            opts,
            filtered,
            applied_consumer,
            applied_global,
            rule_reason(vetoed?, preferred?)
          )
      end
    end
  end

  # Las capas blandas, con la cache delante (§6.1).
  #
  # El veto y el force se aplican **antes** de mirar la cache, y un hit no
  # los salta: son deterministas y gratis, y ademas un cambio de reglas
  # cambia el hash del catalogo, que es parte de la clave.
  #
  # El pin tampoco pasa por aqui: es eje A y ya ha resuelto.
  defp soft_layers(
         candidates,
         messages,
         text,
         opts,
         filtered,
         applied_consumer,
         applied_global,
         rule_reason
       ) do
    case lookup(text, opts) do
      {:ok, ranking} ->
        # El ranking cacheado se revalida: un alias que ya no es elegible se
        # descarta. Si no queda ninguno, el hit no vale y se recalcula.
        eligible = Enum.filter(candidates, &(&1.alias in ranking))

        case eligible do
          [] ->
            compute_layers(
              candidates,
              messages,
              text,
              opts,
              filtered,
              applied_consumer,
              applied_global,
              rule_reason
            )

          _eligible ->
            ranked = Enum.map(eligible, & &1.alias)
            chosen = List.first(ranked)
            model = Enum.find(candidates, &(&1.alias == chosen))

            {:ok, build(model, :cache, [:cache], ranked, filtered, applied_consumer, applied_global)}
        end

      :error ->
        compute_layers(
          candidates,
          messages,
          text,
          opts,
          filtered,
          applied_consumer,
          applied_global,
          rule_reason
        )
    end
  end

  # Las capas blandas en orden (§6.1): `:rule` si opino, `:embedding`,
  # `:llm` y `fallback` al final. Gana la primera que opina; las siguientes no
  # se pagan (§6.2, eje B).
  #
  # `router.llm` decide si la capa `:llm` existe (§6.3): `never` la quita,
  # `fallback` (defecto) la deja correr solo si las baratas no resolvieron, y
  # `always` la corre siempre.
  defp compute_layers(
         candidates,
         messages,
         text,
         opts,
         filtered,
         applied_consumer,
         applied_global,
         rule_reason
       ) do
    {result, ranking} =
      soft_layers_chain(
        candidates,
        messages,
        text,
        opts,
        filtered,
        applied_consumer,
        applied_global,
        rule_reason
      )

    with {:ok, _decision} <- result do
      store(text, opts, ranking)
    end

    result
  end

  defp soft_layers_chain(
         candidates,
         messages,
         text,
         opts,
         filtered,
         applied_consumer,
         applied_global,
         rule_reason
       ) do
    {result, ranking, degraded} =
      if rule_reason do
        # La capa :rule opino: corta (§6.10).
        {resolve(candidates, rule_reason, [:rule], opts, filtered, applied_consumer, applied_global),
         apply_strategy(rank_pure(candidates, prefer_weights(opts, candidates)), strategy(opts)), []}
      else
        case embedding_layer(candidates, text, opts) do
          {:ok, ranking} ->
            {build_embedding(ranking, candidates, filtered, applied_consumer, applied_global), ranking, []}

          {:skip, _reason, degraded} ->
            {nil, nil, degraded}
        end
      end

    case result do
      nil ->
        # La capa :embedding no.opino: sigue la :llm y, al final, el fallback.
        llm_or_fallback(candidates, messages, opts, filtered, applied_consumer, applied_global, degraded)

      _resolved ->
        {result, ranking}
    end
  end

  # La capa :llm y, si no hay, el fallback.
  defp llm_or_fallback(candidates, messages, opts, filtered, applied_consumer, applied_global, degraded) do
    case llm_layer(candidates, messages, opts) do
      {:ok, ranking, info} ->
        {build_llm(ranking, candidates, info, filtered, applied_consumer, applied_global), ranking}

      {:skip, _reason, llm_degraded} ->
        {fallback(candidates, opts, [], filtered, applied_consumer, applied_global, degraded ++ llm_degraded),
         apply_strategy(rank_pure(candidates, prefer_weights(opts, candidates)), strategy(opts))}
    end
  end

  # La capa :llm (SPEC §6.3). Sin modelo de decision la capa no existe.
  defp llm_layer(candidates, messages, opts) do
    spec = Keyword.get(opts, :decision_spec)
    mode = Keyword.get(opts, :llm_mode, :fallback)

    if is_nil(spec) or mode == :never do
      {:skip, :no_spec, []}
    else
      Gunther.Router.Llm.rank(candidates, messages, spec, llm_opts(opts))
    end
  end

  defp llm_opts(opts) do
    opts
    |> Keyword.take([:provider, :model_id, :timeout_ms, :allow_unverified, :mock])
    |> Keyword.put_new(:timeout_ms, 1_500)
  end

  defp build_llm(ranking, candidates, info, filtered, applied_consumer, applied_global) do
    chosen = List.first(ranking)
    model = Enum.find(candidates, &(&1.alias == chosen))

    decision =
      build(model, :llm, [:llm], ranking, filtered, applied_consumer, applied_global)

    {:ok, %{decision | decision_model: info}}
  end

  # La capa :embedding (SPEC §6.1). Sin embedder registrado la capa no
  # existe (§6.10) y el router sigue con el fallback.
  defp embedding_layer(candidates, text, opts) do
    embedder = Keyword.get(opts, :embedder)
    embedding = Keyword.get(opts, :embedding, %{})

    cond do
      # Sin embedder registrado la capa no existe (§6.10): no es un fallo y
      # no deja aviso.
      embedder == nil ->
        {:skip, :no_embedder, []}

      # La capa no esta verificada (§6.11): no acts. El aviso lo dice.
      not verified?(embedding, opts) ->
        {:skip, :unverified, [:classifier_unverified]}

      true ->
        case Gunther.Router.Embedding.rank(candidates, text, embedder, %{
               min_similarity: Map.get(embedding, :min_similarity, 0.0),
               embedder_opts: Keyword.get(opts, :embedder_opts, [])
             }) do
          {:ok, ranking} ->
            {:ok, ranking}

          {:skip, {:embedder_error, _reason}} ->
            {:skip, :embedder_error, [:embedding_unavailable]}

          {:skip, reason} ->
            {:skip, reason, []}
        end
    end
  end

  # La capa esta verificada (§6.11), o el operador permite actuar sin
  # verificar (`router.allow_unverified`, defecto `false`).
  defp verified?(embedding, opts) do
    Map.get(embedding, :verified, false) or Keyword.get(opts, :allow_unverified, false)
  end

  defp build_embedding(ranking, candidates, filtered, applied_consumer, applied_global) do
    chosen = List.first(ranking)
    model = Enum.find(candidates, &(&1.alias == chosen))

    {:ok, build(model, :embedding, [:embedding], ranking, filtered, applied_consumer, applied_global)}
  end

  # La lectura de la cache. Sin hash de catalogo no se cachea: sin el no se
  # puede invalidar cuando la configuracion cambia (§6.5).
  defp lookup(text, opts) do
    with true <- Keyword.get(opts, :cache_enabled, true),
         hash when is_binary(hash) and hash != "" <- Keyword.get(opts, :catalog_hash) do
      cache = Keyword.get(opts, :cache, Gunther.Cache.Decisions)
      cache.get(cache_key(opts, hash, text))
    else
      _other -> :error
    end
  end

  # La escritura del ranking. Lo que se guarda es el ranking **final**: con
  # la estrategia ya aplicada, para que un hit se sirva tal cual. Cuando
  # `least_used` y `round_robin` dependan de un estado que cambia, el
  # ranking a guardar tiene que ser el previo a la estrategia.
  defp store(text, opts, ranking) do
    with true <- Keyword.get(opts, :cache_enabled, true),
         hash when is_binary(hash) and hash != "" <- Keyword.get(opts, :catalog_hash) do
      cache = Keyword.get(opts, :cache, Gunther.Cache.Decisions)
      cache.put(cache_key(opts, hash, text), ranking)
    else
      _other -> :ok
    end
  end

  # La clave de §6.5: {consumer, pin, force, firma de requisitos, hash del
  # catalogo, ultimo mensaje de usuario normalizado}.
  defp cache_key(opts, catalog_hash, text) do
    Gunther.Cache.Decisions.key(
      consumer: Keyword.get(opts, :consumer, :default),
      pin: Keyword.get(opts, :model) || Keyword.get(opts, :pin),
      force: Keyword.get(opts, :force, false),
      requirements: Keyword.get(opts, :requirements, %{}),
      catalog_hash: catalog_hash,
      text: text
    )
  end

  # El `reason` de una decision que resuelve la capa de reglas (SPEC §4.13).
  #
  # La enumeracion distingue `:veto`, `:force` y `:rule`, asi que el motivo
  # se distingue tambien: un veto es seguridad y un force es el operador.
  # Un `prefer` solo pondera, y ahi el motivo es la capa de reglas.
  #
  # `nil` significa que la capa de reglas **no opino**: entonces el destino
  # lo eligen las capas de abajo. Asi el motivo y el "opino" son la misma
  # cosa, y no hacen falta dos parametros para decirlo.
  defp rule_reason(vetoed?, preferred?) do
    cond do
      vetoed? -> :veto
      preferred? -> :rule
      true -> nil
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
  defp fallback(candidates, opts, layers_ran, filtered, applied_consumer, applied_global, degraded) do
    ranked = order(candidates, strategy(opts))

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
           applied_global,
           degraded
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

  defp build(model, reason, layers_ran, ranked, filtered, applied_consumer, applied_global, degraded \\ []) do
    # Un modelo de un catalogo mal formado no revienta el enrutado: la
    # decision sale con lo que haya, y el `reason` lo delata. Los errores
    # son valores (SPEC §4.13), no excepciones.
    %Decision{
      chosen: Map.get(model, :alias),
      provider: Map.get(model, :provider),
      node: Map.get(model, :node),
      ranked: ranked,
      reason: reason,
      layers_ran: layers_ran,
      candidates_per_layer: [
        %{layer: List.last(layers_ran), before: length(ranked), after: length(ranked)}
      ],
      filtered: filtered,
      degraded: degraded,
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
    |> rank_pure(weights)
    |> apply_strategy(strategy)
  end

  # El ranking puro: el orden que sale de las capas blandas, con el peso de
  # las reglas `prefer` y sin la estrategia. Es lo que se cachea (§6.5): la
  # estrategia se aplica al servir, porque `least_used` y `round_robin`
  # dependen de un estado que cambia.
  defp rank_pure(candidates, weights) do
    candidates
    |> Enum.sort_by(&{-Map.get(weights, &1.alias, 0.0), &1.alias})
    |> Enum.map(& &1.alias)
  end

  defp strategy(opts), do: Keyword.get(opts, :fallback_strategy, :least_used)

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
