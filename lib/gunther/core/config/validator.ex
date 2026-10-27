defmodule Gunther.Config.Validator do
  @moduledoc """
  Valida la configuración de Gunther (SPEC §14.1, §14.2).

  ## Claves desconocidas (D-26 con excepción, CE-H11)

  Una clave desconocida es **aviso**, salvo en las secciones `[commands]`,
  `[nodes]`, `[tools]`, `[mcp]`, `[gateway]`, `[security]`, `[coral]` y
  `[[consumers.<id>.rules]]`, donde es **error**: una errata en `allow_private`,
  en un permiso o en una regla de consumer no puede degradarse a un aviso.

  ## Validaciones cruzadas

  Cada una de las de §14.2 es `config_error`.
  """

  alias Gunther.Config
  alias Gunther.Error

  @security_sections ["commands", "nodes", "tools", "mcp", "gateway", "security", "coral"]

  @skills ~w(code reasoning redaction vision audio tools embeddings)a
  @localities ~w(local lan cloud)a
  @modalities ~w(text image audio video)a
  @backends ~w(cuda vulkan rocm metal cpu)a
  @fallback_strategies ~w(last first round_robin least_used)a
  @refusal_policies ~w(fail wait degrade)a
  @llm_modes ~w(never fallback always)a
  @structured_modes ~w(auto native prompt)a
  @compaction_modes ~w(none truncate summary)a
  @stores ~w(memory sqlite postgres)a
  @store_backends ~w(separate shared)a
  @strategies ~w(vector lexical hybrid multi_query)a
  @permissions ~w(auto confirm deny)a
  @actions ~w(veto force prefer)a
  @fits ~w(auto formula declared)a
  @rule_targets ["models", "provider", "node", "capability", "locality", "tags"]
  @kinds ~w(discrete unified)a
  @decision_kinds ~w(preference_router win_rate_binary general_llm)a

  @doc """
  Valida un mapa de configuración crudo.

  ## Ejemplos

      iex> {:ok, config} = Gunther.Config.Validator.validate(%{gunther: %{instance_id: "main"}})
      iex> config.router.fallback_strategy
      :least_used
  """
  @spec validate(map()) :: {:ok, Config.t()} | {:error, Error.t()}
  def validate(raw) when is_map(raw) do
    # Las secciones de seguridad se comprueban ANTES de interpretarlas: una
    # errata en `allow_private`, en un permiso o en un nombre de regla no
    # puede degradarse a un aviso (CE-H11).
    with :ok <- check_security_sections(raw),
         :ok <- validate_gunther(raw),
         {:ok, gunther} <- gunther_section(raw),
         {:ok, router} <- router(raw),
         {:ok, refusal} <- refusal(raw),
         {:ok, retry} <- retry(raw),
         {:ok, circuit_breaker} <- circuit_breaker(raw),
         {:ok, engine} <- engine(raw),
         {:ok, devices} <- devices(raw),
         {:ok, commands} <- commands(raw),
         {:ok, engines} <- engines(raw),
         {:ok, models} <- models(raw),
         {:ok, nodes} <- nodes(raw),
         {:ok, placement} <- placement(raw),
         {:ok, decision_models} <- decision_models(raw),
         {:ok, rules} <- rules(raw),
         {:ok, providers} <- providers(raw),
         {:ok, structured} <- structured(raw),
         {:ok, stream} <- stream(raw),
         {:ok, context} <- context(raw),
         {:ok, sessions} <- sessions(raw),
         {:ok, memory} <- memory(raw),
         {:ok, selector} <- selector(raw),
         {:ok, consumers} <- consumers(raw),
         {:ok, cache} <- cache(raw),
         {:ok, tools} <- tools(raw),
         {:ok, mcp} <- mcp(raw),
         {:ok, mcp_clients} <- mcp_clients(raw),
         {:ok, agents} <- agents(raw),
         {:ok, rag} <- rag(raw),
         {:ok, embedders} <- embedders(raw),
         {:ok, guardrails} <- guardrails(raw),
         {:ok, budget} <- budget(raw),
         {:ok, gateway} <- gateway(raw),
         {:ok, security} <- security(raw),
         {:ok, telemetry} <- telemetry(raw) do
      config = %Config{
        gunther: gunther,
        router: router,
        refusal: refusal,
        retry: retry,
        circuit_breaker: circuit_breaker,
        engine: engine,
        devices: devices,
        commands: commands,
        engines: engines,
        models: models,
        nodes: nodes,
        placement: placement,
        decision_models: decision_models,
        rules: rules,
        providers: providers,
        structured: structured,
        stream: stream,
        context: context,
        sessions: sessions,
        memory: memory,
        selector: selector,
        consumers: consumers,
        cache: cache,
        tools: tools,
        mcp: mcp,
        mcp_clients: mcp_clients,
        agents: agents,
        rag: rag,
        embedders: embedders,
        guardrails: guardrails,
        budget: budget,
        gateway: gateway,
        security: security,
        telemetry: telemetry
      }

      case cross_validate(config) do
        :ok -> {:ok, config}
        {:error, error} -> {:error, error}
      end
    end
  end

  def validate(_other) do
    {:error, Error.new(:config_error, "la configuracion debe ser un mapa")}
  end

  # --- [gunther] ---

  defp validate_gunther(raw) do
    case Map.get(raw, "gunther") do
      nil ->
        {:error, Error.new(:config_error, "[gunther] es obligatorio", details: %{section: "gunther"})}

      section when is_map(section) ->
        instance_id = Map.get(section, "instance_id")

        cond do
          is_nil(instance_id) ->
            {:error, Error.new(:config_error, "[gunther].instance_id es obligatorio", details: %{key: "instance_id"})}

          not (is_binary(instance_id) and instance_id =~ ~r/^[a-z0-9_-]{1,32}$/) ->
            {:error,
             Error.new(:config_error, "[gunther].instance_id debe cumplir [a-z0-9_-]{1,32}",
               details: %{key: "instance_id", value: instance_id}
             )}

          true ->
            :ok
        end

      _other ->
        {:error, Error.new(:config_error, "[gunther] debe ser una tabla", details: %{section: "gunther"})}
    end
  end

  # La seccion [gunther] lleva `state_dir` y `dotenv` ademas del
  # `instance_id`. `state_dir` es la raiz de la que cuelgan el estado en
  # disco, los stores y el path derivado del RAG.
  defp gunther_section(raw) do
    with {:ok, map} <- section(raw, "gunther", :gunther, %{}),
         {:ok, instance_id} <- fetch_string(map, "instance_id", nil),
         {:ok, state_dir} <- fetch_string(map, "state_dir", nil),
         {:ok, dotenv} <- fetch_bool(map, "dotenv", false) do
      {:ok, %{instance_id: instance_id, state_dir: state_dir, dotenv: dotenv}}
    end
  end

  # --- helpers genericos ---

  defp section(raw, name, _key, defaults) do
    case Map.get(raw, name) do
      nil ->
        {:ok, defaults}

      map when is_map(map) ->
        case unknown_keys(map, allowed(name)) do
          [] -> {:ok, map}
          unknown -> check_unknown_keys(name, map, unknown)
        end

      _other ->
        {:error, Error.new(:config_error, "[#{name}] debe ser una tabla", details: %{section: name})}
    end
  end

  # Una clave desconocida en una seccion de seguridad es un error; fuera de
  # ellas es un aviso (D-26) y la carga continua.
  defp check_unknown_keys(name, map, unknown) do
    if name in @security_sections do
      {:error,
       Error.new(:config_error, "clave desconocida en la seccion de seguridad [#{name}]",
         details: %{section: name, unknown: unknown}
       )}
    else
      warn_unknown_keys(name, unknown)
      {:ok, map}
    end
  end

  # D-26: fuera de las secciones de seguridad, una clave desconocida es un
  # aviso. Se avisa por log y la carga continua.
  defp warn_unknown_keys(section, unknown) do
    require Logger

    Logger.warning(
      "Gunther: claves desconocidas en [#{section}]: #{Enum.join(unknown, ", ")}. " <>
        "La configuracion se carga igualmente (D-26)."
    )
  end

  defp unknown_keys(map, allowed) do
    map
    |> Map.keys()
    |> Enum.reject(&(&1 in allowed))
    |> Enum.sort()
  end

  defp fetch(map, key, default) do
    case Map.get(map, key) do
      nil -> default
      value -> value
    end
  end

  # Igual que `fetch/3`, pero envuelto en `{:ok, valor}` para poder encadenarlo
  # en un `with`. `fetch/3` devuelve el valor pelado: usarlo con el patron
  # `{:ok, x} <- fetch(...)` hace que el `with` devuelva ese valor tal cual,
  # y el fallo aparece como un valor raro en lugar de un error.
  defp fetch_ok(map, key, default) do
    {:ok, fetch(map, key, default)}
  end

  defp fetch_int(map, key, default) do
    case fetch(map, key, default) do
      value when is_integer(value) -> {:ok, value}
      value -> {:error, type_error(key, "entero", value)}
    end
  end

  defp fetch_bool(map, key, default) do
    case fetch(map, key, default) do
      value when is_boolean(value) -> {:ok, value}
      value -> {:error, type_error(key, "booleano", value)}
    end
  end

  defp fetch_float(map, key, default) do
    case fetch(map, key, default) do
      value when is_float(value) -> {:ok, value}
      value when is_integer(value) -> {:ok, value * 1.0}
      value -> {:error, type_error(key, "float", value)}
    end
  end

  defp fetch_string(map, key, default) do
    case fetch(map, key, default) do
      nil -> {:ok, nil}
      value when is_binary(value) -> {:ok, value}
      value -> {:error, type_error(key, "cadena", value)}
    end
  end

  defp fetch_enum(map, key, default, allowed) do
    case fetch(map, key, default) do
      value when is_binary(value) ->
        atom = safe_atom(value)

        if atom in allowed do
          {:ok, atom}
        else
          {:error,
           Error.new(:config_error, "[#{key}] debe ser uno de #{inspect(allowed)}",
             details: %{key: key, value: value, allowed: allowed}
           )}
        end

      value ->
        {:error, type_error(key, "cadena", value)}
    end
  end

  # Una lista de cadenas (o de atomos ya convertidos) pasa a lista de atomos.
  # Los valores por defecto internos son atomos, no cadenas: si no, un
  # defecto como `[:gunther]` fallaria su propia validacion.
  defp fetch_atom_list(map, key, default) do
    case fetch(map, key, default) do
      value when is_list(value) -> atom_list(value, key)
      value -> {:error, type_error(key, "lista de cadenas", value)}
    end
  end

  # Una lista de cadenas (o de atomos ya convertidos) pasa a lista de atomos.
  # Los valores por defecto internos son atomos, no cadenas: si no, un
  # defecto como `[:gunther]` fallaria su propia validacion.
  defp atom_list(value, key) do
    cond do
      Enum.all?(value, &is_binary/1) -> {:ok, Enum.map(value, &safe_atom/1)}
      Enum.all?(value, &is_atom/1) -> {:ok, Enum.map(value, &safe_atom/1)}
      true -> {:error, type_error(key, "lista de cadenas", value)}
    end
  end

  # Convierte una lista de tablas en una lista de estructuras ya validadas.
  # El primer elemento invalido detiene la recorrido: se devuelve su error y
  # no se sigue validando. `fun` recibe una entrada y devuelve
  # `{:ok, valor}` o `{:error, error}`.
  defp parse_list(list, fun) do
    Enum.reduce_while(list, {:ok, []}, fn entry, {:ok, acc} ->
      case fun.(entry) do
        {:ok, parsed} -> {:cont, {:ok, acc ++ [parsed]}}
        {:error, error} -> {:halt, {:error, error}}
      end
    end)
  end

  # Igual que `parse_list/2`, pero sobre una tabla de entradas: el resultado
  # es un mapa con la clave de la entrada.
  defp parse_map(map, fun) do
    Enum.reduce_while(map, {:ok, %{}}, fn {name, entry}, {:ok, acc} ->
      case fun.(name, entry) do
        {:ok, parsed} -> {:cont, {:ok, Map.put(acc, safe_atom(name), parsed)}}
        {:error, error} -> {:halt, {:error, error}}
      end
    end)
  end

  # El peso de afinidad solo aplica cuando la afinidad esta activa; si lo
  # esta, es obligatorio y tiene que ser un numero.
  defp router_affinity_weight(map, affinity) do
    if affinity == :prefer do
      case fetch(map, "affinity_weight", nil) do
        nil ->
          {:error,
           Error.new(:config_error, "[router].affinity_weight es obligatorio con affinity = \"prefer\"",
             details: %{key: "affinity_weight"}
           )}

        value ->
          fetch_float(%{"affinity_weight" => value}, "affinity_weight", 0.0)
      end
    else
      {:ok, nil}
    end
  end

  # Los limites de bytes por adjunto tienen que ser mayores que cero: un
  # limite de cero o negativo rechazaria cualquier adjunto, y uno ausente
  # dejaria elAttachment sin techo.
  defp check_attachment_bytes(image, audio) do
    if image > 0 and audio > 0 do
      {:ok, %{image: image, audio: audio}}
    else
      {:error,
       Error.new(:config_error, "max_attachment_bytes.image y .audio deben ser mayores que 0",
         details: %{image: image, audio: audio}
       )}
    end
  end

  # Los idiomas de evaluacion son obligatorios cuando el modelo exige
  # evaluacion: sin ellos, el corpus no tiene sobre que evaluarse.
  defp build_eval(corpus, adversarial, languages, confidence, min_top1, max_p99) do
    if languages == [] do
      {:error,
       Error.new(:config_error, "decision_models.eval.required_languages es obligatorio si require_eval",
         details: %{key: "required_languages"}
       )}
    else
      {:ok,
       %{
         corpus: corpus,
         adversarial_corpus: adversarial,
         required_languages: languages,
         confidence: confidence,
         min_top1_accuracy: min_top1,
         max_p99_ms: max_p99
       }}
    end
  end

  # Una entrada de `[tools].permissions`: un patron y el permiso que concede.
  defp tool_permission(entry) do
    with true <- is_map(entry),
         {:ok, pattern} <- fetch_string(entry, "pattern", nil),
         {:ok, permission} <- fetch_enum(entry, "permission", nil, @permissions) do
      {:ok, %{pattern: pattern, permission: permission}}
    else
      false ->
        {:error, Error.new(:config_error, "cada entrada de [tools].permissions debe ser una tabla")}

      {:error, error} ->
        {:error, error}
    end
  end

  defp type_error(key, expected, value) do
    Error.new(:config_error, "[#{key}] debe ser #{expected}", details: %{key: key, expected: expected, value: value})
  end

  # Un TOML puede traer cualquier cadena. `String.to_atom/1` sobre entrada
  # externa crea atoms que nunca se liberan; se usa `String.to_existing_atom/1`
  # con lista blanca.
  #
  # `safe_atom/1` acepta tambien un atomo ya convertido: los defectos
  # internos del validador son atomos, no cadenas, y convertirlos otra vez
  # fallaria.
  defp safe_atom(value) when is_atom(value), do: value

  defp safe_atom(value) when is_binary(value) do
    String.to_existing_atom(value)
  rescue
    ArgumentError -> String.to_atom(value)
  end

  # --- secciones ---

  defp router(raw) do
    with {:ok, map} <- section(raw, "router", :router, %{}),
         {:ok, llm} <- fetch_enum(map, "llm", "fallback", @llm_modes),
         {:ok, llm_timeout_ms} <- fetch_int(map, "llm_timeout_ms", 1500),
         {:ok, llm_warm_cache} <- fetch_bool(map, "llm_warm_cache", false),
         {:ok, max_failovers} <- fetch_int(map, "max_failovers", 2),
         {:ok, max_in_flight} <- fetch_int(map, "max_in_flight", 256),
         {:ok, fallback_strategy} <- fetch_enum(map, "fallback_strategy", "least_used", @fallback_strategies),
         {:ok, regex_match_limit} <- fetch_int(map, "regex_match_limit", 100_000),
         {:ok, allow_general} <- fetch_bool(map, "allow_general", false),
         {:ok, allow_unverified} <- fetch_bool(map, "allow_unverified", false),
         {:ok, affinity} <- fetch_enum(map, "affinity", "off", [:off, :prefer]) do
      affinity_weight = router_affinity_weight(map, affinity)

      with {:ok, affinity_weight} <- affinity_weight,
           {:ok, classifiers} <- fetch_atom_list(map, "classifiers", []),
           {:ok, capture} <- capture(map),
           {:ok, cache} <- router_cache(map),
           {:ok, embedding} <- router_embedding(map) do
        {:ok,
         %{
           llm: llm,
           llm_timeout_ms: llm_timeout_ms,
           llm_warm_cache: llm_warm_cache,
           max_failovers: max_failovers,
           max_in_flight: max_in_flight,
           fallback_strategy: fallback_strategy,
           regex_match_limit: regex_match_limit,
           allow_general: allow_general,
           allow_unverified: allow_unverified,
           affinity: affinity,
           affinity_weight: affinity_weight,
           classifiers: classifiers,
           capture: capture,
           cache: cache,
           embedding: embedding
         }}
      end
    end
  end

  defp capture(map) do
    with {:ok, sub} <- section(map, "capture", :capture, %{}),
         {:ok, enabled} <- fetch_bool(sub, "enabled", false),
         {:ok, max_entries} <- fetch_int(sub, "max_entries", 10_000) do
      {:ok, %{enabled: enabled, max_entries: max_entries}}
    end
  end

  defp router_cache(map) do
    with {:ok, sub} <- section(map, "cache", :cache, %{}),
         {:ok, enabled} <- fetch_bool(sub, "enabled", true),
         {:ok, ttl_seconds} <- fetch_int(sub, "ttl_seconds", 300),
         {:ok, max_entries} <- fetch_int(sub, "max_entries", 10_000) do
      {:ok, %{enabled: enabled, ttl_seconds: ttl_seconds, max_entries: max_entries}}
    end
  end

  defp router_embedding(map) do
    with {:ok, sub} <- section(map, "embedding", :embedding, %{}),
         {:ok, min_similarity} <- fetch_float(sub, "min_similarity", 0.0) do
      {:ok, %{min_similarity: min_similarity}}
    end
  end

  defp refusal(raw) do
    with {:ok, map} <- section(raw, "refusal", :refusal, %{}),
         {:ok, policy} <- fetch_enum(map, "policy", "wait", @refusal_policies),
         {:ok, wait_ms} <- fetch_int(map, "wait_ms", 10_000) do
      {:ok, %{policy: policy, wait_ms: wait_ms}}
    end
  end

  defp retry(raw) do
    with {:ok, map} <- section(raw, "retry", :retry, %{}),
         {:ok, max_attempts} <- fetch_int(map, "max_attempts", 3),
         {:ok, base_ms} <- fetch_int(map, "base_ms", 200),
         {:ok, cap_ms} <- fetch_int(map, "cap_ms", 5000),
         {:ok, attempt_timeout_ms} <- fetch_int(map, "attempt_timeout_ms", 60_000) do
      {:ok, %{max_attempts: max_attempts, base_ms: base_ms, cap_ms: cap_ms, attempt_timeout_ms: attempt_timeout_ms}}
    end
  end

  defp circuit_breaker(raw) do
    with {:ok, map} <- section(raw, "circuit_breaker", :circuit_breaker, %{}),
         {:ok, failure_rate_threshold} <- fetch_float(map, "failure_rate_threshold", 0.5),
         {:ok, min_calls} <- fetch_int(map, "min_calls", 10),
         {:ok, open_duration_ms} <- fetch_int(map, "open_duration_ms", 30_000),
         {:ok, half_open_probes} <- fetch_int(map, "half_open_probes", 1) do
      {:ok,
       %{
         failure_rate_threshold: failure_rate_threshold,
         min_calls: min_calls,
         open_duration_ms: open_duration_ms,
         half_open_probes: half_open_probes
       }}
    end
  end

  defp engine(raw) do
    with {:ok, map} <- section(raw, "engine", :engine, %{}),
         {:ok, start_timeout_ms} <- fetch_int(map, "start_timeout_ms", 120_000),
         {:ok, idle_unload_seconds} <- fetch_int(map, "idle_unload_seconds", 600),
         {:ok, vram_margin_mib} <- fetch_int(map, "vram_margin_mib", 1024),
         {:ok, port_range} <- port_range(map),
         {:ok, log_lines} <- fetch_int(map, "log_lines", 2000),
         {:ok, max_restarts} <- fetch_int(map, "max_restarts", 3),
         {:ok, shutdown_timeout_ms} <- fetch_int(map, "shutdown_timeout_ms", 30_000) do
      {:ok,
       %{
         start_timeout_ms: start_timeout_ms,
         idle_unload_seconds: idle_unload_seconds,
         vram_margin_mib: vram_margin_mib,
         port_range: port_range,
         log_lines: log_lines,
         max_restarts: max_restarts,
         shutdown_timeout_ms: shutdown_timeout_ms
       }}
    end
  end

  defp port_range(map) do
    case fetch(map, "port_range", [39_000, 39_999]) do
      [low, high] when is_integer(low) and is_integer(high) and low > 0 and high >= low ->
        {:ok, {low, high}}

      value ->
        {:error, type_error("port_range", "par [min, max]", value)}
    end
  end

  defp devices(raw) do
    with {:ok, map} <- section(raw, "devices", :devices, %{}),
         {:ok, foreign_resync_threshold_mib} <- fetch_int(map, "foreign_resync_threshold_mib", 64),
         {:ok, total_tolerance_mib} <- fetch_int(map, "total_tolerance_mib", 256),
         {:ok, map_list} <- device_map_list(map) do
      {:ok,
       %{
         foreign_resync_threshold_mib: foreign_resync_threshold_mib,
         total_tolerance_mib: total_tolerance_mib,
         map: map_list
       }}
    end
  end

  defp device_map_list(map) do
    case fetch(map, "map", []) do
      [] ->
        {:ok, []}

      list when is_list(list) ->
        parse_list(list, &device_map/1)

      value ->
        {:error, type_error("devices.map", "lista de tablas", value)}
    end
  end

  defp device_map(entry) when is_map(entry) do
    with {:ok, physical_id} <- fetch_string(entry, "physical_id", nil),
         {:ok, kind} <- fetch_enum(entry, "kind", "discrete", @kinds),
         {:ok, max_mib} <- optional_positive_int(entry, "max_mib"),
         {:ok, reserve_mib} <- optional_positive_int(entry, "reserve_mib"),
         {:ok, backend_names} <- backend_names(entry) do
      if kind == :unified and (is_nil(max_mib) or is_nil(reserve_mib)) do
        {:error,
         Error.new(:config_error, "un device unified exige max_mib y reserve_mib", details: %{physical_id: physical_id})}
      else
        {:ok,
         %{
           physical_id: physical_id,
           kind: kind,
           max_mib: max_mib,
           reserve_mib: reserve_mib,
           backend_names: backend_names
         }}
      end
    end
  end

  defp device_map(_other) do
    {:error, Error.new(:config_error, "cada entrada de [[devices.map]] debe ser una tabla")}
  end

  defp optional_positive_int(map, key) do
    case fetch(map, key, nil) do
      nil ->
        {:ok, nil}

      value when is_integer(value) and value > 0 ->
        {:ok, value}

      value ->
        {:error, type_error(key, "entero mayor que 0", value)}
    end
  end

  defp backend_names(entry) do
    case fetch(entry, "backend_names", %{}) do
      map when is_map(map) -> {:ok, map}
      value -> {:error, type_error("backend_names", "tabla", value)}
    end
  end

  defp commands(raw) do
    with {:ok, map} <- section(raw, "commands", :commands, %{}),
         {:ok, allow} <- command_allow(map),
         {:ok, env_allow} <- fetch_ok(map, "env_allow", ["PATH"]) do
      {:ok, %{allow: allow, env_allow: env_allow}}
    end
  end

  defp command_allow(map) do
    case fetch(map, "allow", []) do
      [] ->
        {:ok, []}

      list when is_list(list) ->
        parse_list(list, &command/1)

      value ->
        {:error, type_error("commands.allow", "lista de tablas", value)}
    end
  end

  defp command(entry) when is_map(entry) do
    with {:ok, name} <- fetch_string(entry, "name", nil),
         {:ok, path} <- fetch_string(entry, "path", nil),
         {:ok, sha256} <- fetch_string(entry, "sha256", nil) do
      {:ok, %{name: name, path: path, sha256: sha256}}
    end
  end

  defp command(_other) do
    {:error, Error.new(:config_error, "cada entrada de [commands].allow debe ser una tabla")}
  end

  defp engines(raw) do
    case fetch(raw, "engines", []) do
      [] ->
        {:ok, []}

      list when is_list(list) ->
        parse_list(list, &engine_profile/1)

      value ->
        {:error, type_error("engines", "lista de tablas", value)}
    end
  end

  defp engine_profile(entry) when is_map(entry) do
    with {:ok, id} <- fetch_string(entry, "id", nil),
         {:ok, command_name} <- fetch_string(entry, "command", nil),
         {:ok, backend} <- fetch_enum(entry, "backend", "cpu", @backends),
         {:ok, env} <- engine_env(entry),
         {:ok, allowed_extra_args} <- fetch_ok(entry, "allowed_extra_args", []),
         {:ok, min_build} <- fetch_int(entry, "min_build", 0) do
      {:ok,
       %{
         id: id,
         command: command_name,
         backend: backend,
         env: env,
         allowed_extra_args: allowed_extra_args,
         min_build: min_build
       }}
    end
  end

  defp engine_profile(_other) do
    {:error, Error.new(:config_error, "cada entrada de [[engines]] debe ser una tabla")}
  end

  defp engine_env(entry) do
    case fetch(entry, "env", %{}) do
      map when is_map(map) -> {:ok, map}
      value -> {:error, type_error("env", "tabla", value)}
    end
  end

  defp models(raw) do
    case fetch(raw, "models", []) do
      [] ->
        {:ok, []}

      list when is_list(list) ->
        parse_list(list, &model/1)

      value ->
        {:error, type_error("models", "lista de tablas", value)}
    end
  end

  defp model(entry) when is_map(entry) do
    with {:ok, alias_name} <- fetch_string(entry, "alias", nil),
         {:ok, provider} <- fetch_string(entry, "provider", nil),
         {:ok, model_id} <- fetch_string(entry, "model_id", ""),
         {:ok, locality} <- fetch_enum(entry, "locality", "local", @localities),
         {:ok, node} <- fetch_string(entry, "node", nil),
         {:ok, engine_id} <- fetch_string(entry, "engine", nil),
         {:ok, path} <- fetch_string(entry, "path", nil),
         {:ok, capabilities} <- fetch_capabilities(entry),
         {:ok, modalities} <- fetch_modalities(entry),
         {:ok, context_window} <- fetch_int(entry, "context_window", 4096),
         {:ok, ctx_size} <- fetch_int(entry, "ctx_size", context_window),
         {:ok, max_output_tokens} <- fetch_int(entry, "max_output_tokens", 2048),
         {:ok, max_concurrency} <- fetch_int(entry, "max_concurrency", 1),
         {:ok, vram_mb} <- fetch_int(entry, "vram_mb", 0),
         {:ok, compute_buffer_mib} <- optional_positive_int(entry, "compute_buffer_mib"),
         {:ok, fit} <- fetch_enum(entry, "fit", "auto", @fits),
         {:ok, kv_type_k} <- fetch_string(entry, "kv_type_k", "f16"),
         {:ok, kv_type_v} <- fetch_string(entry, "kv_type_v", "f16"),
         {:ok, resident} <- fetch_bool(entry, "resident", false),
         {:ok, exclusive} <- fetch_bool(entry, "exclusive", false),
         {:ok, tags} <- fetch_atom_list(entry, "tags", []),
         {:ok, pricing} <- pricing(entry),
         {:ok, max_attachment_bytes} <- max_attachment_bytes(entry) do
      {:ok,
       %{
         alias: safe_atom(alias_name),
         provider: safe_atom(provider),
         model_id: model_id,
         locality: locality,
         node: node,
         engine: engine_id,
         path: path,
         capabilities: capabilities,
         modalities: modalities,
         context_window: context_window,
         ctx_size: ctx_size,
         max_output_tokens: max_output_tokens,
         max_concurrency: max_concurrency,
         vram_mb: vram_mb,
         compute_buffer_mib: compute_buffer_mib,
         fit: fit,
         kv_type_k: kv_type_k,
         kv_type_v: kv_type_v,
         resident: resident,
         exclusive: exclusive,
         tags: tags,
         pricing: pricing,
         max_attachment_bytes: max_attachment_bytes
       }}
    end
  end

  defp model(_other) do
    {:error, Error.new(:config_error, "cada entrada de [[models]] debe ser una tabla")}
  end

  # Las skills (capacidades) tienen taxonomia **cerrada** (D-02, ratificada en
  # r8 por Q-16). Una skill desconocida rompe la validacion en carga, no en
  # cada peticion: el router filtra por `opts.require` y por
  # `[[rules]].target.capability`.
  defp fetch_capabilities(entry) do
    case fetch(entry, "capabilities", []) do
      value when is_list(value) -> check_capabilities(value)
      value -> {:error, type_error("capabilities", "lista de cadenas", value)}
    end
  end

  # Las skills tienen taxonomia cerrada: una skill desconocida rompe la
  # validacion en carga, no en cada peticion.
  defp check_capabilities(value) do
    if Enum.all?(value, &is_binary/1) do
      atoms = Enum.map(value, &safe_atom/1)
      unknown = Enum.reject(atoms, &(&1 in @skills))

      if unknown == [] do
        {:ok, atoms}
      else
        {:error,
         Error.new(:config_error, "skill no admitida en [[models]].capabilities",
           details: %{unknown: unknown, allowed: @skills}
         )}
      end
    else
      {:error, type_error("capabilities", "lista de cadenas", value)}
    end
  end

  # Las modalidades admitidas son las de §5.1: `:text`, `:image`, `:audio` y
  # `:video`. Una modalidad desconocida es un error de carga, no un aviso:
  # el router filtra por modalidad en cada petición (SPEC §6.10).
  defp fetch_modalities(entry) do
    with {:ok, atoms} <- fetch_atom_list(entry, "modalities", [:text]) do
      unknown = Enum.reject(atoms, &(&1 in @modalities))

      if unknown == [] do
        {:ok, atoms}
      else
        {:error,
         Error.new(:config_error, "modalidad no admitida en [[models]]",
           details: %{unknown: unknown, allowed: @modalities}
         )}
      end
    end
  end

  defp pricing(entry) do
    case fetch(entry, "pricing", %{}) do
      map when is_map(map) ->
        with {:ok, input} <- fetch_int(map, "input_per_mtok_micros", 0),
             {:ok, output} <- fetch_int(map, "output_per_mtok_micros", 0) do
          {:ok, %{input_per_mtok_micros: input, output_per_mtok_micros: output}}
        end

      value ->
        {:error, type_error("pricing", "tabla", value)}
    end
  end

  defp max_attachment_bytes(entry) do
    case fetch(entry, "max_attachment_bytes", %{}) do
      map when is_map(map) ->
        with {:ok, image} <- fetch_int(map, "image", 20_971_520),
             {:ok, audio} <- fetch_int(map, "audio", 52_428_800) do
          check_attachment_bytes(image, audio)
        end

      value ->
        {:error, type_error("max_attachment_bytes", "tabla", value)}
    end
  end

  defp nodes(raw) do
    case fetch(raw, "nodes", []) do
      [] ->
        {:ok, []}

      list when is_list(list) ->
        parse_list(list, &node_profile/1)

      value ->
        {:error, type_error("nodes", "lista de tablas", value)}
    end
  end

  # Las secciones de seguridad son tablas: una clave desconocida es un error.
  # Se comprueba antes de interpretar el contenido.
  defp check_security_section!(raw, name) do
    case Map.get(raw, name) do
      nil ->
        :ok

      map when is_map(map) ->
        case unknown_keys(map, allowed(name)) do
          [] ->
            :ok

          unknown ->
            {:error,
             Error.new(:config_error, "clave desconocida en la seccion de seguridad [#{name}]",
               details: %{section: name, unknown: unknown}
             )}
        end

      _other ->
        :ok
    end
  end

  defp check_security_sections(raw) do
    Enum.reduce_while(@security_sections, :ok, fn name, :ok ->
      case check_security_section!(raw, name) do
        :ok -> {:cont, :ok}
        {:error, error} -> {:halt, {:error, error}}
      end
    end)
  end

  defp node_profile(entry) when is_map(entry) do
    with {:ok, id} <- fetch_string(entry, "id", nil),
         {:ok, url} <- fetch_string(entry, "url", nil),
         {:ok, pinned} <- fetch_ok(entry, "pinned_server_cert_sha256", []),
         {:ok, client_cert_file} <- fetch_string(entry, "client_cert_file", nil),
         {:ok, client_key_file} <- fetch_string(entry, "client_key_file", nil),
         {:ok, heartbeat_ms} <- fetch_int(entry, "heartbeat_ms", 5000),
         {:ok, heartbeat_miss_limit} <- fetch_int(entry, "heartbeat_miss_limit", 3),
         {:ok, lease_ttl_ms} <- fetch_int(entry, "lease_ttl_ms", 30_000),
         {:ok, max_inflight_control} <- fetch_int(entry, "max_inflight_control", 16),
         {:ok, control_timeout_ms} <- fetch_int(entry, "control_timeout_ms", 10_000) do
      case node_url_and_pins(id, url, pinned) do
        {:error, error} ->
          {:error, error}

        :ok ->
          {:ok,
           %{
             id: id,
             url: url,
             pinned_server_cert_sha256: pinned,
             client_cert_file: client_cert_file,
             client_key_file: client_key_file,
             heartbeat_ms: heartbeat_ms,
             heartbeat_miss_limit: heartbeat_miss_limit,
             lease_ttl_ms: lease_ttl_ms,
             max_inflight_control: max_inflight_control,
             control_timeout_ms: control_timeout_ms
           }}
      end
    end
  end

  defp node_profile(_other) do
    {:error, Error.new(:config_error, "cada entrada de [[nodes]] debe ser una tabla")}
  end

  defp node_url_and_pins(id, url, pinned) do
    cond do
      not String.starts_with?(url, "https://") ->
        {:error, Error.new(:config_error, "[[nodes]].url debe empezar por https://", details: %{id: id, url: url})}

      pinned == [] ->
        {:error, Error.new(:config_error, "[[nodes]].pinned_server_cert_sha256 es obligatorio", details: %{id: id})}

      true ->
        :ok
    end
  end

  defp placement(raw) do
    with {:ok, map} <- section(raw, "placement", :placement, %{}),
         {:ok, prefer} <- fetch_ok(map, "prefer", []),
         {:ok, max_loaded_models} <- fetch_int(map, "max_loaded_models", 0) do
      {:ok, %{prefer: prefer, max_loaded_models: max_loaded_models}}
    end
  end

  defp decision_models(raw) do
    case fetch(raw, "decision_models", []) do
      [] ->
        {:ok, []}

      list when is_list(list) ->
        parse_list(list, &decision_model/1)

      value ->
        {:error, type_error("decision_models", "lista de tablas", value)}
    end
  end

  defp decision_model(entry) when is_map(entry) do
    with {:ok, id} <- fetch_string(entry, "id", nil),
         {:ok, kind} <- fetch_enum(entry, "kind", nil, @decision_kinds),
         {:ok, model_alias} <- fetch_string(entry, "model", nil),
         {:ok, max_input_tokens} <- fetch_int(entry, "max_input_tokens", 2048),
         {:ok, max_output_tokens} <- fetch_int(entry, "max_output_tokens", 32),
         {:ok, resident} <- fetch_bool(entry, "resident", false),
         {:ok, require_eval} <- fetch_bool(entry, "require_eval", true),
         {:ok, eval} <- decision_eval(entry) do
      {:ok,
       %{
         id: safe_atom(id),
         kind: kind,
         model: safe_atom(model_alias),
         routes: Map.get(entry, "routes", %{}),
         max_input_tokens: max_input_tokens,
         max_output_tokens: max_output_tokens,
         resident: resident,
         require_eval: require_eval,
         eval: eval
       }}
    end
  end

  defp decision_model(_other) do
    {:error, Error.new(:config_error, "cada entrada de [[decision_models]] debe ser una tabla")}
  end

  defp decision_eval(entry) do
    case fetch(entry, "eval", %{}) do
      map when is_map(map) ->
        with {:ok, corpus} <- fetch_string(map, "corpus", nil),
             {:ok, adversarial} <- fetch_string(map, "adversarial_corpus", nil),
             {:ok, languages} <- fetch_ok(map, "required_languages", []),
             {:ok, confidence} <- fetch_float(map, "confidence", 0.95),
             {:ok, min_top1} <- optional_float(map, "min_top1_accuracy"),
             {:ok, max_p99} <- optional_positive_int(map, "max_p99_ms") do
          build_eval(corpus, adversarial, languages, confidence, min_top1, max_p99)
        end

      value ->
        {:error, type_error("eval", "tabla", value)}
    end
  end

  defp optional_float(map, key) do
    case fetch(map, key, nil) do
      nil -> {:ok, nil}
      value when is_float(value) -> {:ok, value}
      value when is_integer(value) -> {:ok, value * 1.0}
      value -> {:error, type_error(key, "float", value)}
    end
  end

  defp rules(raw) do
    case fetch(raw, "rules", []) do
      [] ->
        {:ok, []}

      list when is_list(list) ->
        parse_list(list, fn entry -> rule(entry, "rules") end)

      value ->
        {:error, type_error("rules", "lista de tablas", value)}
    end
  end

  defp rule(entry, section) when is_map(entry) do
    with {:ok, name} <- fetch_string(entry, "name", nil),
         {:ok, when_map} <- optional_map(entry, "when"),
         {:ok, action} <- fetch_enum(entry, "action", nil, @actions),
         {:ok, target} <- fetch_map(entry, "target"),
         {:ok, weight} <- optional_float(entry, "weight") do
      cond do
        is_nil(target) or map_size(target) == 0 ->
          {:error, Error.new(:config_error, "[[#{section}]].target es obligatorio", details: %{name: name})}

        not valid_target?(target) ->
          {:error,
           Error.new(:config_error, "[[#{section}]].target tiene una clave desconocida",
             details: %{name: name, target: target, allowed: @rule_targets}
           )}

        action == :prefer and is_nil(weight) ->
          {:error,
           Error.new(:config_error, "[[#{section}]].weight es obligatorio con action = \"prefer\"",
             details: %{name: name}
           )}

        action != :prefer and not is_nil(weight) ->
          {:error,
           Error.new(:config_error, "[[#{section}]].weight solo existe con action = \"prefer\"", details: %{name: name})}

        true ->
          {:ok, %{name: name, when: when_map, action: action, target: target, weight: weight}}
      end
    end
  end

  defp rule(_other, _section) do
    {:error, Error.new(:config_error, "cada entrada de [[rules]] debe ser una tabla")}
  end

  defp valid_target?(target) do
    Enum.all?(Map.keys(target), &(&1 in @rule_targets))
  end

  defp optional_map(entry, key) do
    case fetch(entry, key, nil) do
      nil -> {:ok, nil}
      map when is_map(map) -> {:ok, map}
      value -> {:error, type_error(key, "tabla", value)}
    end
  end

  defp fetch_map(entry, key) do
    case fetch(entry, key, nil) do
      nil -> {:ok, nil}
      map when is_map(map) -> {:ok, map}
      value -> {:error, type_error(key, "tabla", value)}
    end
  end

  defp providers(raw) do
    case fetch(raw, "providers", %{}) do
      map when is_map(map) ->
        parse_map(map, &provider/2)

      value ->
        {:error, type_error("providers", "tabla", value)}
    end
  end

  defp provider(_name, entry) when is_map(entry) do
    with {:ok, module} <- provider_module(entry),
         {:ok, mode} <- fetch_enum(entry, "mode", "managed_local", [:managed_local, :managed_node, :external]),
         {:ok, base_url} <- fetch_string(entry, "base_url", nil),
         {:ok, api_key_env} <- fetch_string(entry, "api_key_env", nil),
         {:ok, rpm} <- fetch_int(entry, "rpm", 0),
         {:ok, tpm} <- fetch_int(entry, "tpm", 0) do
      {:ok,
       %{
         module: module,
         mode: mode,
         base_url: base_url,
         api_key_env: api_key_env,
         rpm: rpm,
         tpm: tpm
       }}
    else
      {:error, %Error{} = error} -> {:error, error}
    end
  end

  defp provider(_name, _other) do
    {:error, Error.new(:config_error, "cada entrada de [providers.*] debe ser una tabla")}
  end

  defp provider_module(entry) do
    case fetch(entry, "module", nil) do
      nil ->
        {:error, Error.new(:config_error, "[providers.*].module es obligatorio", details: %{key: "module"})}

      value when is_binary(value) ->
        module = safe_module(value)
        {:ok, module}

      value ->
        {:error, type_error("module", "cadena", value)}
    end
  end

  # Un modulo puede no estar compilado todavia (config de un proyecto consumidor
  # que todavia no ha compilado). Se resuelve en tiempo de uso; aqui solo se
  # comprueba que el nombre tiene forma de modulo.
  defp safe_module(value) do
    Module.concat([value])
  rescue
    ArgumentError -> value
  end

  defp structured(raw) do
    with {:ok, map} <- section(raw, "structured", :structured, %{}),
         {:ok, mode} <- fetch_enum(map, "mode", "auto", @structured_modes),
         {:ok, max_retries} <- fetch_int(map, "max_retries", 2),
         {:ok, feedback_bytes} <- fetch_int(map, "feedback_bytes", 2048) do
      {:ok, %{mode: mode, max_retries: max_retries, feedback_bytes: feedback_bytes}}
    end
  end

  defp stream(raw) do
    with {:ok, map} <- section(raw, "stream", :stream, %{}),
         {:ok, pre} <- fetch_int(map, "pre_commit_buffer_chunks", 16),
         {:ok, max_buffered} <- fetch_int(map, "max_buffered_chunks", 64),
         {:ok, grace} <- fetch_int(map, "cancel_grace_ms", 1000) do
      {:ok, %{pre_commit_buffer_chunks: pre, max_buffered_chunks: max_buffered, cancel_grace_ms: grace}}
    end
  end

  defp context(raw) do
    with {:ok, map} <- section(raw, "context", :context, %{}),
         {:ok, max_prompt_tokens} <- fetch_int(map, "max_prompt_tokens", 0),
         {:ok, compaction} <- compaction(map),
         {:ok, summary_model} <- fetch_string(map, "summary_model", nil) do
      {:ok,
       %{
         max_prompt_tokens: max_prompt_tokens,
         compaction: compaction,
         summary_model: summary_model && safe_atom(summary_model)
       }}
    end
  end

  defp compaction(map) do
    case fetch(map, "compaction", "truncate") do
      value when is_binary(value) ->
        atom = safe_atom(value)

        if atom in @compaction_modes do
          {:ok, atom}
        else
          {:error,
           Error.new(:config_error, "[context].compaction debe ser uno de #{inspect(@compaction_modes)}",
             details: %{key: "compaction", value: value}
           )}
        end

      value ->
        {:error, type_error("compaction", "cadena", value)}
    end
  end

  defp sessions(raw) do
    with {:ok, map} <- section(raw, "sessions", :sessions, %{}),
         {:ok, max_sessions} <- fetch_int(map, "max_sessions", 1024),
         {:ok, idle_ttl} <- fetch_int(map, "idle_ttl_seconds", 3600),
         {:ok, max_turns} <- fetch_int(map, "max_turns_in_memory", 200),
         {:ok, store} <- fetch_enum(map, "store", "memory", [:memory, :disk]) do
      {:ok,
       %{
         max_sessions: max_sessions,
         idle_ttl_seconds: idle_ttl,
         max_turns_in_memory: max_turns,
         store: store
       }}
    end
  end

  defp memory(raw) do
    with {:ok, map} <- section(raw, "memory", :memory, %{}),
         {:ok, max_entries} <- fetch_int(map, "max_entries", 10_000) do
      {:ok, %{max_entries: max_entries}}
    end
  end

  defp selector(raw) do
    with {:ok, map} <- section(raw, "selector", :selector, %{}),
         {:ok, max_states} <- fetch_int(map, "max_states", 10_000),
         {:ok, aging_step_ms} <- fetch_int(map, "aging_step_ms", 1000) do
      {:ok, %{max_states: max_states, aging_step_ms: aging_step_ms}}
    end
  end

  defp consumers(raw) do
    case fetch(raw, "consumers", %{}) do
      map when is_map(map) ->
        parse_map(map, &consumer/2)

      value ->
        {:error, type_error("consumers", "tabla", value)}
    end
  end

  defp consumer(name, entry) when is_map(entry) do
    with {:ok, default_model} <- fetch_string(entry, "default_model", nil),
         {:ok, priority} <- fetch_int(entry, "priority", 0),
         {:ok, rules} <- consumer_rules(entry, name) do
      {:ok, %{default_model: safe_atom(default_model), priority: priority, rules: rules}}
    end
  end

  defp consumer(_name, _other) do
    {:error, Error.new(:config_error, "cada entrada de [consumers.*] debe ser una tabla")}
  end

  defp consumer_rules(entry, consumer_name) do
    case fetch(entry, "rules", []) do
      [] ->
        {:ok, []}

      list when is_list(list) ->
        parse_list(list, fn rule_entry -> rule(rule_entry, "consumers.#{consumer_name}.rules") end)

      value ->
        {:error, type_error("rules", "lista de tablas", value)}
    end
  end

  defp cache(raw) do
    with {:ok, map} <- section(raw, "cache", :cache, %{}),
         {:ok, sweep_interval_ms} <- fetch_int(map, "sweep_interval_ms", 30_000) do
      {:ok, %{sweep_interval_ms: sweep_interval_ms}}
    end
  end

  defp tools(raw) do
    with {:ok, map} <- section(raw, "tools", :tools, %{}),
         {:ok, max_result_bytes} <- fetch_int(map, "max_result_bytes", 65_536),
         {:ok, truncate_passes} <- fetch_int(map, "truncate_passes", 32),
         {:ok, max_parallel} <- fetch_int(map, "max_parallel", 4),
         {:ok, max_schema_bytes} <- fetch_int(map, "max_schema_bytes", 16_384),
         {:ok, max_description_bytes} <- fetch_int(map, "max_description_bytes", 2048),
         {:ok, default_local} <-
           fetch_enum(map, "default_permission_local", "auto", @permissions),
         {:ok, default_mcp} <- fetch_enum(map, "default_permission_mcp", "confirm", @permissions),
         {:ok, auto_approve} <- fetch_ok(map, "auto_approve", []),
         {:ok, permissions} <- tool_permissions(map) do
      {:ok,
       %{
         max_result_bytes: max_result_bytes,
         truncate_passes: truncate_passes,
         max_parallel: max_parallel,
         max_schema_bytes: max_schema_bytes,
         max_description_bytes: max_description_bytes,
         default_permission_local: default_local,
         default_permission_mcp: default_mcp,
         auto_approve: auto_approve,
         permissions: permissions
       }}
    end
  end

  defp tool_permissions(map) do
    case fetch(map, "permissions", []) do
      [] ->
        {:ok, []}

      list when is_list(list) ->
        parse_list(list, &tool_permission/1)

      value ->
        {:error, type_error("permissions", "lista de tablas", value)}
    end
  end

  defp mcp(raw) do
    with {:ok, map} <- section(raw, "mcp", :mcp, %{}),
         {:ok, compat} <- fetch_bool(map, "compat_2025_11_25", false),
         {:ok, max_sessions} <- fetch_int(map, "max_sessions", 256),
         {:ok, session_ttl} <- fetch_int(map, "session_ttl_seconds", 900),
         {:ok, max_message_bytes} <- fetch_int(map, "max_message_bytes", 4_194_304),
         {:ok, rpc_timeout_ms} <- fetch_int(map, "rpc_timeout_ms", 30_000),
         {:ok, ping_interval_ms} <- fetch_int(map, "ping_interval_ms", 60_000),
         {:ok, reconnect_attempts} <- fetch_int(map, "reconnect_attempts", 5) do
      {:ok,
       %{
         compat_2025_11_25: compat,
         max_sessions: max_sessions,
         session_ttl_seconds: session_ttl,
         max_message_bytes: max_message_bytes,
         rpc_timeout_ms: rpc_timeout_ms,
         ping_interval_ms: ping_interval_ms,
         reconnect_attempts: reconnect_attempts
       }}
    end
  end

  defp mcp_clients(raw) do
    case Map.get(fetch(raw, "mcp", %{}), "clients", []) do
      [] ->
        {:ok, []}

      list when is_list(list) ->
        parse_list(list, &mcp_client/1)

      value ->
        {:error, type_error("mcp.clients", "lista de tablas", value)}
    end
  end

  defp mcp_client(entry) when is_map(entry) do
    with {:ok, id} <- fetch_string(entry, "id", nil),
         {:ok, transport} <- fetch_enum(entry, "transport", nil, [:stdio, :http]),
         {:ok, command_name} <- fetch_string(entry, "command", nil),
         {:ok, args} <- fetch_ok(entry, "args", []),
         {:ok, url} <- fetch_string(entry, "url", nil),
         {:ok, allow_private} <- fetch_bool(entry, "allow_private", false) do
      cond do
        transport == :stdio and (is_nil(command_name) or not is_nil(url)) ->
          {:error,
           Error.new(:config_error, "un cliente MCP stdio exige command y no url",
             details: %{id: id, transport: transport}
           )}

        transport == :http and (is_nil(url) or not is_nil(command_name)) ->
          {:error,
           Error.new(:config_error, "un cliente MCP http exige url y no command",
             details: %{id: id, transport: transport}
           )}

        true ->
          {:ok,
           %{
             id: id,
             transport: transport,
             command: command_name,
             args: args,
             url: url,
             allow_private: allow_private
           }}
      end
    end
  end

  defp mcp_client(_other) do
    {:error, Error.new(:config_error, "cada entrada de [[mcp.clients]] debe ser una tabla")}
  end

  defp agents(raw) do
    with {:ok, map} <- section(raw, "agents", :agents, %{}),
         {:ok, max_agents} <- fetch_int(map, "max_agents", 64),
         {:ok, max_depth} <- fetch_int(map, "max_depth", 3),
         {:ok, confirm_timeout_ms} <- fetch_int(map, "confirm_timeout_ms", 3_600_000) do
      {:ok, %{max_agents: max_agents, max_depth: max_depth, confirm_timeout_ms: confirm_timeout_ms}}
    end
  end

  defp rag(raw) do
    with {:ok, map} <- section(raw, "rag", :rag, %{}),
         {:ok, max_document_bytes} <- fetch_int(map, "max_document_bytes", 10_485_760),
         {:ok, max_chunks} <- fetch_int(map, "max_chunks_per_document", 5000),
         {:ok, rrf_k} <- fetch_int(map, "rrf_k", 60),
         {:ok, strategy} <- fetch_enum(map, "strategy", "hybrid", @strategies),
         {:ok, tool_enabled} <- fetch_bool(map, "tool_enabled", true),
         {:ok, store} <- fetch_enum(map, "store", "sqlite", @stores),
         {:ok, store_backend} <- fetch_enum(map, "store_backend", "separate", @store_backends),
         {:ok, sqlite} <- rag_sqlite(map),
         {:ok, store} <- derive_sqlite_path(sqlite, store, raw),
         {:ok, sqlite} <- derive_sqlite_path_value(sqlite, store, raw) do
      {:ok,
       %{
         max_document_bytes: max_document_bytes,
         max_chunks_per_document: max_chunks,
         rrf_k: rrf_k,
         strategy: strategy,
         tool_enabled: tool_enabled,
         store: store,
         store_backend: store_backend,
         sqlite: sqlite
       }}
    end
  end

  defp rag_sqlite(map) do
    case fetch(map, "sqlite", %{}) do
      sub when is_map(sub) ->
        {:ok, %{path: fetch(sub, "path", nil)}}

      value ->
        {:error, type_error("rag.sqlite", "tabla", value)}
    end
  end

  # El path del store SQLite se deriva de `state_dir` cuando el operador no
  # lo escribe. El ejemplo del SPEC usa `/var/lib/gunther/rag.db` con
  # `state_dir = "/var/lib/gunther"`: la derivacion reproduce ese resultado.
  #
  # Si no hay `state_dir`, el store efectivo pasa a `memory` con un aviso: un
  # campo que nada puede rellenar y que la validacion exige es un deadlock,
  # no un bug.
  #
  # El path derivado se escribe en la config, para que el resto del codigo
  # no tenga que saber como se resolvio.
  defp derive_sqlite_path_value(sqlite, store, raw) do
    if store == :sqlite and is_nil(sqlite.path) do
      case get_in(raw, ["gunther", "state_dir"]) do
        state_dir when is_binary(state_dir) ->
          {:ok, %{sqlite | path: Path.join(state_dir, "rag.db")}}

        _other ->
          {:ok, sqlite}
      end
    else
      {:ok, sqlite}
    end
  end

  # Devuelve `{:ok, store_efectivo}` o `{:error, ...}`.
  #
  # Distingue dos casos:
  #
  # - El operador puso `store = "sqlite"` **de forma explicita**: si no hay
  #   path ni `state_dir`, es `config_error` (§14.2).
  # - `sqlite` es solo el **defecto**: sin `state_dir`, el store efectivo pasa
  #   a `memory` con un aviso y la configuracion minima sigue siendo valida.
  #   Un campo que nada puede rellenar y que la validacion exige es un
  #   deadlock, no un bug.
  defp derive_sqlite_path(sqlite, store, raw) do
    if store == :sqlite and is_nil(sqlite.path) do
      explicit? = Map.has_key?(Map.get(raw, "rag", %{}), "store")

      case get_in(raw, ["gunther", "state_dir"]) do
        state_dir when is_binary(state_dir) ->
          {:ok, store}

        _other when explicit? ->
          {:error, Error.new(:config_error, "rag.store = \"sqlite\" exige rag.sqlite.path", details: %{store: :sqlite})}

        _other ->
          require Logger

          Logger.warning(
            "Gunther: [rag].store es \"sqlite\" pero no hay [rag].sqlite.path ni [gunther].state_dir. " <>
              "El store efectivo pasa a \"memory\"."
          )

          {:ok, :memory}
      end
    else
      {:ok, store}
    end
  end

  defp embedders(raw) do
    case fetch(raw, "embedders", %{}) do
      map when is_map(map) ->
        parse_map(map, &embedder/2)

      value ->
        {:error, type_error("embedders", "tabla", value)}
    end
  end

  defp embedder(_name, entry) when is_map(entry) do
    with {:ok, module} <- provider_module(entry),
         {:ok, min_score} <- fetch_float(entry, "min_score", 0.0) do
      {:ok, %{module: module, min_score: min_score}}
    end
  end

  defp embedder(_name, _other) do
    {:error, Error.new(:config_error, "cada entrada de [embedders.*] debe ser una tabla")}
  end

  defp guardrails(raw) do
    with {:ok, map} <- section(raw, "guardrails", :guardrails, %{}),
         {:ok, timeout_ms} <- fetch_int(map, "timeout_ms", 2000),
         {:ok, on_error} <- fetch_enum(map, "on_error", "closed", [:closed, :open]),
         {:ok, pre_send} <- fetch_bool(map, "pre_send", false),
         {:ok, stream_mode} <- fetch_enum(map, "stream_mode", "buffered", [:buffered, :post_hoc]) do
      {:ok,
       %{
         timeout_ms: timeout_ms,
         on_error: on_error,
         pre_send: pre_send,
         stream_mode: stream_mode
       }}
    end
  end

  defp budget(raw) do
    with {:ok, map} <- section(raw, "budget", :budget, %{}),
         {:ok, max_cost_per_request} <- fetch_int(map, "max_cost_per_request", 0) do
      {:ok, %{max_cost_per_request: max_cost_per_request}}
    end
  end

  defp gateway(raw) do
    with {:ok, map} <- section(raw, "gateway", :gateway, %{}),
         {:ok, max_body_bytes} <- fetch_int(map, "max_body_bytes", 1_048_576),
         {:ok, max_headers_bytes} <- fetch_int(map, "max_headers_bytes", 16_384),
         {:ok, max_connections} <- fetch_int(map, "max_connections", 1024),
         {:ok, max_attachment_body_bytes} <- optional_positive_int(map, "max_attachment_body_bytes"),
         {:ok, request_timeout_ms} <- fetch_int(map, "request_timeout_ms", 120_000),
         {:ok, allow_plaintext_remote} <- fetch_bool(map, "allow_plaintext_remote", false) do
      {:ok,
       %{
         max_body_bytes: max_body_bytes,
         max_headers_bytes: max_headers_bytes,
         max_connections: max_connections,
         max_attachment_body_bytes: max_attachment_body_bytes,
         request_timeout_ms: request_timeout_ms,
         allow_plaintext_remote: allow_plaintext_remote
       }}
    end
  end

  defp security(raw) do
    with {:ok, map} <- section(raw, "security", :security, %{}),
         {:ok, persist_hmac_key_env} <- fetch_string(map, "persist_hmac_key_env", ""),
         {:ok, persist_encrypt} <- fetch_bool(map, "persist_encrypt", false) do
      {:ok, %{persist_hmac_key_env: persist_hmac_key_env, persist_encrypt: persist_encrypt}}
    end
  end

  defp telemetry(raw) do
    with {:ok, map} <- section(raw, "telemetry", :telemetry, %{}),
         {:ok, prefix} <- fetch_atom_list(map, "prefix", [:gunther]) do
      {:ok, %{prefix: prefix}}
    end
  end

  # --- allowed keys por seccion ---

  defp allowed("gunther"), do: ["instance_id", "state_dir", "dotenv"]

  defp allowed("router"),
    do: [
      "llm",
      "llm_timeout_ms",
      "llm_warm_cache",
      "max_failovers",
      "max_in_flight",
      "fallback_strategy",
      "regex_match_limit",
      "allow_general",
      "allow_unverified",
      "affinity",
      "affinity_weight",
      "classifiers",
      "capture",
      "cache",
      "embedding"
    ]

  defp allowed("capture"), do: ["enabled", "max_entries"]
  defp allowed("cache"), do: ["enabled", "ttl_seconds", "max_entries", "sweep_interval_ms"]
  defp allowed("embedding"), do: ["min_similarity"]
  defp allowed("refusal"), do: ["policy", "wait_ms"]
  defp allowed("retry"), do: ["max_attempts", "base_ms", "cap_ms", "attempt_timeout_ms"]
  defp allowed("circuit_breaker"), do: ["failure_rate_threshold", "min_calls", "open_duration_ms", "half_open_probes"]

  defp allowed("engine"),
    do: [
      "start_timeout_ms",
      "idle_unload_seconds",
      "vram_margin_mib",
      "port_range",
      "log_lines",
      "max_restarts",
      "shutdown_timeout_ms"
    ]

  defp allowed("devices"), do: ["foreign_resync_threshold_mib", "total_tolerance_mib", "map", "overhead_mib"]
  defp allowed("commands"), do: ["allow", "env_allow"]
  defp allowed("structured"), do: ["mode", "max_retries", "feedback_bytes"]
  defp allowed("stream"), do: ["pre_commit_buffer_chunks", "max_buffered_chunks", "cancel_grace_ms"]
  defp allowed("context"), do: ["max_prompt_tokens", "compaction", "summary_model", "switch"]
  defp allowed("sessions"), do: ["max_sessions", "idle_ttl_seconds", "max_turns_in_memory", "store"]
  defp allowed("memory"), do: ["max_entries"]
  defp allowed("selector"), do: ["max_states", "aging_step_ms"]

  defp allowed("tools"),
    do: [
      "max_result_bytes",
      "truncate_passes",
      "max_parallel",
      "max_schema_bytes",
      "max_description_bytes",
      "default_permission_local",
      "default_permission_mcp",
      "auto_approve",
      "permissions"
    ]

  defp allowed("mcp"),
    do: [
      "compat_2025_11_25",
      "max_sessions",
      "session_ttl_seconds",
      "max_message_bytes",
      "rpc_timeout_ms",
      "ping_interval_ms",
      "reconnect_attempts",
      "clients"
    ]

  defp allowed("agents"), do: ["max_agents", "max_depth", "confirm_timeout_ms"]

  defp allowed("rag"),
    do: [
      "max_document_bytes",
      "max_chunks_per_document",
      "rrf_k",
      "strategy",
      "tool_enabled",
      "store",
      "store_backend",
      "sqlite"
    ]

  defp allowed("guardrails"), do: ["timeout_ms", "on_error", "pre_send", "stream_mode"]
  defp allowed("budget"), do: ["max_cost_per_request"]

  defp allowed("gateway"),
    do: [
      "max_body_bytes",
      "max_headers_bytes",
      "max_connections",
      "max_attachment_body_bytes",
      "request_timeout_ms",
      "allow_plaintext_remote"
    ]

  defp allowed("security"), do: ["persist_hmac_key_env", "persist_encrypt"]
  defp allowed("telemetry"), do: ["prefix"]
  defp allowed("placement"), do: ["prefer", "max_loaded_models"]
  defp allowed(_section), do: []

  # --- validaciones cruzadas (§14.2) ---

  defp cross_validate(config) do
    checks = [
      &check_decision_model_timeouts/1,
      &check_consumers_default_model/1,
      &check_rule_names_unique/1,
      &check_consumer_veto_own_default/1,
      &check_rag_store/1,
      &check_attachment_limits/1,
      &check_engine_commands_allowed/1,
      &check_model_concurrency/1,
      &check_model_node_no_path/1,
      &check_guardrails_stream_mode/1
    ]

    Enum.reduce_while(checks, :ok, fn check, :ok ->
      case check.(config) do
        :ok -> {:cont, :ok}
        {:error, error} -> {:halt, {:error, error}}
      end
    end)
  end

  # decision_models.*.eval.max_p99_ms <= router.llm_timeout_ms
  defp check_decision_model_timeouts(config) do
    limit = config.router.llm_timeout_ms

    Enum.reduce_while(config.decision_models, :ok, fn spec, :ok ->
      case spec.eval.max_p99_ms do
        nil ->
          {:cont, :ok}

        value when value > limit ->
          {:halt,
           {:error,
            Error.new(:config_error, "decision_models.eval.max_p99_ms no puede superar router.llm_timeout_ms",
              details: %{id: spec.id, max_p99_ms: value, llm_timeout_ms: limit}
            )}}

        _other ->
          {:cont, :ok}
      end
    end)
  end

  # consumers.*.default_model presente y alias existente del catalogo
  defp check_consumers_default_model(config) do
    aliases = Enum.map(config.models, & &1.alias)

    Enum.reduce_while(config.consumers, :ok, fn {name, consumer}, :ok ->
      cond do
        is_nil(consumer.default_model) ->
          {:halt,
           {:error, Error.new(:config_error, "consumers.*.default_model es obligatorio", details: %{consumer: name})}}

        consumer.default_model not in aliases ->
          {:halt,
           {:error,
            Error.new(:config_error, "consumers.*.default_model no es un alias del catalogo",
              details: %{consumer: name, default_model: consumer.default_model}
            )}}

        true ->
          {:cont, :ok}
      end
    end)
  end

  # Nombres de regla unicos en el espacio combinado (M-01, CE-34)
  defp check_rule_names_unique(config) do
    global_names = Enum.map(config.rules, & &1.name)

    duplicates =
      Enum.flat_map(config.consumers, fn {consumer, data} ->
        data.rules
        |> Enum.filter(&(&1.name in global_names))
        |> Enum.map(&{consumer, &1.name})
      end)

    case duplicates do
      [] ->
        :ok

      list ->
        {:error,
         Error.new(:config_error, "el nombre de una regla debe ser unico en el espacio combinado",
           details: %{duplicates: list}
         )}
    end
  end

  # Una regla de consumer con veto incondicional que casa con su default_model
  # es config_error (§6.8.1, §14.2).
  defp check_consumer_veto_own_default(config) do
    Enum.reduce_while(config.consumers, :ok, fn {name, consumer}, :ok ->
      default = Enum.find(config.models, &(&1.alias == consumer.default_model))

      offending =
        Enum.find(consumer.rules, fn rule ->
          rule.action == :veto and is_nil(rule.when) and target_matches?(rule.target, default)
        end)

      case offending do
        nil ->
          {:cont, :ok}

        rule ->
          {:halt,
           {:error,
            Error.new(
              :config_error,
              "una regla de veto incondicional del consumer no puede vetar su propio default_model",
              details: %{consumer: name, rule: rule.name, default_model: consumer.default_model}
            )}}
      end
    end)
  end

  defp target_matches?(_target, nil), do: false

  defp target_matches?(target, model) do
    Enum.all?(target, fn
      {"models", models} -> model.alias in Enum.map(models, &safe_atom/1)
      {"locality", locality} -> model.locality == safe_atom(locality)
      {"provider", provider} -> model.provider == safe_atom(provider)
      {"node", node} -> to_string(model.node) == to_string(node)
      {"capability", capability} -> safe_atom(capability) in model.capabilities
      {"tags", tags} -> Enum.all?(Enum.map(tags, &safe_atom/1), &(&1 in model.tags))
      _other -> false
    end)
  end

  # `rag.store = "sqlite"` exige `rag.sqlite.path` (§14.2).
  #
  # El path puede derivarse de `state_dir` (el ejemplo del SPEC usa
  # `/var/lib/gunther/rag.db` con `state_dir = "/var/lib/gunther"`). Si el
  # operador elige `sqlite` de forma explicita y no hay path ni `state_dir`,
  # es un `config_error`: no hay donde persistir.
  #
  # Si `sqlite` es solo el DEFECTO y no hay `state_dir`, el store efectivo
  # pasa a `memory` con un aviso: exigir un path que nada puede rellenar
  # haria invalida cualquier configuracion minima (un campo que nada puede
  # rellenar y que la validacion exige es un deadlock, no un bug).
  defp check_rag_store(config) do
    cond do
      config.rag.store_backend == :shared ->
        {:error,
         Error.new(:config_error, "shared requiere MemoryStore persistente, que llega en v1.1",
           details: %{store_backend: :shared}
         )}

      config.rag.store == :sqlite and is_nil(config.rag.sqlite.path) ->
        # El store efectivo ya ha pasado a `memory` en `derive_sqlite_path/3`
        # cuando no habia `state_dir`. Aqui solo queda el caso explicito:
        # el operador puso `store = "sqlite"` y no hay donde persistir.
        if config.gunther.state_dir do
          {:ok, config}
        else
          {:error, Error.new(:config_error, "rag.store = \"sqlite\" exige rag.sqlite.path", details: %{store: :sqlite})}
        end

      true ->
        :ok
    end
  end

  defp check_attachment_limits(config) do
    Enum.reduce_while(config.models, :ok, fn model, :ok ->
      if model.max_attachment_bytes.image > 0 and model.max_attachment_bytes.audio > 0 do
        {:cont, :ok}
      else
        {:halt,
         {:error,
          Error.new(:config_error, "max_attachment_bytes.image y .audio deben ser mayores que 0",
            details: %{alias: model.alias}
          )}}
      end
    end)
  end

  # Cada command de [[engines]] figura en commands.allow
  defp check_engine_commands_allowed(config) do
    allowed_names = Enum.map(config.commands.allow, & &1.name)

    Enum.reduce_while(config.engines, :ok, fn engine, :ok ->
      if engine.command in allowed_names do
        {:cont, :ok}
      else
        {:halt,
         {:error,
          Error.new(:config_error, "el command de un engine no figura en commands.allow",
            details: %{engine: engine.id, command: engine.command}
          )}}
      end
    end)
  end

  defp check_model_concurrency(config) do
    Enum.reduce_while(config.models, :ok, fn model, :ok ->
      if model.max_concurrency >= 1 do
        {:cont, :ok}
      else
        {:halt,
         {:error,
          Error.new(:config_error, "max_concurrency de un modelo debe ser >= 1",
            details: %{alias: model.alias, max_concurrency: model.max_concurrency}
          )}}
      end
    end)
  end

  defp check_model_node_no_path(config) do
    Enum.reduce_while(config.models, :ok, fn model, :ok ->
      if is_nil(model.node) or is_nil(model.path) do
        {:cont, :ok}
      else
        {:halt, {:error, Error.new(:config_error, "un modelo con node no lleva path", details: %{alias: model.alias})}}
      end
    end)
  end

  # stream_mode obligatorio si hay guardrails de output. En v1 no se puede
  # saber si hay guardrails de output sin arrancar, asi que se exige siempre
  # el valor explicito cuando la seccion esta presente.
  defp check_guardrails_stream_mode(config) do
    if is_nil(config.guardrails.stream_mode) do
      {:error, Error.new(:config_error, "guardrails.stream_mode es obligatorio si hay guardrails de output")}
    else
      :ok
    end
  end
end
