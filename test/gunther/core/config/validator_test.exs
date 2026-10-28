defmodule Gunther.Config.ValidatorTest do
  use ExUnit.Case, async: true

  alias Gunther.Config
  alias Gunther.Error

  defp base(extra \\ %{}) do
    Map.merge(%{"gunther" => %{"instance_id" => "main"}}, extra)
  end

  describe "carga minima" do
    test "una config con solo [gunther].instance_id es valida" do
      assert {:ok, %Config{} = config} = Config.load(base())
      assert config.gunther.instance_id == "main"
    end

    test "instance_id es obligatorio" do
      assert {:error, %Error{code: :config_error}} = Config.load(%{})
    end

    test "instance_id debe cumplir el patron" do
      for bad <- ["Main", "con espacio", "", "a" <> String.duplicate("b", 40)] do
        assert {:error, %Error{code: :config_error}} = Config.load(%{"gunther" => %{"instance_id" => bad}}),
               "deberia rechazar #{inspect(bad)}"
      end
    end
  end

  describe "defectos (§14.1)" do
    test "cada seccion tiene su defecto documentado" do
      {:ok, config} = Config.load(base())

      assert config.router.llm == :fallback
      assert config.router.llm_timeout_ms == 1500
      assert config.router.max_failovers == 2
      assert config.router.max_in_flight == 256
      assert config.router.fallback_strategy == :least_used
      assert config.router.regex_match_limit == 100_000
      assert config.router.allow_general == false
      assert config.router.allow_unverified == false
      assert config.router.affinity == :off
      assert config.router.cache.ttl_seconds == 300
      assert config.router.cache.max_entries == 10_000
      assert config.router.embedding.min_similarity == 0.0
      assert config.refusal.policy == :wait
      assert config.refusal.wait_ms == 10_000
      assert config.retry.max_attempts == 3
      assert config.retry.base_ms == 200
      assert config.retry.cap_ms == 5000
      assert config.retry.attempt_timeout_ms == 60_000
      assert config.circuit_breaker.failure_rate_threshold == 0.5
      assert config.circuit_breaker.min_calls == 10
      assert config.circuit_breaker.open_duration_ms == 30_000
      assert config.circuit_breaker.half_open_probes == 1
      assert config.engine.start_timeout_ms == 120_000
      assert config.engine.idle_unload_seconds == 600
      assert config.engine.vram_margin_mib == 1024
      assert config.engine.port_range == {39_000, 39_999}
      assert config.engine.log_lines == 2000
      assert config.engine.max_restarts == 3
      assert config.engine.shutdown_timeout_ms == 30_000
      assert config.devices.foreign_resync_threshold_mib == 64
      assert config.devices.total_tolerance_mib == 256
      assert config.structured.mode == :auto
      assert config.structured.max_retries == 2
      assert config.structured.feedback_bytes == 2048
      assert config.stream.pre_commit_buffer_chunks == 16
      assert config.stream.max_buffered_chunks == 64
      assert config.stream.cancel_grace_ms == 1000
      assert config.context.compaction == :truncate
      assert config.sessions.max_sessions == 1024
      assert config.sessions.idle_ttl_seconds == 3600
      assert config.sessions.max_turns_in_memory == 200
      assert config.sessions.store == :memory
      assert config.memory.max_entries == 10_000
      assert config.selector.max_states == 10_000
      assert config.selector.aging_step_ms == 1000
      assert config.cache.sweep_interval_ms == 30_000
      assert config.tools.max_result_bytes == 65_536
      assert config.tools.truncate_passes == 32
      assert config.tools.max_parallel == 4
      assert config.tools.max_schema_bytes == 16_384
      assert config.tools.max_description_bytes == 2048
      assert config.tools.default_permission_local == :auto
      assert config.tools.default_permission_mcp == :confirm
      assert config.mcp.compat_2025_11_25 == false
      assert config.mcp.max_sessions == 256
      assert config.mcp.session_ttl_seconds == 900
      assert config.mcp.max_message_bytes == 4_194_304
      assert config.mcp.rpc_timeout_ms == 30_000
      assert config.mcp.ping_interval_ms == 60_000
      assert config.mcp.reconnect_attempts == 5
      assert config.agents.max_agents == 64
      assert config.agents.max_depth == 3
      assert config.agents.confirm_timeout_ms == 3_600_000
      assert config.rag.max_document_bytes == 10_485_760
      assert config.rag.max_chunks_per_document == 5000
      assert config.rag.rrf_k == 60
      assert config.rag.strategy == :hybrid
      assert config.rag.tool_enabled == true
      # Sin [gunther].state_dir no hay donde persistir: el store efectivo
      # pasa a :memory con un aviso (un campo que nada puede rellenar y que
      # la validacion exige seria un deadlock).
      assert config.rag.store == :memory
      assert config.rag.store_backend == :separate
      assert config.guardrails.timeout_ms == 2000
      assert config.guardrails.on_error == :closed
      assert config.guardrails.pre_send == false
      assert config.guardrails.stream_mode == :buffered
      assert config.budget.max_cost_per_request == 0
      assert config.gateway.max_body_bytes == 1_048_576
      assert config.gateway.max_headers_bytes == 16_384
      assert config.gateway.max_connections == 1024
      assert config.gateway.request_timeout_ms == 120_000
      assert config.gateway.allow_plaintext_remote == false
      assert config.security.persist_encrypt == false
      assert config.telemetry.prefix == [:gunther]
      assert config.placement.max_loaded_models == 0
    end

    test "affinity_weight es obligatorio con affinity = prefer" do
      assert {:error, %Error{code: :config_error} = error} =
               Config.load(base(%{"router" => %{"affinity" => "prefer"}}))

      assert error.details[:key] == "affinity_weight"
    end

    test "affinity_weight se acepta con affinity = prefer" do
      assert {:ok, config} =
               Config.load(base(%{"router" => %{"affinity" => "prefer", "affinity_weight" => 0.5}}))

      assert config.router.affinity == :prefer
      assert config.router.affinity_weight == 0.5
    end
  end

  describe "claves desconocidas (D-26, CE-H11)" do
    test "en una seccion normal es un aviso" do
      assert {:ok, config} = Config.load(base(%{"router" => %{"clave_rara" => 1}}))
      assert config.router.llm == :fallback
    end

    test "en una seccion de seguridad es un error" do
      for section <- ["commands", "nodes", "tools", "mcp", "gateway", "security"] do
        assert {:error, %Error{code: :config_error} = error} =
                 Config.load(base(%{section => %{"clave_rara" => 1}})),
               "deberia rechazar la clave desconocida en [#{section}]"

        assert error.details[:section] == section
      end
    end
  end

  describe "validaciones cruzadas (§14.2)" do
    test "max_p99_ms no puede superar router.llm_timeout_ms" do
      raw =
        base(%{
          "router" => %{"llm_timeout_ms" => 1000},
          "decision_models" => [
            %{
              "id" => "d",
              "kind" => "general_llm",
              "model" => "m",
              "eval" => %{
                "corpus" => "c.jsonl",
                "adversarial_corpus" => "a.jsonl",
                "required_languages" => ["es"],
                "max_p99_ms" => 2000
              }
            }
          ]
        })

      assert {:error, %Error{code: :config_error} = error} = Config.load(raw)
      assert error.details[:id] == :d
    end

    test "required_languages es obligatorio si require_eval" do
      raw =
        base(%{
          "decision_models" => [
            %{
              "id" => "d",
              "kind" => "general_llm",
              "model" => "m",
              "eval" => %{"corpus" => "c.jsonl", "adversarial_corpus" => "a.jsonl"}
            }
          ]
        })

      assert {:error, %Error{code: :config_error}} = Config.load(raw)
    end

    test "un consumer sin default_model es config_error" do
      assert {:error, %Error{code: :config_error}} =
               Config.load(base(%{"consumers" => %{"default" => %{}}}))
    end

    test "consumers.default_model debe ser un alias del catalogo" do
      assert {:error, %Error{code: :config_error} = error} =
               Config.load(base(%{"consumers" => %{"default" => %{"default_model" => "no_existe"}}}))

      assert error.details[:consumer] == :default
    end

    test "consumers.default_model debe existir en el catalogo" do
      raw =
        base(%{
          "models" => [%{"alias" => "qwen", "provider" => "llamacpp", "model_id" => "x"}],
          "consumers" => %{"default" => %{"default_model" => "qwen"}}
        })

      assert {:ok, config} = Config.load(raw)
      assert config.consumers.default.default_model == :qwen
    end

    test "un nombre de regla duplicado entre global y consumer es config_error (M-01)" do
      raw =
        base(%{
          "models" => [%{"alias" => "qwen", "provider" => "llamacpp", "model_id" => "x"}],
          "rules" => [%{"name" => "privado", "action" => "veto", "target" => %{"locality" => "cloud"}}],
          "consumers" => %{
            "default" => %{
              "default_model" => "qwen",
              "rules" => [%{"name" => "privado", "action" => "veto", "target" => %{"locality" => "cloud"}}]
            }
          }
        })

      assert {:error, %Error{code: :config_error} = error} = Config.load(raw)
      assert error.details[:duplicates] == [{:default, "privado"}]
    end

    test "un veto incondicional del consumer sobre su default_model es config_error (§6.8.1)" do
      raw =
        base(%{
          "models" => [%{"alias" => "qwen", "provider" => "llamacpp", "model_id" => "x"}],
          "consumers" => %{
            "default" => %{
              "default_model" => "qwen",
              "rules" => [%{"name" => "no_local", "action" => "veto", "target" => %{"models" => ["qwen"]}}]
            }
          }
        })

      assert {:error, %Error{code: :config_error} = error} = Config.load(raw)
      assert error.details[:rule] == "no_local"
    end

    test "rag.store = sqlite sin path ni state_dir es config_error" do
      assert {:error, %Error{code: :config_error}} =
               Config.load(base(%{"rag" => %{"store" => "sqlite"}}))
    end

    test "rag.store = sqlite con state_dir deriva el path" do
      raw =
        base(%{
          "gunther" => %{"instance_id" => "main", "state_dir" => "/var/lib/gunther"},
          "rag" => %{"store" => "sqlite"}
        })

      assert {:ok, config} = Config.load(raw)
      assert config.rag.store == :sqlite
      assert config.rag.sqlite.path == "/var/lib/gunther/rag.db"
    end

    test "rag.store = sqlite con path explicito lo respeta" do
      raw =
        base(%{
          "gunther" => %{"instance_id" => "main", "state_dir" => "/var/lib/gunther"},
          "rag" => %{"store" => "sqlite", "sqlite" => %{"path" => "/otro/rag.db"}}
        })

      assert {:ok, config} = Config.load(raw)
      assert config.rag.sqlite.path == "/otro/rag.db"
    end

    test "rag.store_backend = shared es config_error en v1 (§8.9)" do
      assert {:error, %Error{code: :config_error} = error} =
               Config.load(base(%{"rag" => %{"store_backend" => "shared"}}))

      assert error.message =~ "v1.1"
    end

    test "max_attachment_bytes deben ser mayores que 0" do
      raw =
        base(%{
          "models" => [
            %{
              "alias" => "qwen",
              "provider" => "llamacpp",
              "model_id" => "x",
              "max_attachment_bytes" => %{"image" => 0, "audio" => 100}
            }
          ]
        })

      assert {:error, %Error{code: :config_error}} = Config.load(raw)
    end

    test "un device unified exige max_mib y reserve_mib" do
      raw = base(%{"devices" => %{"map" => [%{"physical_id" => "gpu0", "kind" => "unified"}]}})
      assert {:error, %Error{code: :config_error}} = Config.load(raw)
    end

    test "un device unified con max_mib y reserve_mib es valido" do
      raw =
        base(%{
          "devices" => %{
            "map" => [%{"physical_id" => "gpu0", "kind" => "unified", "max_mib" => 12_000, "reserve_mib" => 2048}]
          }
        })

      assert {:ok, config} = Config.load(raw)

      assert config.devices.map == [
               %{physical_id: "gpu0", kind: :unified, max_mib: 12_000, reserve_mib: 2048, backend_names: %{}}
             ]
    end

    test "nodes[].url debe empezar por https://" do
      raw =
        base(%{
          "nodes" => [
            %{"id" => "pc2", "url" => "http://192.168.1.20:7443", "pinned_server_cert_sha256" => ["abc"]}
          ]
        })

      assert {:error, %Error{code: :config_error}} = Config.load(raw)
    end

    test "nodes[].pinned_server_cert_sha256 es obligatorio" do
      raw = base(%{"nodes" => [%{"id" => "pc2", "url" => "https://192.168.1.20:7443"}]})
      assert {:error, %Error{code: :config_error}} = Config.load(raw)
    end

    test "un modelo con node no lleva path" do
      raw =
        base(%{
          "models" => [
            %{"alias" => "qwen", "provider" => "llamacpp", "model_id" => "x", "node" => "pc2", "path" => "/m.gguf"}
          ]
        })

      assert {:error, %Error{code: :config_error}} = Config.load(raw)
    end

    test "el command de un engine debe figurar en commands.allow" do
      raw =
        base(%{
          "commands" => %{"allow" => [%{"name" => "llama-server", "path" => "/bin/llama-server"}]},
          "engines" => [%{"id" => "e1", "command" => "otro", "backend" => "cuda"}]
        })

      assert {:error, %Error{code: :config_error} = error} = Config.load(raw)
      assert error.details[:engine] == "e1"
    end

    test "max_concurrency de un modelo debe ser >= 1" do
      raw =
        base(%{
          "models" => [%{"alias" => "qwen", "provider" => "llamacpp", "model_id" => "x", "max_concurrency" => 0}]
        })

      assert {:error, %Error{code: :config_error}} = Config.load(raw)
    end
  end

  describe "taxonomias cerradas" do
    test "una skill desconocida es config_error (D-02, Q-16)" do
      raw =
        base(%{
          "models" => [%{"alias" => "qwen", "provider" => "llamacpp", "model_id" => "x", "capabilities" => ["xyz"]}]
        })

      assert {:error, %Error{code: :config_error} = error} = Config.load(raw)
      assert error.details[:unknown] == [:xyz]
    end

    test "las siete skills de §1.3 son validas" do
      raw =
        base(%{
          "models" => [
            %{
              "alias" => "qwen",
              "provider" => "llamacpp",
              "model_id" => "x",
              "capabilities" => ["code", "reasoning", "redaction", "vision", "audio", "tools", "embeddings"]
            }
          ]
        })

      assert {:ok, _config} = Config.load(raw)
    end

    test "una modalidad desconocida es config_error" do
      raw =
        base(%{
          "models" => [%{"alias" => "qwen", "provider" => "llamacpp", "model_id" => "x", "modalities" => ["video8k"]}]
        })

      assert {:error, %Error{code: :config_error}} = Config.load(raw)
    end
  end

  describe "reglas" do
    test "target es obligatorio" do
      raw = base(%{"rules" => [%{"name" => "r", "action" => "veto"}]})
      assert {:error, %Error{code: :config_error}} = Config.load(raw)
    end

    test "weight es obligatorio con prefer" do
      raw = base(%{"rules" => [%{"name" => "r", "action" => "prefer", "target" => %{"locality" => "cloud"}}]})
      assert {:error, %Error{code: :config_error}} = Config.load(raw)
    end

    test "weight solo existe con prefer" do
      raw =
        base(%{
          "rules" => [%{"name" => "r", "action" => "veto", "target" => %{"locality" => "cloud"}, "weight" => 1.0}]
        })

      assert {:error, %Error{code: :config_error}} = Config.load(raw)
    end

    test "una clave de target desconocida es config_error" do
      raw = base(%{"rules" => [%{"name" => "r", "action" => "veto", "target" => %{"inventada" => "x"}}]})
      assert {:error, %Error{code: :config_error}} = Config.load(raw)
    end

    test "when es opcional" do
      raw = base(%{"rules" => [%{"name" => "r", "action" => "veto", "target" => %{"locality" => "cloud"}}]})
      assert {:ok, config} = Config.load(raw)
      assert config.rules == [%{name: "r", when: nil, action: :veto, target: %{"locality" => "cloud"}, weight: nil}]
    end
  end
end
