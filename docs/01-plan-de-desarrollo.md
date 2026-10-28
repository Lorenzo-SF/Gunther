# Plan de diseño y desarrollo de Gunther

**Base**: `SPEC-000-GUNTHER_r9.md`. Este plan **no contiene estimaciones de tiempo**: una estimación sería una afirmación sin medición (regla §0.6 del SPEC). El plan fija **orden, dependencias, entregables y criterios de salida**. Los tiempos reales se registran al cerrar cada fase (`docs/13-registro-de-fases.md`) y solo entonces pueden usarse para planificar la siguiente.

**Estado a 2026-10-28**: DP0 cerrado (`CIERRE-DP0.md`). r9 vigente. F0 y F1 cerrados.

## 1. Principios

1.  **Una fase se cierra por ejecución real** (D-10): los AC del SPEC §19 se ejecutan; no se revisan.
2.  **Cada fase empieza con diseño y termina con cierre.** Diseño de fase: leer las secciones del SPEC que cubre, escribir una nota de fase de una página (`docs/fases/Fnn.md`) con las decisiones locales y los paquetes de trabajo; revisar. Cierre de fase: ejecutar AC, actualizar SPEC si hubo desviaciones, registrar la fase.
3.  **El SPEC manda.** Si el código necesita algo que el SPEC no dice, se detiene el trabajo, se corrige el SPEC (nueva revisión `rN+1`) y se continúa. Nunca al revés.
4.  **Orden por valor y riesgo**: primero lo que da un sistema de extremo a extremo (router sobre providers mock y cloud), después lo que depende de hardware.
5.  **Definición de hecho (DoD) de cualquier paquete de trabajo**: código con typespecs y `@moduledoc`; tests unitarios, de propiedades donde el SPEC lo pida y de contrato donde haya behaviour; eventos de telemetría del SPEC §13.1 emitidos y probados; claves de config en el esquema §14 con validación; sin violaciones de los scripts de CI; entrada en `CHANGELOG.md`; ADR si introduce una decisión.

## 2. Fases de diseño (antes y durante el desarrollo)

| Fase                          | Objetivo                                             | Entregables                                                                                                   | Criterio de salida                                                        | Estado                    |
| ----------------------------- | ---------------------------------------------------- | ------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------- | ------------------------- |
| **DP0** Aprobación            | El dueño aprueba D-48 a D-92 y las respuestas de §21 | Decisiones marcadas `aceptada` en `docs/08-decisiones/`; `CIERRE-DP0.md` firmado                              | Cada ADR tiene estado `aceptada` o `rechazada`; Q-01 a Q-16 cerradas      | **Completado 2026-10-26** |
| **DP1** Memoria de decisiones | Recuperar el porqué de D-01 a D-47                   | ADR de D-01 a D-47 escritos por el dueño (el SPEC solo tiene su resumen de una línea) y el ADR del RAG (D-36) | Ningún D-nn con † del SPEC §1.4 sin ADR                                   | **Siguiente**             |
| **DP2** Contratos en código   | Traducir §4 y §5 a módulos Elixir sin lógica         | Módulos con `@callback`, `@type`, structs y `@moduledoc`; `mix docs` genera la API                            | `mix compile --warnings-as-errors` limpio; cada callback tiene su ejemplo | Pendiente                 |
| **DP3** Diseño de fase        | Se repite al inicio de cada Fnn                      | `docs/fases/Fnn.md`                                                                                           | Revisado antes de escribir código                                         | Pendiente                 |
| **DP4** Congelación de API    | Antes de `1.0.0`                                     | Lista pública cerrada (SPEC §4, §5); `@deprecated` donde proceda                                              | Revisión sin cambios pendientes                                           | Pendiente                 |

## 3. Grafo de dependencias entre fases

```
F0 ─► F1 ─┬─► F2 ──────────────┐
          │                    ├─► F6 ─┐
          └─► F3 ─► F4 ─► F5 ──┘       │
                │      │               ├─► F15 ─┐
                │      └─► F10          │        │
                ├─► F7 ─┬─► F9          │        │
                │       ├─► F13         │        │
                │       └─► F14 ◄─ F8   │        │
                ├─► F8                  │        │
                └─► F11 ─► F12          │        ▼
                                        └──────► F16 ─► 1.0.0 ─► F18 (v1.1+)
```

