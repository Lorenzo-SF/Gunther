# Registro de decisiones

Plantilla: `plantilla.md`. Estados: propuesta, aceptada, rechazada, sustituida.

## Cómo se leen los ADR de D-01 a D-28

Están adaptados del documento original de `08-decisiones` (decidido hasta 2026-10-21) **sin cambiar su contenido**: se comprobó línea a línea que ninguna falta. Solo se aplicó el renombrado a Gunther (D-63) y los nombres nuevos (`Detector.Devices` → `Detector.LlamaCpp`, `Scheduler` → Selector y Placer), se quitaron las marcas «✓» de la última pasada de revisión y se eliminó una repetición accidental en D-08. Las referencias al CLI, a las fases numeradas del plan anterior y a ficheros del repositorio anterior describen el estado en la fecha de cada decisión. Cada ADR sustituido lleva al principio una nota «Sustituida por D-xx».

## D-01 a D-28

Estado: aceptada, salvo D-02 (taxonomía de skills), que no está en el documento original y se extrajo del SPEC (propuesta). Los ⚠️ de cada ADR son incoherencias con el SPEC r6 para resolver entre el dueño y el revisor; no se han resuelto aquí.

| Decisión | Estado |
| --- | --- |
| [D-01 — El centro de gravedad: el enrutado, no la GPU](ADR-01.md) | aceptada |
| [D-02 — Taxonomía de skills cerrada](ADR-02.md) | propuesta |
| [D-02b — `exclusive` es una propiedad del destino, no un interruptor](ADR-02b.md) | aceptada |
| [D-03 — La capacidad en megas enteros, la cuota en decimal](ADR-03.md) | aceptada |
| [D-04 — El ejemplo de la GPU parecía mal y no lo estaba](ADR-04.md) | aceptada |
| [D-05 — Las siete hermanas desde su `main`, no desde Hex](ADR-05.md) | aceptada |
| [D-06 — Sin clasificador ni embedder por defecto](ADR-06.md) | aceptada |
| [D-07 — El enrutado sube de fase, y el gateway baja al 8](ADR-07.md) | aceptada |
| [D-08 — `one_for_all` y `rest_for_one` se escribieron como si fueran distintos](ADR-08.md) | aceptada |
| [D-09 — El refusal se configura, no se decide de una vez](ADR-09.md) | aceptada |
| [D-10 — Una fase no se cierra por el CLI, ni por los tests, ni por un verde](ADR-10.md) | aceptada |
| [D-11 — Lo que NO se decidió, y por eso está escrito](ADR-11.md) | aceptada |
| [D-12 — Gunther manda la pregunta; la respuesta no es suya](ADR-12.md) | aceptada |
| [D-13 — La frontera con Arrea: lo que Arrea usa, o lo que piden dos](ADR-13.md) | aceptada |
| [D-14 — «Agente» significa una sola cosa: el proceso; la mesa tiene voces](ADR-14.md) | aceptada |
| [D-15 — El scheduler: round-robin justo por defecto, prioridad como peso](ADR-15.md) | aceptada |
| [D-16 — La verdad de la VRAM: Arrea mide, Gunther consume y decide](ADR-16.md) | aceptada |
| [D-17 — `Gunther.Provider`: registro, no lista cerrada](ADR-17.md) | aceptada |
| [D-18 — El camino de librería: fuera de las fases](ADR-18.md) | aceptada |
| [D-19 — `rest_for_one`: no se implementa](ADR-19.md) | aceptada |
| [D-20 — El breaker de crashes: ETS persistente + `restart: :transient`](ADR-20.md) | aceptada |
| [D-21 — `:degrade` se mantiene declarado y se reinterpreta al existir la cobertura](ADR-21.md) | aceptada |
| [D-22 — La memoria común: un mapa clave→valor, no historial](ADR-22.md) | aceptada |
| [D-23 — Ya decidida: = D-21](ADR-23.md) | aceptada |
| [D-24 — Ya decidida: = D-19](ADR-24.md) | aceptada |
| [D-25 — El breaker de los agentes sin nombre](ADR-25.md) | aceptada |
| [D-26 — El cargador del catálogo avisa de claves desconocidas](ADR-26.md) | aceptada |
| [D-27 — Quién elige el device y cómo se le dice al motor](ADR-27.md) | aceptada |
| [D-28 — Qué es un «device» y de dónde salen sus cifras](ADR-28.md) | aceptada |

## D-29 a D-47

Extraídas del SPEC r6. Aceptadas por el dueño: D-34, D-35, D-36, D-38, D-41 y D-44; el resto sigue en **propuesta** hasta DP0.

