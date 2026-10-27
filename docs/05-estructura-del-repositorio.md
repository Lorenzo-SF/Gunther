# Estructura del repositorio

```
gunther/
├── lib/gunther/
│   ├── core/                  # sin dependencias opcionales
│   │   ├── config/            # loader, validator, server (§14)
│   │   ├── catalog/           # catálogo y registry (§4.4, §5.14)
│   │   ├── router/            # capas, reglas, caché, ranking, Borda (§6)
│   │   ├── decision/          # DecisionSpec, DecisionView, calibración (§6.11)
│   │   ├── resilience/        # pipeline (§2.5) — único que nombra Arrea/Apero/Trebejo
│   │   ├── command/           # run, spawn, Spawner, ArgsBuilder (§3.4) — idem
│   │   ├── cache.ex           # §3.3 — idem
│   │   ├── platform.ex        # idem
│   │   ├── resource/          # ledger, placement, placer, GGUF, KV (§11)
│   │   ├── detector/          # LlamaCpp, Cpu, Nvidia, Rocm, Metal (§5.12)
│   │   ├── engine/            # backend local y remoto, loader, reaper (§11.1, §2.8)
│   │   ├── node/              # client y connection (§18.6); NO el agente
│   │   ├── provider/          # behaviour y providers de referencia (§5.1)
│   │   ├── session/, memory/  # §7
│   │   └── telemetry/         # puente y eventos (§13)
│   ├── tools/, mcp/           # §9 (servidor y cliente)
│   ├── rag/                   # §8 (opcional)
│   ├── agent/                 # §10.1 (opcional)
│   ├── gateway/               # §12 (opcional; plug + bandit)
│   ├── node_agent/            # Gunther.Node.Agent (§18; opcional; plug + bandit)
│   ├── hive/                  # v1.1
│   └── testing/               # Mock, FakeGPU, FakeNode
├── test/                      # espejo de lib/; fixtures/ con cabeceras
├── probes/                    # F0, fuera del paquete publicado
├── docs/                      # este conjunto
├── examples/                  # configs y ejemplos ejecutables
├── scripts/                   # doc_lint.sh, check_boundaries.sh
├── .github/                   # workflows y plantillas de issues
├── SPEC-000-GUNTHER_rN.md
├── LICENSE  NOTICE  CONTRIBUTING.md  SECURITY.md  CHANGELOG.md  README.md
└── mix.exs
```

## Reglas de dependencias (comprobadas en CI)

| Regla | Origen | Comprobación |
| --- | --- | --- |
| `lib/gunther/core/**` no referencia `tools`, `mcp` (servidor), `rag`, `agent`, `gateway`, `node_agent`, `hive` | SPEC §0.4 | `mix xref graph` |
| Solo `resilience/`, `command/`, `cache.ex`, `platform.ex` y la carga de config nombran `Arrea.`, `Apero.` o `Trebejo.` | SPEC §3.6 | `scripts/check_boundaries.sh` |
| Ningún `System.cmd`, `:os.cmd` ni `Port.open` fuera de `command/` | SPEC §3.4 | `scripts/check_boundaries.sh` |
| Las dependencias opcionales se cargan con `Code.ensure_loaded?/1` | SPEC §0.4 | Prueba que arranca el núcleo sin ellas |

## Dependencias de `mix.exs`

Obligatorias: `arrea`, `apero`, `trebejo`, `jason`, `finch`, `telemetry`, el validador de JSON Schema que decida F0. Opcionales: `plug`, `bandit`, `exqlite`, `postgrex`, `opentelemetry`. Sólo para pruebas: `stream_data`, `benchee`.