Dependencias duras: F2 y F3 requieren F1. F4 requiere F3. F5 requiere F4. F6 requiere F2 y F5. F7, F8 y F11 requieren F3. F9 requiere F5 y F7. F10 requiere F4 y F8. F13 requiere F7. F14 requiere F5, F7 y F8. F15 requiere F2, F5 y F6. F16 requiere todas. F18-F22 requieren `1.0.0`.

**Nota sobre la numeración de fases.** La colmena, que era F17 en r5/r6, se sustituye por F18 a F22 (la coral) en r7 y r8. No hay una F17 activa. La numeración original se conserva como referencia histórica en `docs/13-registro-de-fases.md`.

**Orden recomendado para una sola persona**: F0, F1, F3, F4, F5, F2, F6, F7, F8, F9, F10, F11, F12, F13, F14, F15, F16. Motivo: F3 a F5 dan un sistema completo de enrutado sobre providers mock y cloud sin depender de hardware; F2 y F6 (GPU) después, cuando el pipeline que van a alimentar ya existe y se puede probar de extremo a extremo.

**Cierres CE y fases**: los cierres CE-01 a CE-34 están **escritos** en el SPEC. Su **verificación por test** ocurre en la fase que implementa cada uno: CE-01 en F3; CE-02 en F7; CE-15 (commit de stream) en F3; CE-19/CE-20 (comandos) en F1; CE-05 (reconciliación) en F6; CE-34 (reglas de consumer) en F4.

## 4. Paquetes de trabajo (WP) por fase

Cada WP es una unidad revisable. «Pruebas» indica el tipo mínimo exigido además de las unitarias.

### F0 · Verificación

| WP    | Contenido                                                              | Pruebas / resultado                          |
| ----- | ---------------------------------------------------------------------- | -------------------------------------------- |
| F0-01 | Repositorio, CI, scripts de lint y fronteras                           | CI verde en vacío                            |
| F0-02 | Proyecto sonda de las hermanas: G-01 a G-07, G-17, G-21                | Resultados en `docs/13-registro-de-fases.md` |
| F0-03 | Matriz del `Spawner`: G-08                                             | Tabla R1 a R8 por candidato                  |
| F0-04 | Sondas de llama.cpp: G-09 a G-14 con fixtures grabados                 | Fixtures en `test/fixtures/`                 |
| F0-05 | Sondas MCP: G-15                                                       | Resultado y rama                             |
| F0-06 | Sondas TLS y proxy: G-19, G-20                                         | Resultado y rama                             |
| F0-07 | G-16, G-18, G-22, G-23, G-24, G-25, G-26, G-27, G-28, G-29, G-30, G-31 | Resultado y rama                             |
| F0-08 | Registro de resultados y SPEC `r8` con las ramas elegidas              | `r8` aprobada                                |

### F1 · Núcleo

| WP    | Contenido                                                                                                                            | Pruebas                                                   |
| ----- | ------------------------------------------------------------------------------------------------------------------------------------ | --------------------------------------------------------- |
| F1-01 | Esquema y validador de config (§14), claves desconocidas por sección, validaciones cruzadas, **incluida `[[consumers.<id>.rules]]`** | Tabla de casos inválidos; una prueba por regla de §14.2   |
| F1-02 | `Config.Server`, snapshots atómicos, recarga                                                                                         | Propiedades: el snapshot nunca queda a medias             |
| F1-03 | Catálogo y registro de behaviours (DP2 ya los definió)                                                                               | Contrato de registro                                      |
| F1-04 | `Gunther.Error` y tabla de códigos §4.13                                                                                             | Una prueba por código y `retryable?`                      |
| F1-05 | `Command.run/3` (corto)                                                                                                              | Bloqueo de comandos, `.zshrc` lento                       |
| F1-06 | `Spawner` y `Command.spawn/3` (largo), lista de permitidos con `realpath`, inodo y `sha256`                                          | Reensamblado de `:noeol`; cambio de binario impide lanzar |
| F1-07 | `Gunther.Cache`                                                                                                                      | Propiedades: tope, LRU exacto, TTL                        |
| F1-08 | `Gunther.Cancel`                                                                                                                     | Cancelación entre procesos                                |
| F1-09 | `Telemetry.Bridge` y eventos de §13.1; prefijo `[:gunther, :coral, ...]` reservado (G6)                                              | Test de emisión por evento                                |
| F1-10 | `Platform`, `Doctor` (esqueleto), `Testing.Mock`                                                                                     | Doctor sobre config de ejemplo                            |
| F1-11 | Redacción de secretos (`Inspect`); `Gunther.Context` (estructura, G2)                                                                | T-05: ninguna clave en logs                               |