| Decisión | ADR | Estado |
| --- | --- | --- |
| D-29 El LLM decide (capa `:llm`) | [ADR-29.md](ADR-29.md) | propuesta |
| D-30 «Mente colmena» como nombre | [ADR-30.md](ADR-30.md) | propuesta |
| D-31 Framework sin CLI | [ADR-31.md](ADR-31.md) | propuesta |
| D-32 Tool-calling de primera clase | [ADR-32.md](ADR-32.md) | propuesta |
| D-33 Salidas estructuradas | [ADR-33.md](ADR-33.md) | propuesta |
| D-34 Multimodal passthrough y límite de adjuntos | [ADR-34.md](ADR-34.md) | aceptada |
| D-35 MCP con transporte propio | [ADR-35.md](ADR-35.md) | aceptada |
| D-36 RAG completo | [ADR-036-rag.md](ADR-036-rag.md) | aceptada |
| D-37 Sesiones como contrato | [ADR-37.md](ADR-37.md) | propuesta |
| D-38 Prompts versionados con plantillas EEx | [ADR-38.md](ADR-38.md) | aceptada |
| D-39 Evaluación como contrato | [ADR-39.md](ADR-39.md) | propuesta |
| D-40 Guardrails | [ADR-40.md](ADR-40.md) | propuesta |
| D-41 Reparto en v1 (Selector + Placer) | [ADR-41.md](ADR-41.md) | aceptada |
| D-42 Cancelación propagada | [ADR-42.md](ADR-42.md) | propuesta |
| D-43 Contexto gestionado | [ADR-43.md](ADR-43.md) | propuesta |
| D-44 Caché de completions (retirada de v1) | [ADR-44.md](ADR-44.md) | aceptada |
| D-45 Registry por instancia | [ADR-45.md](ADR-45.md) | propuesta |
| D-46 Contrato de voces | [ADR-46.md](ADR-46.md) | propuesta |
| D-47 Integración con el ecosistema | [ADR-47.md](ADR-47.md) | propuesta |

## D-48 a D-73

| Decisión | Estado |
| --- | --- |
| [D-48 — Ledger de recursos propio](ADR-48.md) | propuesta |
| [D-49 — Un paquete, dependencias opcionales y CI de fronteras](ADR-49.md) | propuesta |
| [D-50 — Ejecución de comandos en dos modos](ADR-50.md) | propuesta |
| [D-51 — Pipeline de resiliencia con orden fijo](ADR-51.md) | propuesta |
| [D-52 — Failover entre candidatos](ADR-52.md) | propuesta |
| [D-53 — Selector y Placer separados](ADR-53.md) | propuesta |
| [D-54 — MCP en la revisión 2026-07-28 con compatibilidad 2025-11-25](ADR-54.md) | propuesta |
| [D-55 — La caché de decisiones guarda solo el ranking puro](ADR-55.md) | propuesta |
| [D-56 — Colmena a v1.1 experimental](ADR-56.md) | propuesta |
| [D-57 — Warnings en `Response`; `:degraded` deja de ser error](ADR-57.md) | propuesta |
| [D-58 — Behaviour `Tokenizer`](ADR-58.md) | propuesta |
| [D-59 — Behaviour `Detector`](ADR-59.md) | propuesta |
| [D-60 — Modelo de amenazas; gateway en loopback por defecto](ADR-60.md) | propuesta |
| [D-61 — Parada que apaga engines propios; reaper por marca](ADR-61.md) | propuesta |
| [D-62 — `chat/2` y `tell/2` en lugar de `send/2`](ADR-62.md) | propuesta |
| [D-63 — El proyecto se llama Gunther](ADR-63.md) | propuesta |
| [D-64 — Regla de no-suposición y lint de documento](ADR-64.md) | propuesta |
| [D-65 — Identidad física de dispositivos y detector por defecto del propio engine](ADR-65.md) | propuesta |
| [D-66 — Nodos remotos gestionados](ADR-66.md) | propuesta |
| [D-67 — Perfiles de engine definidos en el nodo](ADR-67.md) | propuesta |
| [D-68 — Modelos de decisión especializados con autoridad acotada](ADR-68.md) | propuesta |
| [D-69 — Backends GPU soportados en v1](ADR-69.md) | propuesta |
| [D-70 — Contrato `Spawner` para procesos largos](ADR-70.md) | propuesta |
| [D-71 — Alcance fijado por el dueño](ADR-71.md) | propuesta |
| [D-72 — Decisor agnóstico y personalizable; verificación relativa a línea base](ADR-72.md) | propuesta |
| [D-73 — Publicación y contribución](ADR-73.md) | propuesta |


