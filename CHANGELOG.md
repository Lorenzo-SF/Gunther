# Cambios

Formato: [Keep a Changelog](https://keepachangelog.com/es-ES/1.1.0/). Versionado: SemVer (SPEC §4.14).

## [Sin publicar]

### F2 en curso: recursos, y los doctests que no se ejecutaban — 2026-10-28

**F2 (recursos), en curso**

- `Gunther.Ggml.Type`: la tabla de tipos de ggml **medida contra `ggml-common.h`**. Los bytes por elemento se leen de la tabla, no se fijan a mano: `f32` 4, `f16` 2, `bf16` 2, `q8_0` 34/32, `q5_1` 24/32, `q5_0` 22/32, `q4_1` 20/32, `q4_0` 18/32. `q8_0` ocupa **1,0625 bytes por elemento**, la mitad que `f16`.
- `Gunther.Gguf`: parser propio de la cabecera GGUF (v2 y v3), con metadatos de todos los tipos, arrays, infos de tensor y `tensor_bytes/1` con la aritmetica de `ggml_nbytes`.
- `Gunther.Resource.Weight`: la formula de KV por capa, con GQA y MHA, `key_length` y `value_length` **por separado**, `type_k` y `type_v` distintos, y MLA y SSM como no aplicables.
- `Gunther.Resource.Ledger`: reescrito con las dos convenciones de medida (A: la del motor; B: la del sistema), memoria ajena, quiescencia y congelacion, memoria unificada, `:no_room` y `:device_unusable`, `reset/0`, `resync/3` y `subscribe/2`.
- `Gunther.Engine.Placer`: elige device con un orden explicito (`prefer`, luego local, luego mayor `available`, luego `physical_id`), margen de 1024 MiB, tope por conteo y los errores `:no_gpu`, `:no_room`, `:memory_unknown` y `:device_unusable`.
- `Gunther.Detector.LlamaCpp` y `Gunther.Detector.Engine`: parsean la salida de `llama-server --list-devices` con el formato **medido en la fuente** (`common/arg.cpp`), y lo ejecutan por `Gunther.Command`, que es la unica puerta de ejecucion.
- `Gunther.Engine.Placement`: el semaforo de colocacion (§11.4), **un proceso por nodo**. Serializa `resync` + `reserve` para que dos arranques concurrentes no midan la misma memoria libre; un nodo ocupado no bloquea a los demas. El turno se concede al proceso que lo pide y se ejecuta **en su propio proceso**: si ese proceso muere con el turno tomado, el semaforo lo libera (monitor) y entra el siguiente; si el que espera en la cola muere, su peticion se descarta. **No** usa `:global.trans/3`: entre varios controladores sobre un mismo nodo manda la autoridad del ledger (§18.5).
- `probes/g10_list_devices.sh`: recoge las salidas reales de `--list-devices` (y de las herramientas del sistema) para los AC que dependen de hardware.

**El `swa_full` por defecto**

- El SPEC §11.5 describe la ventana deslizante como una cota. El defecto **medido** en llama.cpp (`src/llama-context.cpp:4034`) es `swa_full = true`: la ventana se aplica a **todas** las capas y la formula es **exacta**. El codigo usa el defecto real. **Esto pide una revision r10 del SPEC**, con su entrada en el Anexo D; no se toca el SPEC en silencio.

**Los doctests no se ejecutaban**

- De 53 modulos del nucleo con doctests, **solo 4** estaban declarados en un test: **157 doctests nunca se ejecutaron**. Y de los que si se ejecutaban, **42 estaban mal**: hashes inventados, un `kv_mib` con la aritmetica ingenua (la de `ggml_nbytes` da 131_072_000), un `cost_micros` con un factor 1000 de error, una firma de funcion que ya no existia, y cuatro que reventaban.
- Ahora hay `test/gunther/doctests_test.exs`, que declara **todos** los doctests del nucleo (**189**, todos en verde), y `scripts/check_phase.sh` comprueba que todo modulo de `lib/` con un `iex>` esta ahi: un doctest nuevo sin declarar rompe la comprobacion. Un doctest que no se ejecuta es un doctest muerto, y parece documentacion verificada.
- Los doctests con estado global (el registro, el selector, la memoria) usan ahora su propio `consumer`, para que el resultado no dependa del orden de los tests.

**Corregido (bugs reales, ninguno cubierto por tests)**

- **La memoria no escribia nunca.** `Gunther.Memory.Server` tenia las dos ramas de `put/3` **invertidas**: sin `:if_version` comparaba la version actual contra `nil` (siempre distinto) y devolvia `version_conflict` **siempre**; con `:if_version` escribia sin comprobar nada. `put` no escribia, ni la primera vez. No habia ningun test de `if_version`.
- **Las claves de un ambito se filtraban a los demas.** `keys/1` quitaba el prefijo con `String.replace_prefix/3` sobre todas las claves de la tabla: las de otro ambito salian con el prefijo de otro consumidor dentro.
- **`Process.sleep/1` con un valor negativo.** En `Gunther.Resilience.Pipeline`, el backoff se limitaba por `min(capped, remaining)` y `remaining` puede ser negativo si el plazo se agota entre el intento y el calculo: se esperaba una cantidad negativa y reventaba. Intermitente, porque solo pasaba cuando el reloj caia en esa ventana.
- **La lista de permitidos reventaba con una entrada malformada.** `Gunther.Command.AllowList.resolve/2` hacia `entry[:name]` sobre la entrada: si no era un mapa, era `FunctionClauseError` en vez de `:command_blocked`. Ahora una ruta se acepta como nombre y ruta, y cualquier otra forma bloquea.
- **El router y el Placer reventaban con datos mal formados.** `Gunther.Router` accedia a `model.node` y `Gunther.Engine.Placer` a `model.device` directamente: un modelo incompleto era un `KeyError` o un `FunctionClauseError`, no un error.

**El cierre de una fase, mas fuerte**

- `scripts/check_phase.sh` tiene una comprobacion nueva: **todo doctest del nucleo se ejecuta**. Y `scripts/check_ac.sh` distingue los AC **bloqueados** (falta el hardware) y **pendientes** (el trabajo no esta hecho) de los **cumplidos**: un AC bloqueado no es un AC cumplido, y la fase no se cierra.
- El selftest del checker ya no fija el numero de comprobaciones: lo **deriva** de la salida. La misma verdad en dos sitios siempre diverge.

### Correcciones editoriales y de licencia — 2026-10-28

Correcciones solicitadas por el dueño, sin cambio de comportamiento (SPEC Anexo D.5, E-01 a E-06):

- **E-01** — §6.8.1: el bloque TOML de ejemplo pasa a ser **válido** (antes llevaba los marcadores `<id>`) y la precedencia se aclara: **los vetos se acumulan** (el de consumer y el global eliminan candidatos y no chocan entre sí) y ambos prevalecen sobre cualquier `force`. Una restricción de privacidad se expresa como `veto`, nunca como `force`, porque un `force` de consumer prevalece sobre uno global.
- **E-02** — `Arrea.Resource`: la afirmación «existe y está publicado» era falsa. **Existe en `main` según la medición del dueño (D-13); su publicación en Hex está pendiente de G-28.** Corregido en §1.4, §3.2, §11.3, §21, Anexos B y D, y en los ADR 48 y 91.
- **E-03** — *Superada*: decía que F0 no estaba iniciado. F0 y F1 están cerrados desde el 2026-10-28 y r9 lo refleja.
- **E-04** — §19 y Anexo C: el recuento de puertas de F0 era 31 y son **32** (G-01 a G-31, con G-06b).
- **E-05** — Regla final: «El juego se considera terminado por evidencia» → «Una fase se considera terminada por evidencia (sus AC ejecutados)», alineado con D-10.
- **E-06** — `LICENSE` con el **texto oficial e íntegro** de Apache-2.0 (verificado byte a byte contra `apache.org`), `NOTICE` con año y titular, `.gitignore` y fuera los `.DS_Store` que estaban versionados.

### Toolchain, cierre de F1 y el `reason` del router — 2026-10-28

**Toolchain**

- Erlang **28.5.0.7** y Elixir **1.19.5-otp-28**, los mismos que `ropero` (instruccion del dueño). `.tool-versions`, la CI y el SPEC (**r9**) quedan fijados en esa combinacion. La matriz de CI con OTP 27 y 28 desaparece: un solo toolchain para todo el ecosistema.

**El `reason` de la decision**

- El `reason` ahora distingue `:veto` y `:force` de `:rule`, como pide la enumeracion de §4.13. Un veto es seguridad y su motivo se ve; un force es el operador y el suyo tambien. `layers_ran` sigue diciendo que capas corrieron: son dos cosas distintas. **Esto cambia un contrato publico.**

**El cierre de una fase, ejecutable**

- `scripts/check_phase.sh F1` y `scripts/check_ac.sh docs/fases/F1.md`: una fase no se da por cerrada porque compile y los tests passen. Los AC de §19 se ejecutan **por test** (un AC sin test es un AC sin cumplir) y diez comprobaciones de calidad haruscan en verde: la suite con el **resumen visible** (un `mix test` cuyo formateador revienta no imprime resumen y no puede darse por bueno), tres corridas seguidas sin intermitencia, Credo **sin filtrar por prioridad**, Dialyzer, compilacion sin warnings, fronteras, lint de documento, paquete limpio y el SPEC sin cambios respecto a la version aprobada.
- **Corregido**: el checker de fases se tragaba sus propios fallos. Tres comprobaciones usaban `return 1` dentro de un `eval` y una usaba `exit 0`; un `return` o un `exit` dentro de un `eval` aborta la funcion que lo contiene, asi que la comprobacion **desaparecia del informe** en vez de marcarse FALLA y el script salia con 0. Un verde falso con el informe a medias. Las diez comprobaciones son ahora funciones que devuelven su codigo de salida, y `scripts/check_phase_selftest.sh` las prueba con dobles: que en verde salgan las diez, y que una en rojo aparezca marcada como FALLA con las otras nueve en verde y el script exiting con 1.
- `docs/fases/F1.md`: la nota de fase con la tabla **AC -> test**.

**Corregido**

- El hash del catalogo cubria el nombre de las reglas y el `id` de los `DecisionSpec`, no su contenido: cambiar el `target`, la `action`, el `when` o las rutas de un spec dejaba el hash igual y la cache seguia sirviendo un ranking invalidado.
- La puerta G6 (prefijo `[:gunther, :coral]` reservado) no era una reserva: el puente aceptaba ese prefijo. Ahora **se niega a arrancar** con el, y el error es un valor.
- Un AC de F1 no tenia test: el reensamblado de `:noeol` con mensajes mayores que el bufer de linea (CE-20). Ahora lo tiene.
- Un consumer sin `default_model` es `config_error` (AC de r7), y ahora tiene test.
- `Gunther.Context` no tenia test.

**Nota sobre el formatter de ExUnit**

- Un `assert` sobre 100.000 caracteres **revienta el formateador** de ExUnit: el `mix test` termina con codigo 1 pero **sin imprimir el resumen**, y el que lo lee no ve el fallo. El test compara longitud y hash.

### F1 — las seis capas del router, el provider de mentira y el contrato — 2026-10-28

**Añadido**

- Capa `:cache` del router (§6.1, §6.5): lee el ranking puro de la cache de decisiones antes de las capas blandas. Lo que se cachea es el ranking, no la decision: la disponibilidad (breaker, bulkhead, ledger) se reevalua en cada peticion.
- `Gunther.Cache.Store`: el contrato de la cache, para que la capa se pueda probar sin un proceso global. `Gunther.Cache.Decisions` lo cumple.
- `Gunther.Router.Requirements`: la firma de requisitos (modalidades, herramientas, `response_format`, skills y `rag`) que forma parte de la clave de §6.5.
- `Gunther.Router.Embedding`: la capa `:embedding`. Compara el prompt con las skills de los candidatos por coseno y ordena por similitud. Sin embedder registrado la capa no existe (§6.10); sin verificar no acts (§6.11) y deja el aviso `:classifier_unverified`.
- `Gunther.Catalog.Server.reload/1`: recarga el catalogo desde la configuracion activa, conserva el snapshot anterior si la nueva no valida, y **vacia la cache de decisiones** (§6.5). `hash/1` da el hash del catalogo activo.
- `Gunther.Provider.Mock`: un provider de mentira para probar el motor sin un `llama-server` delante. Es determinista, se configura por llamada (`:mock` con `:text`, `:delay_ms`, `:error` y `:usage`), rechaza las entradas malas con `{:error, :invalid_request}` en vez de lanzar, y **aborta en cuanto se cancela**, sin esperar a terminar la llamada.
- `Gunther.ContractTest`: `use Gunther.ContractTest, behaviour: B, module: M` genera los tests que comprueban que un modulo cumple el contrato: la forma del retorno, la robustez ante una entrada mala, el determinismo y la cancelacion (§5.14). El mock se prueba con el, para que no se desvie.

- Capa `:llm` del router (§6.1, §6.3, §6.11, §6.12): la ultima capa blanda, la que llama a un **modelo de decision especializado**. `router.llm` decide si la capa existe: `never` la quita, `fallback` (defecto) la deja correr solo si las baratas no resolvieron, `always` la corre siempre.
- `Gunther.Decision.Prompt` y `Gunther.Decision.Parse`: la plantilla de la peticion y el interprete de la salida, los dos **personalizables** (D-72). La plantilla incorporada pone el prefijo estatico (las rutas) primero y el texto del usuario al final, para que la cache de prompt del servidor sirva.
- `Gunther.Router.Llm.Bulkhead`: el limite de concurrencia del modelo de decision (control M7). Un flujo de peticiones no puede saturar al decisor.
- `Gunther.DecisionSpec`: el estado de verificacion (`:unverified`, `:active`, `:failed`), el `report_id` y el `max_concurrency`.

**Fijado**

- La capa `:rule` corta cuando opino (§6.10): un `veto` o un `prefer` que casa resuelve, y `:embedding` y `:llm` no corren.
- **La autoridad del decisor es acotada** (control M1): su salida se intersecta con el conjunto elegible, lo que dice **no crea atomos nuevos** y una etiqueta desconocida es una etiqueta desconocida.
- **La decision se abstiene, no se adivina** (control M4): una salida invalida, una ruta `other` sin destino o una ruta cuyos modelos no son elegibles son una abstension, y la decision sigue con el fallback.
- El decisor solo ve el `DecisionView` (control M2): texto de autoria del caller con los roles de `context_roles`, truncado a `max_input_tokens`.
- El veto y el force se aplican antes de la cache y un hit no los salta.
- Sin hash de catalogo no hay cache: sin el no hay forma de invalidarla.

**Corregido**

- El hash del catalogo cubria el nombre de las reglas y no su contenido: cambiar el `target`, la `action` o el `when` de una regla dejaba el hash igual y la cache seguia sirviendo un ranking invalidado. La huella es ahora la regla entera, canonicalizada.
- `Catalog.reload/0` llamaba a un `handle_call` que no existia: reventaba en vez de recargar.
- `Config.Server.get/1` hacia `exit` si el servidor no estaba arrancado. Ahora devuelve `nil`.
- La cache de decisiones reventaba si el proceso no estaba arrancado. Ahora un `miss` es un `miss`.

### F0 y F1 — 2026-10-27

Cierre de F0 (puertas medidas) y primer nucleo de F1.

**Añadido**

- Nucleo de la libreria: `Gunther.Error`, `Gunther.Response`, `Gunther.Decision`, `Gunther.Config` (con carga, validacion y servidor), `Gunther.Cache` (LRU exacto con dos ETS), `Gunther.Command` (unica puerta de ejecucion, con lista de permitidos y `Spawner`), `Gunther.Resilience`, `Gunther.Catalog`, `Gunther.Placement`, `Gunther.Provider`, `Gunther.Embedder`, `Gunther.Chunker`, `Gunther.Retriever`, `Gunther.Reranker`, `Gunther.QueryRewriter`, `Gunther.Classifier`, `Gunther.Selector`, `Gunther.Store`, `Gunther.Guardrail`, `Gunther.Tokenizer`, `Gunther.Detector`, `Gunther.SessionStore`, `Gunther.Memory`, `Gunther.Resource.Ledger`, `Gunther.Telemetry.Bridge` y `Gunther.DecisionView`.
- Configuracion: `Gunther.Config.Validator` valida el esquema completo (secciones del SPEC §14) y distingue la clave desconocida como aviso (D-26) de la seccion de seguridad, donde es `config_error`.
- Puerta de ejecucion: `Gunther.Command` es la unica forma de lanzar un proceso en Gunther. `scripts/check_boundaries.sh` lo verifica y CI lo ejecuta.
- Probes de F0: `probes/` con un script reproducible por puerta y las salidas integrias en `probes/output/`.
- `docs/13-registro-de-fases.md`: las 11 puertas medidas (G-01 a G-07, G-16, G-17, G-21, G-23) con procedimiento, salida, resultado y rama aplicada.
- `.credo.exs`, `config/config.exs` y el trabajo de CI por capas (L1 a L4).

**Fijado**

- `{:arrea, "~> 3.1"}`: es la unica version resoluble junto a `trebejo` publicado, y cumple el `~> 3.0` del SPEC. La insignia del README de `arrea` dice 3.0.0 y lo publicado es 4.0.0 (puerta G-17, rama B).
- `Apero.Retry` no se usa: no admite el `retry_after` que dicta el servicio. El retry de §2.5 vive en `Gunther.Resilience` (puerta G-05, rama B).
- `Trebejo.SafeCommand` no se usa: carga la configuracion del shell y no distingue el caso destructivo del de solo lectura. `Gunther.Command` fuerza `/bin/sh` y exige lista de permitidos (puerta G-06, rama B).

**Nota**

- `Apero.Llm` no existe en `apero` 4.1.0: la puerta G-21 se cierra sin rama por ausencia de solapamiento, no por auditoria propia.

### SPEC-000-GUNTHER r8 — 2026-10-26

Cierre de DP0 y apertura de F0. Cambios acotados respecto a r7 (M-01 a M-11 y CE-34).

**Añadido**

- `[[consumers.<id>.rules]]`: reglas por consumer con la misma forma que `[[rules]]` (M-01, Q-15).
- Nueva §6.8.1 en el SPEC: precedencia completa de reglas (consumer → global → `default_model`).
- Nueva §1.7 en el SPEC: estado de las decisiones por bloque.
- Nueva §22.1 con `Gunther.Coral` como nombre definitivo (M-03, Q-13).
- `CE-34`: cierre de especificación de D-09 y D-87 (sintaxis y precedencia de reglas de consumer).
- Anexo D del SPEC: cambios de r7 a r8.
- `CIERRE-DP0.md` en la raíz: registro histórico del cierre de DP0.

**Cambiado**

- D-48 a D-92: estado `propuesta` → `aceptada` (DP0 cerrado).
- D-30, D-46, D-56: sustituidas por D-74 en lo relativo a «colmena / mesa camilla / voz» (M-03).
- D-48 y D-91: nota de Q-14 (ledger propio en v1; `Arrea.Resource` existe y está publicado). **[Corregido en r9, E-02: solo existe en `main`; la publicación en Hex está pendiente de G-28.]**
- §1.3: tabla de conceptos renombrada (coral, miembro, plan, pizarra).
- §1.4 y §1.5: notas a D-30, D-46, D-48, D-56, D-91.
- §3.2: fila `Arrea.Resource` actualizada con Q-14.
- §4.9: API de la coral (`Gunther.Coral.run/2`, `await/2`, `status/1`, `events/1`, `resume/2`, `cancel/1`, `register_mode/3`, `list_modes/0`).
- §5: introducción con los cuatro behaviours nuevos de la coral (`:coral_mode`, `:consensus`, `:step`, `:run_store`).
- §6.5: hash del catálogo incluye reglas de consumer.
- §6.10: tres filas nuevas (consumer con `default_model` vetado; consumer no declarado; nombre de regla duplicado).
- §15.2 T-15: las reglas de consumer no pueden vetar candidatos de otro consumer.
- §17 N-15: valor fijado a 50 ms p99 (M-02, Q-09).
- §19 F4: AC ampliados con precedencia de reglas de consumer.
- §21: Q-01 a Q-16 cerradas con las respuestas del dueño.
- §22.1: estado «aprobada»; coral como modalidad de la infraestructura integrada.
- §22.19: sin pendientes del dueño.

**Documentación**

- `README.md`: estado actualizado a «en diseño — DP0 cerrado, F0 en ejecución».
- `docs/00-indice.md`: referencia a r8; añadido `CIERRE-DP0.md`; nota sobre el gap intencional de `docs/14-*.md`.
- `docs/01-plan-de-desarrollo.md`: DP0 marcado como completado el 2026-10-26; DP1 pasa a siguiente.
- `docs/02-proceso-de-desarrollo.md`: §5 aclara que DP0 se cerró con `CIERRE-DP0.md`, no con ADRs individuales.
- `docs/03-estrategia-de-pruebas.md`: nuevo caso obligatorio para reglas de consumer con veto del `default_model`.
- `docs/04-f0-puertas.md`: nueva sección de política de ejecución (`PASA` / `FALLA` / `BLOQUEADA con rama B provisional`).
- `docs/05-estructura-del-repositorio.md`: `CIERRE-DP0.md` añadido al árbol.
- `docs/06-guia-de-operacion.md`: nueva §10 «Reglas por consumer».
- `docs/07-seguridad-checklist.md`: punto 13 ampliado con el aislamiento de reglas entre consumers.
- `docs/08-decisiones/README.md`: D-48 a D-92 a `aceptada`; notas de renombrado.
- `docs/09-trazabilidad.md`: nuevas filas (reglas por consumer; N-15 = 50 ms p99).
- `docs/12-roadmap.md`: coral marcada «aprobada, v1.1+, con G1–G9 en v1».
- `docs/13-registro-de-fases.md`: fila DP0 completa.
- `docs/15-matriz-de-puertas.md`: nota sobre G-28 y Q-14.
- ADRs D-02, D-30, D-46, D-48, D-56, D-87, D-91: notas de ratificación y renombrado.
- `examples/gunther.example.toml`: sección de ejemplo `[[consumers.<id>.rules]]`.

### SPEC-000-GUNTHER r7 — 2026-10-26

**Añadido**

- §22 completa: la coral (colmena y equipo como modalidades), DSL, pizarra, mensajería, consenso, contexto portable, evoluciones propuestas para Arrea.
- §18 completa: nodos remotos.
- §12 a §17: gateway, telemetría, configuración, modelo de amenazas, guardrails y evaluación, requisitos no funcionales.
- §19, §20, §21: fases con AC, riesgos y deuda, preguntas abiertas.
- Anexos A, B, C: cambios, cierres y hallazgos, verificaciones y puertas.
- ADRs D-74 a D-86 (adenda de la coral) y D-87 a D-92 (resoluciones por delegación del dueño).

**Cambiado**

- §8: RAG completo con siete piezas, `rag_query` como tool, `store_backend`, SQLite por defecto, `calibrate_rag/2`.
- §11: convenciones A y B de medida, estados de la reserva, reintento en otro device, capas enteras, presupuesto jerárquico.
- §12.2: límite del gateway con adjuntos.
- §12.3: subconjunto de la API de chat.
- §14.1: `[consumers.*]`, `[[rules]]`, `[[decision_models]]`, `[rag]`, `[coral]`, `[context]`.
- §15.2: T-25 añadido.
- §18.3.1: cuerpos de la API de nodo.

### SPEC-000-GUNTHER r6 — 2026-10-25

**Añadido**

- §0.6: regla de no-suposición y lint de documento.
- §3.4: contrato `Spawner`, lista de permitidos con `realpath` e inodo, `ArgsBuilder` sin líneas libres.
- §4.2.1: salida estructurada con fallback.
- §6.11 y §6.12: modelos de decisión especializados y seguridad del router.
- §9: MCP en la revisión 2026-07-28 con modo compatible 2025-11-25; SSRF; permisos y confirmación.
- §11.7 y §11.8: backends GPU y matriz de capacidades; identidad física, memoria unificada, coherencia.
- §18: nodos remotos.
- §22: la coral.
- ADRs D-63 a D-73.

**Cambiado**

- Renombrado completo Candil → Gunther (D-63).
- Fórmula de KV corregida por tipo de atención (CE-24).
- `foreign` redefinido (CE-23).
- Coste de entrada incluido en el presupuesto (CE-25).
- Modo compatible de MCP con sesiones y tope (CE-H15).
- Sección de seguridad: clave desconocida es error (CE-H11).

### SPEC-000-GUNTHER r5 — histórico

Primera versión completa del SPEC. No se mantiene en este CHANGELOG; el detalle está en `SPEC-000-GUNTHER_r7.md`, Anexo A.

### r4 y anteriores — histórico

Renombrado desde Candil. Ver `docs/08-decisiones/` para el histórico de decisiones.