### F2 · Recursos

| WP    | Contenido                                                                                                  | Pruebas                                            |
| ----- | ---------------------------------------------------------------------------------------------------------- | -------------------------------------------------- |
| F2-01 | Parser GGUF acotado                                                                                        | Fuzz; modelos de referencia                        |
| F2-02 | Tabla de tipos de ggml y fórmula de KV por tipo de atención                                                | `kv_mib` fórmula = `kv_mib` del servidor           |
| F2-03 | `Detector.LlamaCpp` con fixtures por backend; `Detector.Cpu`                                               | Fixtures CUDA, Vulkan, ROCm, Metal; `free > total` |
| F2-04 | Detectores de fabricante (identidad física, atribución) según G-11                                         | Fixtures por herramienta                           |
| F2-05 | Mapeo `[[devices.map]]`, reglas de unificada, coherencia                                                   | Casos de §11.8                                     |
| F2-06 | `Resource.Ledger` con `foreign` y `available`; convenciones A y B de medida; `Doctor.calibrate_overhead/2` | Propiedades (`StreamData`) de §11.3                |
| F2-07 | `Placement` por nodo y `Placer` con expulsión y tope por conteo                                            | Concurrencia de dos arranques                      |
| F2-08 | Método `fit` (rama de G-09); estados de la reserva y reintento en otro device                              | Con y sin `llama-fit-params`                       |

### F3 · Provider

| WP    | Contenido                                                                                     | Pruebas                                     |
| ----- | --------------------------------------------------------------------------------------------- | ------------------------------------------- |
| F3-01 | Behaviour `Provider`, `Result`, `Chunk`, `Response`; `opts.require` y `opts.context` (G1, G2) | Contrato                                    |
| F3-02 | `ContractTest` genérico                                                                       | Se aplica a todos los behaviours existentes |
| F3-03 | `Provider.Mock` con guion                                                                     | Escenarios de error                         |
| F3-04 | Transporte HTTP/SSE (resultado de G-22)                                                       | Cancelación, contrapresión                  |
| F3-05 | Providers `OpenAI`, `Anthropic`, `Ollama`                                                     | Contra servidor simulado                    |
| F3-06 | `Provider.LlamaCpp` modo `external`                                                           | Contra `llama-server` real                  |
| F3-07 | Salida estructurada §4.2.1                                                                    | Invariante «nunca `nil` en silencio»        |
| F3-08 | Commit de stream y `stream!/2` (§2.9)                                                         | Sin procesos tras `cancel_grace_ms`         |
| F3-09 | Contadores de tokens exactos y registro de `Tokenizer`; límite de adjuntos por tipo           | Contrato                                    |

### F4 · Enrutado

| WP    | Contenido                                                                                           | Pruebas                                                                                                                                                                                                                   |
| ----- | --------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| F4-01 | Router: capas, precedencia, traza                                                                   | Tabla de casos borde §6.10                                                                                                                                                                                                |
| F4-02 | Reglas globales (`when`, `target`, `veto`/`force`/`prefer`), `match_limit`                          | ReDoS                                                                                                                                                                                                                     |
| F4-03 | **Reglas por consumer** (`[[consumers.<id>.rules]]`) y precedencia completa de §6.8.1 (M-01, CE-34) | Un consumer con veto que aplica y sin otro candidato devuelve `:no_candidates` con `:consumer_veto`; veto de consumer gana a `force` global; nombres duplicados → `config_error`; reglas de un consumer no afectan a otro |
| F4-04 | Caché de decisiones (clave con hash de reglas de consumer)                                          | Invalidación al cambiar `[[consumers.*.rules]]`                                                                                                                                                                           |
| F4-05 | `Selector` por consumer                                                                             | Propiedad: un consumer no desplaza a otro                                                                                                                                                                                 |
| F4-06 | `Classifier`, `DecisionSpec`, `DecisionView`                                                        | `DecisionView` nunca contiene RAG, tools, memoria ni `assistant`                                                                                                                                                          |
| F4-07 | Plantilla y parser personalizables; tipos de §6.11                                                  | Contrato del `Classifier`                                                                                                                                                                                                 |
| F4-08 | Agregación Borda                                                                                    | Determinismo                                                                                                                                                                                                              |
| F4-09 | Capa `:embedding`                                                                                   | Verificación como el decisor                                                                                                                                                                                              |
| F4-10 | Harness de evaluación y `Doctor.calibrate_router` con intervalo de Wilson                           | Casos con resultado conocido                                                                                                                                                                                              |
| F4-11 | Estados `:unverified` a `:active`                                                                   | Invalidación por cambio de modelo, spec o rutas                                                                                                                                                                           |
| F4-12 | `Session.last_call` y `Decision.affinity` (G4)                                                      | La afinidad nunca sobrescribe veto, force ni pin                                                                                                                                                                          |