## D-74 a D-86 (adenda de la coral)

Propuestas del 2026-10-26; detalle en SPEC §22.

| Decisión | Estado |
| --- | --- |
| [D-74 — La coral (colmena y equipo como modalidades)](ADR-74.md) | propuesta |
| [D-75 — Un solo plan; tres vías; condiciones cerradas](ADR-75.md) | propuesta |
| [D-76 — Terminación garantizada y despacho por modelo](ADR-76.md) | propuesta |
| [D-77 — Pizarra de ejecución](ADR-77.md) | propuesta |
| [D-78 — Mensajería nativa de OTP; Arrea como anfitrión opcional](ADR-78.md) | propuesta |
| [D-79 — Consenso como behaviour](ADR-79.md) | propuesta |
| [D-80 — Sobre de contexto `Gunther.Context`](ADR-80.md) | propuesta |
| [D-81 — Contexto portable y política de cambio de modelo](ADR-81.md) | propuesta |
| [D-82 — Afinidad de caché en el router](ADR-82.md) | propuesta |
| [D-83 — Reanudación al menos una vez con registro de efectos](ADR-83.md) | propuesta |
| [D-84 — Planes dinámicos (`expand`)](ADR-84.md) | propuesta |
| [D-85 — Ganchos G1 a G9 antes de 1.0](ADR-85.md) | propuesta |
| [D-86 — Evoluciones propuestas para Arrea](ADR-86.md) | propuesta |

## D-87 a D-92 (resoluciones de r7, por delegación del dueño)

| Decisión | Estado |
| --- | --- |
| [D-87 — Sección `[consumers.<id>]`](ADR-87.md) | propuesta |
| [D-88 — Defecto del refusal y reglas invariantes](ADR-88.md) | propuesta |
| [D-89 — Colocación y medida: reserva, reintento, capas y fuente única](ADR-89.md) | propuesta |
| [D-90 — Memoria con autor y versión; evento de calidad](ADR-90.md) | propuesta |
| [D-91 — Precedencias entre D-01 a D-28 y r7](ADR-91.md) | propuesta |
| [D-92 — Resoluciones del RAG y de los adjuntos](ADR-92.md) | propuesta |

## Incoherencias entre D-01 a D-28 y el SPEC r6

**Todas resueltas en r7** (D-87 a D-91; ver Anexo B.3 del SPEC). Se conserva la tabla como registro. Quedan dos premisas por confirmar con el dueño: la existencia de `Arrea.Resource` (Q-14) y la interpretación de los tres niveles de D-09 (Q-15).

| # | ADR | Qué choca con el SPEC r6 | Sección r6 | Tipo |
| --- | --- | --- | --- | --- |
| J-00 | D-02 | La taxonomía de skills no está en el documento original (allí D-02 es `exclusive`) | §1.3, §1.4 | decisión |
| J-01 | D-01 | Scheduler aparcado y destinos `:local/:remote/:external` frente a reparto en v1 y `locality`/`node` | §6.8, §18, D-41, D-53 | incoherencia |
| J-02 | D-03 | Cuota decimal de `Arrea.Resource` frente a ledger propio | §11.3, D-48 | incoherencia |
| J-03 | D-05 | Hermanas desde `main` con `override` frente a versiones de Hex | §0.3, §3.7 | incoherencia |
| J-04 | D-09, D-11 | «El defecto no está puesto» frente a `policy = "wait"` | §14.1 | incoherencia |
| J-05 | D-09 | `[consumer.X]` con `model_default` obligatorio frente a ausencia de la sección | §14.1, §4.2 | incoherencia |
| J-06 | D-12 | `Telemetry.Quality` frente a eventos de §13.1 sin esa métrica | §13.1 | incoherencia |
| J-07 | D-13 | `Arrea.Resource` existe y está publicado frente a «no verificado» | §3.2, D-48 | incoherencia |
| J-08 | D-15 | `[consumer.X] priority` y envejecimiento frente a «prioridad como peso» sin definir | §5.8, §14.1 | incoherencia |
| J-09 | D-18 | CLI con su fase frente a «sin CLI» | §1.1, D-31 | incoherencia |
| J-10 | D-20 | Agente con circuito abierto no reinicia frente a regla retirada | §10.1 | incoherencia |
| J-11 | D-22 | `meta.author`, `superseded_by` y `mem:*` común frente a espacio por consumer | §7.2 | incoherencia |
| J-12 | D-27 | Entero de capas calculado frente a `llama-fit-params` o `--fit on` | §11.1, §11.5 | incoherencia |
| J-13 | D-27 | Reserva = peso real frente a peso más margen | §11.3 | incoherencia |
| J-14 | D-27 | Reintento en otro device frente a failover entre modelos | §11.1 | incoherencia |
| J-15 | D-28 | Una sola fuente de medida frente a `:per_process` con otra herramienta | §11.3 | incoherencia |
| J-16 | D-28 | Overhead calibrado por backend frente a ninguna calibración | §11.3 | incoherencia |

