defmodule Gunther.Config do
  @moduledoc """
  La configuración de Gunther (SPEC §14).

  El TOML se carga, se valida y se convierte en esta estructura. Los defectos
  viven en los módulos de configuración (SPEC §0.3, D-72: el código no
  contiene nombres de modelos; lo que depende de un modelo es configuración).

  ## Defecto

  "Defecto" es el valor que se usa si falta la clave. "Obligatorio" significa
  que no existe defecto y su ausencia es `config_error` (§14.1).
  """

  @type t :: %__MODULE__{
          gunther: gunther(),
          router: router(),
          refusal: refusal(),
          retry: retry(),
          circuit_breaker: circuit_breaker(),
          engine: engine(),
          devices: devices(),
          commands: commands(),
          engines: [engine_profile()],
          models: [model()],
          nodes: [node_profile()],
          placement: placement(),
          decision_models: [decision_spec()],
          rules: [rule()],
          providers: %{optional(atom()) => provider()},
          structured: structured(),
          stream: stream(),
          context: context(),
          sessions: sessions(),
          memory: memory(),
          selector: selector(),
          consumers: %{optional(atom()) => consumer()},
          cache: cache(),
          tools: tools(),
          mcp: mcp(),
          mcp_clients: [mcp_client()],
          agents: agents(),
          rag: rag(),
          embedders: %{optional(atom()) => embedder()},
          guardrails: guardrails(),
          budget: budget(),
          gateway: gateway(),
          security: security(),
          telemetry: telemetry()
        }

  @type gunther :: %{instance_id: String.t(), state_dir: Path.t() | nil, dotenv: boolean()}
  @type router :: %{
          llm: :never | :fallback | :always,
          llm_timeout_ms: pos_integer(),
          llm_warm_cache: boolean(),
          max_failovers: non_neg_integer(),
          max_in_flight: pos_integer(),
          fallback_strategy: :last | :first | :round_robin | :least_used,
          regex_match_limit: pos_integer(),
          allow_general: boolean(),
          allow_unverified: boolean(),
          affinity: :off | :prefer,
          affinity_weight: float() | nil,
          classifiers: [atom()],
          capture: %{enabled: boolean(), max_entries: non_neg_integer()},
          cache: %{enabled: boolean(), ttl_seconds: pos_integer(), max_entries: pos_integer()},
          embedding: %{min_similarity: float()}
        }
  @type refusal :: %{policy: :fail | :wait | :degrade, wait_ms: pos_integer()}
  @type retry :: %{
          max_attempts: pos_integer(),
          base_ms: pos_integer(),
          cap_ms: pos_integer(),
          attempt_timeout_ms: pos_integer()
        }
  @type circuit_breaker :: %{
          failure_rate_threshold: float(),
          min_calls: pos_integer(),
          open_duration_ms: pos_integer(),
          half_open_probes: pos_integer()
        }
  @type engine :: %{
          start_timeout_ms: pos_integer(),
          idle_unload_seconds: pos_integer(),
          vram_margin_mib: non_neg_integer(),
          port_range: {pos_integer(), pos_integer()},
          log_lines: pos_integer(),
          max_restarts: non_neg_integer(),
          shutdown_timeout_ms: pos_integer()
        }
  @type devices :: %{
          foreign_resync_threshold_mib: non_neg_integer(),
          total_tolerance_mib: non_neg_integer(),
          map: [device_map()]
        }
  @type device_map :: %{
          physical_id: String.t(),
          kind: :discrete | :unified,
          max_mib: pos_integer() | nil,
          reserve_mib: pos_integer() | nil,
          backend_names: %{optional(atom()) => String.t()}
        }
  @type commands :: %{allow: [command()], env_allow: [String.t()]}
  @type command :: %{name: String.t(), path: Path.t(), sha256: String.t() | nil}
  @type engine_profile :: %{
          id: String.t(),
          command: String.t(),
          backend: :cuda | :vulkan | :rocm | :metal | :cpu,
          env: %{optional(String.t()) => String.t()},
          allowed_extra_args: [String.t()],
          min_build: non_neg_integer()
        }
  @type model :: %{
          alias: atom(),
          provider: atom(),
          model_id: String.t(),
          locality: :local | :lan | :cloud,
          node: String.t() | nil,
          engine: String.t() | nil,
          path: Path.t() | nil,
          capabilities: [atom()],
          modalities: [:text | :image | :audio | :video],
          context_window: pos_integer(),
          ctx_size: pos_integer(),
          max_output_tokens: pos_integer(),
          max_concurrency: pos_integer(),
          vram_mb: non_neg_integer(),
          compute_buffer_mib: non_neg_integer() | nil,
          fit: :auto | :formula | :declared,
          kv_type_k: String.t(),
          kv_type_v: String.t(),
          resident: boolean(),
          exclusive: boolean(),
          tags: [atom()],
          pricing: %{input_per_mtok_micros: non_neg_integer(), output_per_mtok_micros: non_neg_integer()},
          max_attachment_bytes: %{image: pos_integer(), audio: pos_integer()}
        }
  @type node_profile :: %{
          id: String.t(),
          url: String.t(),
          pinned_server_cert_sha256: [String.t()],
          client_cert_file: Path.t() | nil,
          client_key_file: Path.t() | nil,
          heartbeat_ms: pos_integer(),
          heartbeat_miss_limit: pos_integer(),
          lease_ttl_ms: pos_integer(),
          max_inflight_control: pos_integer(),
          control_timeout_ms: pos_integer()
        }
  @type placement :: %{prefer: [String.t()], max_loaded_models: non_neg_integer()}
  @type decision_spec :: map()
  @type rule :: %{
          name: String.t(),
          when: map() | nil,
          action: :veto | :force | :prefer,
          target: map(),
          weight: float() | nil
        }
  @type provider :: %{
          module: module(),
          mode: :managed_local | :managed_node | :external,
          base_url: String.t() | nil,
          api_key_env: String.t() | nil,
          rpm: non_neg_integer(),
          tpm: non_neg_integer()
        }
  @type structured :: %{mode: :auto | :native | :prompt, max_retries: non_neg_integer(), feedback_bytes: pos_integer()}
  @type stream :: %{
          pre_commit_buffer_chunks: pos_integer(),
          max_buffered_chunks: pos_integer(),
          cancel_grace_ms: non_neg_integer()
        }
  @type context :: %{
          max_prompt_tokens: non_neg_integer(),
          compaction: :none | :truncate | :summary | {:custom, module()},
          summary_model: atom() | nil
        }
  @type sessions :: %{
          max_sessions: pos_integer(),
          idle_ttl_seconds: pos_integer(),
          max_turns_in_memory: pos_integer(),
          store: :memory | :disk
        }
  @type memory :: %{max_entries: pos_integer()}
  @type selector :: %{max_states: pos_integer(), aging_step_ms: pos_integer()}
  @type consumer :: %{
          default_model: atom(),
          priority: integer(),
          rules: [rule()]
        }
  @type cache :: %{sweep_interval_ms: pos_integer()}
  @type tools :: %{
          max_result_bytes: pos_integer(),
          truncate_passes: pos_integer(),
          max_parallel: pos_integer(),
          max_schema_bytes: pos_integer(),
          max_description_bytes: pos_integer(),
          default_permission_local: :auto | :confirm | :deny,
          default_permission_mcp: :auto | :confirm | :deny,
          auto_approve: [String.t()],
          permissions: [%{pattern: String.t(), permission: :auto | :confirm | :deny}]
        }
  @type mcp :: %{
          compat_2025_11_25: boolean(),
          max_sessions: pos_integer(),
          session_ttl_seconds: pos_integer(),
          max_message_bytes: pos_integer(),
          rpc_timeout_ms: pos_integer(),
          ping_interval_ms: pos_integer(),
          reconnect_attempts: pos_integer()
        }
  @type mcp_client :: %{
          id: String.t(),
          transport: :stdio | :http,
          command: String.t() | nil,
          args: [String.t()],
          url: String.t() | nil,
          allow_private: boolean()
        }
  @type agents :: %{
          max_agents: pos_integer(),
          max_depth: pos_integer(),
          confirm_timeout_ms: pos_integer()
        }
  @type rag :: %{
          max_document_bytes: pos_integer(),
          max_chunks_per_document: pos_integer(),
          rrf_k: pos_integer(),
          strategy: :vector | :lexical | :hybrid | :multi_query,
          tool_enabled: boolean(),
          store: :memory | :sqlite | :postgres,
          store_backend: :separate | :shared,
          sqlite: %{path: Path.t() | nil}
        }
  @type embedder :: %{module: module(), min_score: float()}
  @type guardrails :: %{
          timeout_ms: pos_integer(),
          on_error: :closed | :open,
          pre_send: boolean(),
          stream_mode: :buffered | :post_hoc
        }
  @type budget :: %{max_cost_per_request: non_neg_integer()}
  @type gateway :: %{
          max_body_bytes: pos_integer(),
          max_headers_bytes: pos_integer(),
          max_connections: pos_integer(),
          max_attachment_body_bytes: pos_integer() | nil,
          request_timeout_ms: pos_integer(),
          allow_plaintext_remote: boolean()
        }
  @type security :: %{persist_hmac_key_env: String.t(), persist_encrypt: boolean()}
  @type telemetry :: %{prefix: [atom()]}

  defstruct gunther: nil,
            router: nil,
            refusal: nil,
            retry: nil,
            circuit_breaker: nil,
            engine: nil,
            devices: nil,
            commands: nil,
            engines: [],
            models: [],
            nodes: [],
            placement: nil,
            decision_models: [],
            rules: [],
            providers: %{},
            structured: nil,
            stream: nil,
            context: nil,
            sessions: nil,
            memory: nil,
            selector: nil,
            consumers: %{},
            cache: nil,
            tools: nil,
            mcp: nil,
            mcp_clients: [],
            agents: nil,
            rag: nil,
            embedders: %{},
            guardrails: nil,
            budget: nil,
            gateway: nil,
            security: nil,
            telemetry: nil

  @doc """
  Carga y valida una configuración desde un mapa o una ruta (SPEC §14).

  Devuelve `{:ok, %Config{}}` o `{:error, %Gunther.Error{}}` con código
  `:config_error`.

  ## Ejemplos

      iex> {:ok, config} = Gunther.Config.load(%{gunther: %{instance_id: "main"}})
      iex> config.gunther.instance_id
      "main"
  """
  @spec load(map() | Path.t()) :: {:ok, t()} | {:error, Gunther.Error.t()}
  def load(source) when is_map(source) do
    Gunther.Config.Validator.validate(source)
  end

  def load(path) when is_binary(path) do
    case Gunther.Config.Loader.load(path) do
      {:ok, raw} -> validate(raw)
      {:error, %Gunther.Error{} = error} -> {:error, error}
    end
  end

  @doc """
  Valida un mapa de configuración ya carregado.
  """
  @spec validate(map()) :: {:ok, t()} | {:error, Gunther.Error.t()}
  def validate(raw) do
    Gunther.Config.Validator.validate(raw)
  end
end