### F5 · Resiliencia y refusal

| WP    | Contenido                                                                   | Pruebas                                                                |
| ----- | --------------------------------------------------------------------------- | ---------------------------------------------------------------------- |
| F5-01 | `Resilience.call/3` con el orden de §2.5                                    | Una prueba por fila de la tabla error→acción                           |
| F5-02 | Plazo total y `attempt_timeout_ms`                                          | Retries y failovers no superan el plazo                                |
| F5-03 | Failover sobre `decision.ranked`                                            | Saltos en `Decision.degraded`                                          |
| F5-04 | Refusal `fail`/`wait`/`degrade`; defecto `wait`                             | `wait` por suscripción; detalles de `:refused_capacity` con `:unknown` |
| F5-05 | Presupuesto con coste de entrada y acumulación; presupuesto jerárquico (G5) | Propiedades; la suma gastada no supera lo asignado arriba              |
| F5-06 | Bulkhead global y por modelo                                                | Saturación                                                             |

### F6 · Ciclo de vida del engine

| WP    | Contenido                                                      | Pruebas                                            |
| ----- | -------------------------------------------------------------- | -------------------------------------------------- |
| F6-01 | `Engine.Backend` y `Backend.Local`                             | Contrato                                           |
| F6-02 | `ArgsBuilder`, flags prohibidos, clave por variable de entorno | Entradas hostiles                                  |
| F6-03 | Arranque, salud, puerto, `Engine.Loader` single-flight         | N peticiones, una carga                            |
| F6-04 | Descarga por inactividad y `resident`                          | Temporizador                                       |
| F6-05 | Caídas y reintentos                                            | Matar el proceso                                   |
| F6-06 | `engines.json` y reconciliación de 5 pasos (§2.8)              | `kill -9` de la VM; PID reutilizado; cierre manual |
| F6-07 | `Gunther.stop/1` y `keep_engines`                              | VRAM liberada                                      |
| F6-08 | `placement.max_loaded_models`                                  | Tope por conteo con expulsión                      |

### F7 · Tools y servidor MCP

| WP    | Contenido                                                                     | Pruebas                          |
| ----- | ----------------------------------------------------------------------------- | -------------------------------- |
| F7-01 | Registro de tools, validación de esquemas, truncado §9.1, `side_effects` (G7) | JSON siempre válido              |
| F7-02 | Bucle de tools y paralelismo                                                  | Presupuesto acumulado            |
| F7-03 | Permisos y confirmación (§9.3) en `chat/2`                                    | `:tool_confirmation_required`    |
| F7-04 | Servidor MCP 2026-07-28 (sin estado)                                          | Cabeceras, `resultType`, errores |
| F7-05 | Modo compatible 2025-11-25 con sesiones y tope                                | Desactivado por defecto          |

### F8 · Contexto

| WP    | Contenido                                                    | Pruebas                                                 |
| ----- | ------------------------------------------------------------ | ------------------------------------------------------- |
| F8-01 | Sesiones por consumer, `open/2` que reabre                   | Aislamiento entre consumers                             |
| F8-02 | `SessionStore` `Memory` y `Disk` con HMAC y cifrado opcional | Alterar un byte ⇒ rechazo                               |
| F8-03 | Memoria KV con autor y versión (G8)                          | `put_new` atómico; `if_version` con `:version_conflict` |
| F8-04 | Compactación                                                 | Nunca se parte un par tool_call/tool_result             |
| F8-05 | Calibración de tokens `approximate`                          | Sin calibración ⇒ no disponible                         |

### F9 · Gateway

| WP    | Contenido                                           | Pruebas                             |
| ----- | --------------------------------------------------- | ----------------------------------- |
| F9-01 | Plug, autenticación, límites                        | Arranque inválido fuera de loopback |
| F9-02 | `/v1/chat/completions` con streaming                | Compatibilidad con clientes OpenAI  |
| F9-03 | `/v1/embeddings`, `/v1/models`, `/v1/gunther/route` | —                                   |
| F9-04 | `/mcp`, `/healthz`, `/readyz`                       | —                                   |