Dos premisas se repiten y conviene resolverlas primero: la existencia de `Arrea.Resource` (J-02, J-07), que decide si D-48 mantiene su ledger propio, y la ausencia de `[consumer.X]` (J-05, J-08).

## Cambios para r7 (decisiones D-29 a D-47): **aplicados en r7**

Recogidos de los ADR (el detalle está en cada uno). «Abierta» = el SPEC r6 debe cambiar; «decisión» = falta un dato del dueño.

| # | Sección r6 afectada | Cambio | Origen | Estado |
| --- | --- | --- | --- | --- |
| I-01 | §8.3, §14.1, §14.2, §19 | `min_score` con defecto `0.0` | D-36 | aplicada en r7 |
| I-02 | §7.4, §8.6, §14.1 | `store_backend`; `shared` es `config_error` en v1 | D-36 | aplicada en r7 |
| I-04 | §4.7, §9.1 | Tool `rag_query` y `tool_enabled` | D-36 | aplicada en r7 |
| I-05 | §5.9, §8.6 | `ETS` no es store del RAG | D-36 | aplicada en r7 |
| I-07 | §4.12, §16.3 | `calibrate_rag/2` con F1@5 | D-36 | aplicada en r7 |
| I-08 | §4.7 | Esquema de la tool sin módulos | D-36 | aplicada en r7 |
| I-11 | §14.1 `[rag]` | `strategy`, `tool_enabled`, `store_backend`, store por defecto | D-36 | aplicada en r7 |
| I-12 | §19 F11/F12 | ¿SQLite pasa a F11? | D-36 | resuelta (D-92) |
| I-13 | §15 T-15, §9.3 | Índice común y aviso de `Doctor` | D-36 | aplicada en r7 |
| I-14 | §2.4 | Formulación de la puerta 3 | D-36 | resuelta (D-92) |
| I-15 | §6.11 | Política de `router.embedding.min_similarity` | D-36 | resuelta (D-92) |
| I-16 | Anexo C | Puertas G-24, G-25, G-26, G-27 | D-36, D-35 | aplicada en r7 |
| I-18 | `docs/06`, `docs/08` | Guía de operación del RAG | D-36 | aplicada en r7 |
| I-19 | §4.2, §4.13, §14.1 | `max_attachment_bytes` y `attachment_too_large` | D-34 | aplicada en r7 |
| I-20 | §12.2 | `gateway.max_body_bytes` frente a adjuntos de 20 y 50 MiB | D-34 | resuelta (D-92) |
| I-21 | §4.11, §15 | EEx, reglas de seguridad y amenaza nueva | D-38 | aplicada en r7 |
| I-22 | §1.4, §2.1 | Renombrar D-41 | D-41 | aplicada en r7 |
| I-23 | §2.3, §3.3 | Quitar `Cache.Completions` | D-44 | aplicada en r7 |
| I-24 | §5.3 | Tamaño máximo de chunk en `Chunker` | D-36 | aplicada en r7 |
| I-25 | §14.1, §4.12, §15 | Registro de consumers para el aviso de `Doctor` | D-36 | aplicada en r7 |
| I-26 | Anexo C | Puerta G-27 (SDK de MCP existentes) | D-35 | aplicada en r7 |
| — | D-35 | Confirmar el motivo de «transporte propio» (existe `snodo` 0.2.0) | D-35 | resuelta (D-92) |

Cerradas por las decisiones del dueño y sin cambio en el SPEC: I-03, I-06, I-09, I-10, I-17.

## Frases del documento original

**La frase que resume todo**:
> Las decisiones abiertas se cierran registrando la respuesta y el porqué, no
> implementando lo que aún no tiene caso. El código llega cuando la decisión
> tiene un consumidor que lo pida.

**La frase que resume todo** (ampliada):
> Las decisiones abiertas se cierran registrando la respuesta y el porqué, no
> implementando lo que aún no tiene caso. El código llega cuando la decisión
> tiene un consumidor que lo pida. Y un campo que nadie rellena no es un
> campo: es una mentira con nombre. **Y un `-1` que depende de un `--fit`
> que nadie controla no es una decisión: es una delegación.**