### F10 · Guardrails y evaluación

| WP     | Contenido                                                                         | Pruebas                                     |
| ------ | --------------------------------------------------------------------------------- | ------------------------------------------- |
| F10-01 | Guardrails de input y output, `stream_mode` obligatorio                           | Cada fila de §16.2                          |
| F10-02 | `Eval.run` y métricas de §16.3                                                    | Percentil por rango más próximo             |
| F10-03 | Herramientas de corpus de §16.4 (`capture`, `label`, `synthesize`, `adversarial`) | Estados `:verified` y `:verified_synthetic` |
| F10-04 | Corpus de inyección                                                               | T-01                                        |

### F11 · RAG núcleo, F12 · RAG avanzado

| WP              | Contenido                                                                                                                                                                     |
| --------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| F11-01 a F11-05 | Behaviours, chunkers, embedder por lotes, stores `Memory` y `SQLite` (defecto, G-24, G-26), retriever `Vector`, IDs estables, citas, `rag_query` como tool, `calibrate_rag/2` |
| F12-01 a F12-06 | `search_by_text`, `Lexical`, `Hybrid` (RRF 1-based, `min_score` previo), `MultiQuery`, reranker, store `Postgres` (G-25), reindexado incremental                              |

### F13 · Cliente MCP

| WP     | Contenido                                                 | Pruebas                                   |
| ------ | --------------------------------------------------------- | ----------------------------------------- |
| F13-01 | stdio con `Spawner`, framing y límite de mensaje          | Fuzz de framing                           |
| F13-02 | HTTP con SSRF §9.3                                        | Resolver falso: 302, DNS múltiple, rangos |
| F13-03 | Espacio de nombres, descripciones no confiables, permisos | —                                         |
| F13-04 | Ciclo de vida y reconexión                                | —                                         |

### F14 · Agentes

| WP     | Contenido                                                                               | Pruebas                                                                 |
| ------ | --------------------------------------------------------------------------------------- | ----------------------------------------------------------------------- |
| F14-01 | Bucle y causas de cierre                                                                | Todas las causas de §10.1                                               |
| F14-02 | `AgentStore` con snapshot, `[:safe]` y HMAC                                             | Manipulación                                                            |
| F14-03 | HITL y confirmación de tools; eventos de coral en `handle/2` y supervisión externa (G3) | Reanudar con plazo restante; un agente con `parent:` muere con su padre |
| F14-04 | Sub-agentes y presupuesto heredado                                                      | Profundidad máxima                                                      |

### F15 · Nodos remotos

| WP     | Contenido                                                  | Pruebas                                 |
| ------ | ---------------------------------------------------------- | --------------------------------------- |
| F15-01 | Agente de nodo: API de §18.3, perfiles, límites, auditoría | Overrides fuera de rango                |
| F15-02 | mTLS con huella fijada y rotación                          | Huella equivocada ⇒ `:node_auth_failed` |
| F15-03 | `Node.Client`, `Node.Connection`, latidos, espejo          | Partición                               |
| F15-04 | `Backend.Remote`, leases, reconciliación                   | Caída del controlador y del agente      |
| F15-05 | Proxy de datos y lista de rutas permitidas                 | SSE sin búfer (G-20)                    |
| F15-06 | Colocación entre nodos                                     | Dos controladores compitiendo           |
| F15-07 | Medición de N-07                                           | Publicada                               |

### F16 · Endurecimiento y 1.0

| WP     | Contenido                                                  |
| ------ | ---------------------------------------------------------- |
| F16-01 | Pruebas de carga y caos completas (N-05, N-13, N-14)       |
| F16-02 | Fuzz de parser GGUF, framing JSON-RPC, TOML y regex        |
| F16-03 | Revisión de seguridad con `docs/07-seguridad-checklist.md` |
| F16-04 | Documentación pública, ejemplos ejecutables, `mix docs`    |
| F16-05 | DP4 y `1.0.0`                                              |

## 5. Qué se decide en cada fase y quién

| Decisión                                   | Quién                                    | Cuándo                                   |
| ------------------------------------------ | ---------------------------------------- | ---------------------------------------- |
| Aprobar o rechazar propuestas              | Dueño                                    | DP0 (completado)                         |
| Elegir rama A o B de una puerta            | Dueño, con el resultado del test delante | F0                                       |
| Cambiar un contrato público                | Dueño, con ADR                           | Cuando aparezca; exige revisión del SPEC |
| Detalles de implementación dentro del SPEC | Quien implementa                         | En la fase                               |

## 6. Riesgos del plan y su control

| Riesgo                                  | Control                                                                                                                                                                                |
| --------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Hardware ausente para probar un backend | Fixtures grabados (F0-04) y AC por fixture; la validación en hardware real se registra por backend; un backend sin hardware real validado se declara «sin validar» en la documentación |
| Una puerta cambia el diseño             | Ramas ya escritas; F0-08 produce `r8`                                                                                                                                                  |
| Deriva entre SPEC y código              | Regla 3 de §1; la CI no impide la deriva: la impide la revisión de fase                                                                                                                |
| Alcance                                 | Todo lo fuera del SPEC va a `docs/12-roadmap.md`                                                                                                                                       |

## 7. Fases de la coral y ganchos previos a 1.0

**Ganchos que entran en v1** (SPEC §22.14): G1 `opts.require` (F4); G2 `Gunther.Context` (F1, F3, F14); G3 eventos de coral en `Agent.handle/2` y supervisión externa (F14); G4 `Session.last_call` y `Decision.affinity` (F8, F4); G5 presupuesto jerárquico (F5); G6 prefijo de telemetría (F1); G7 `side_effects` y permisos por rol en tools (F7); G8 autor y versión en `Memory` (F8); G9 behaviours `:coral_mode`, `:consensus`, `:step`, `:run_store` (F18).

| Fase                  | Contenido                                                                  | Paquetes de trabajo                                                                                                                                                          |
| --------------------- | -------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| F18 Base              | `Context`, `Board`, `Run`, `Member`, `Monitor`, mensajería, `RunStore`     | F18-01 Board con CAS y suscripción acotada; F18-02 `Coral.Run` y miembros supervisados; F18-03 mensajería con buzones acotados; F18-04 `RunStore` firmado; F18-05 telemetría |
| F19 Motor del plan    | Pasos, validación, condiciones, consenso, reanudación, despacho por modelo | F19-01 validador; F19-02 tipos de paso; F19-03 condiciones cerradas; F19-04 consenso; F19-05 reanudación y registro de efectos; F19-06 despacho                              |
| F20 Modalidades y DSL | `Mode`, modalidades, datos, TOML, DSL                                      | F20-01 `Mode` y registro; F20-02 `:hive`, `:teamwork`, `:routing_vote`; F20-03 TOML; F20-04 macros; F20-05 propiedad de equivalencia                                         |
| F21 Contexto portable | `Portable`, `on_switch`, afinidad, continuidad                             | F21-01 resumen incremental; F21-02 política; F21-03 afinidad; F21-04 corpus de continuidad                                                                                   |
| F22 Arrea             | Solo si G-28 pasa                                                          | F22-01 anfitrión de miembros; F22-02 pruebas R-A1 a R-A5                                                                                                                     |

La coral se entrega **después de 1.0** (Q-09, Q-13). Los ganchos G1 a G9 entran en v1.

## 8. Cambios de r7 en el plan

- SQLite pasa a F11 (es el store por defecto de uso real); F12 conserva Postgres.
- Cada fase incorpora los añadidos de SPEC §19.1 (ganchos G1 a G9, consumers, convenciones de medida, subconjunto de la API de chat, cuerpos de la API de nodo).
- Puertas G-24 a G-27 en F0-04 y F0-07.

## 9. Cambios de r8 en el plan

- **DP0 cerrado** (2026-10-26). `CIERRE-DP0.md` es el registro.
- **DP1** pasa a siguiente. Recupera el porqué de D-01 a D-47 en ADRs completos.
- **`[[consumers.<id>.rules]]`** (M-01, Q-15): F1-01 añade validación; F4-03 es un WP propio; F4-04 incluye el hash de reglas de consumer en la clave de caché.
- **N-15 = 50 ms p99** (M-02, Q-09): se verifica en F18.
- **Coral sustituye a Hive y Voice** (M-03, Q-13): F18-F22 usan `Gunther.Coral` como nombre.
- **`Arrea.Resource` existe y está publicado** (M-04, Q-14): G-28 sigue verificando si cumple §11.3, pero ya no comprueba su existencia; no bloquea F1.
- **Taxonomía cerrada de skills** (M-06, Q-16): F1-01 valida el catálogo contra la lista cerrada.
