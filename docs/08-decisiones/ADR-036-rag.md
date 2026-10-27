# ADR D-36 — RAG completo

- **Estado**: aceptada (respuestas del dueño P-1 a P-8; ver las filas abiertas de la tabla final)
- **Fecha**: 2026-10-25
- **Fuente**: SPEC-000-GUNTHER r6 §8, §4.7, §7.4, §9.1, §14.1; respuestas del dueño 8a a 8e y P-1 a P-8
- **Sustituye** a las versiones anteriores de este fichero.

Marcas: **aplicada en r7** = el SPEC r6 debe cambiar; **resuelta (D-92)** = falta un dato que el dueño no ha dado. Solo aparecen en la tabla final.

## Contexto

D-36 existe como «RAG completo», pero el SPEC r6 reconoce que el RAG sigue sin decisiones escritas (§8; riesgo R-09). Lo que §8 ya contiene se conserva: RRF 1-based, `min_score` aplicado antes de la fusión, IDs estables, reindexado incremental por `content_hash`, citas, filtros con `:unsupported_filter`, límites de ingesta y documentos como entrada no confiable.

## Decisión

### 8a · Siete piezas; el classifier de consulta (A1) se aplaza a v1.1 (P-1)

Piezas: store, chunker, embedder, retriever, reranker, rewriter y evaluación (SPEC §8.1). **No hay octava pieza en v1.**

- La estrategia de recuperación (`:vector`, `:lexical`, `:hybrid`, `:multi_query`) se elige por `opts.strategy` o por `[rag] strategy = "hybrid"` (defecto).
- Motivo (dueño): `hybrid` es un defecto sólido; modificar `DecisionSpec` para admitir estrategias es sobreingeniería en v1, y es coherente con D-56 y D-72.
- **A1 en v1.1**, con estas condiciones ya fijadas: no se clasifica cuando la consulta la redacta el modelo (P-2); la verificación es por resultado: `recall@5` con límite inferior del intervalo de Wilson frente a la línea base «siempre `hybrid`» (P-3), calculado sobre conteos agregados (relevantes recuperados / relevantes totales del corpus).

### 8b · Stores

| Store | Rol en v1 | Estado |
| --- | --- | --- |
| `Memory` | Defecto para pruebas | Sin dependencias; no persiste |
| `SQLite` (`sqlite-vec` + FTS5) | **Defecto para uso real** | Sin servidor; cubre vector y léxico |
| `Postgres` (`pgvector` + `tsvector`) | Producción y multinodo | Cuando el despliegue ya tiene Postgres |
| `ETS` | **No es un store del RAG**: es interno (cachés) | Se retira de la lista de stores |

**Matriz de §0.6** (solo hechos \[V\], puertas \[G\] o propiedades del diseño):

| Criterio | Memory | SQLite + sqlite-vec | Postgres + pgvector |
| --- | --- | --- | --- |
| Búsqueda vectorial | Fuerza bruta en proceso (propiedad del diseño) | KNN por **fuerza bruta (exacto)**; el índice «rescore» ya fusionado en el proyecto sigue siendo fuerza bruta sobre vectores cuantizados \[V\] | Sin verificar \[G-25\] |
| Búsqueda léxica | BM25 en proceso (SPEC §5.9) | FTS5 \[G-26\] | `tsvector` \[G-25\] |
| Rendimiento a escala | Limitado por la memoria de la VM | Coste lineal con el número de vectores, por ser fuerza bruta \[V\]; **el punto de corte se mide en F12**, no se fija aquí | Sin verificar \[G-25\] |
| Robustez | No persiste | Un fichero; escritura concurrente a comprobar \[G-24\] | Servidor externo |
| Seguridad | Sin superficie adicional | Extensión cargable: solo desde una ruta de la config del operador \[G-24\] | Credenciales y red del servidor |
| Operabilidad | Sin dependencias | Sin servidor; depende de cargar la extensión desde Elixir \[G-24\] | Exige operar Postgres |

La matriz **confirma** la lectura del dueño. Condiciones: el defecto SQLite depende de **G-24** y **G-26** (rama B de G-24: vectores en una tabla normal puntuados en proceso, búsqueda exacta a costa de rendimiento). Que el plan sitúe SQLite en F12 mientras es el defecto de uso real queda en la tabla final (I-12).

### 8c · `min_score` y `calibrate_rag/2` (P-4)

- `min_score = 0.0` por defecto (sin umbral). Se documenta como «acepta todo lo no ortogonal; se recomienda calibrar con el corpus de recuperación». La regla «un coseno exactamente 0.0 no entra» (§8.3) sigue vigente. La calibración es opcional; `Doctor` emite `:warn` si no se ha ejecutado `calibrate_rag` para el embedder configurado, y **no bloquea el arranque**. Un defecto declarado con su procedimiento de calibración cumple la regla 2 de §0.6.
- **`Gunther.Doctor.calibrate_rag/2`**: para cada valor candidato de `min_score`, ejecuta las consultas del corpus de recuperación (`relevant_ids`, §16.3), calcula **F1@5** y elige el valor de **F1@5 máxima**; si todas las F1@5 son 0, usa `0.0`.
  - Por consulta: `recall@5 = |relevantes ∩ top5| / |relevantes|`; `precision@5 = |relevantes ∩ top5| / |resultados devueltos|` (los que superan `min_score`, como máximo 5; si no se devuelve ninguno, precisión 0); `F1@5 = 2·P·R / (P + R)` (0 si `P + R = 0`). Se promedia sobre las consultas.
  - **La precisión se divide por los resultados devueltos y no por 5**: con denominador fijo 5, subir el umbral nunca mejoraría la precisión y el máximo sería siempre `0.0`, con lo que la calibración no discriminaría.
  - Valores candidatos: los valores distintos de puntuación observados en los resultados del corpus, más `0.0`. Ante empate, el menor.

### 8d · El RAG como tool: una API, cuatro puertas

| Puerta | Cómo se invoca | Quién decide consultar |
| --- | --- | --- |
| 1. API directa | `Gunther.Rag.query/2` | El código del usuario |
| 2. Tool `rag_query` | Se registra al arrancar en `Gunther.Tools` con `source: :local` y `permission: :auto`; `[rag] tool_enabled = true` por defecto (`false` la apaga) | El modelo |
| 3. `opts.rag` en `chat/2` | Inyecta el contexto en el flujo, antes de decidir | El llamador |
| 4. Agentes, MCP y gateway | Por el registro de tools y las vías normales | Según la vía |

- **Registro** (condición): solo si `Gunther.Rag` está cargado (es opcional, §0.4) y hay un store configurado.
- **Esquema de `rag_query` (P-5)**: `query` (obligatorio), `top_k` y `filter`. **No expone** `store`, `retriever`, `reranker` ni `rewriter`. `top_k` tiene un tope derivado de `tools.max_result_bytes`: `floor(tools.max_result_bytes / bytes máximos de un resultado)`; mientras el `Chunker` no declare un tamaño máximo de chunk (I-24), actúa solo el truncado de §9.1.
- **Permisos (P-6)**: `:auto` por defecto; el operador puede cambiarlo a `:confirm` con `tools.permissions`. `Doctor` emite `:warn` si la config tiene más de un consumer y `rag_query` es `:auto`. **El índice es común a todos los consumers**: no hay aislamiento por consumer del contenido indexado.
- **Servidor y cliente (P-8)**, como dice §9.4: las tools del registro se ejecutan en el servidor; las tools definidas por el cliente se devuelven al cliente.
- No es un paso fijo del pipeline: `opts.rag` decide si se consulta, y la tool está disponible cuando el modelo decida consultarla. El resultado pasa por el truncado de §9.1 y se marca `untrusted` al entrar al prompt (§7.3).

### 8e · `store_backend` (P-7)

```toml
[rag]
store_backend = "separate"   # v1: solo "separate"
```

`separate`: el RAG y la memoria KV tienen cada uno su store, sin mezclar filas. `shared` produce `config_error` con el mensaje: **«shared requiere MemoryStore persistente, que llega en v1.1»**.

## Alternativas consideradas

- Classifier de consulta en v1 (A1): aplazado a v1.1 por sobreingeniería.
- `min_score` obligatorio sin defecto (r6): descartado por el dueño.
- Exponer las opciones de módulo de `query/2` como esquema de la tool: descartado (P-5).
- `ETS` como store del RAG (r6 §8.6): descartado por el dueño.
- `store_backend = shared` en v1: aplazado a v1.1 (P-7).

## Consecuencias

- Una implementación, cuatro puertas; la tool `rag_query` expone el contenido indexado a quien llegue al registro de tools, incluidos clientes MCP autenticados (aceptado con `Doctor :warn`).
- Dependencias de puertas nuevas: **G-24, G-25 y G-26**.
- Reaparecen para v1.1: A1 y `MemoryStore` persistente (en `docs/12-roadmap.md`).

## Verificación

- AC de F11 y F12 (SPEC §19), con los cambios de la tabla de abajo.
- Puertas nuevas (se añadirían al Anexo C en r7):

| Puerta | Pregunta y test | Rama A | Rama B |
| --- | --- | --- | --- |
| G-24 | ¿Se carga `sqlite-vec` desde el binding de SQLite de Elixir y funcionan las escrituras concurrentes? | Store SQLite con `sqlite-vec` | Vectores en tabla normal puntuados en proceso |
| G-25 | ¿Funcionan `pgvector` y `tsvector` desde el cliente de Postgres de Elixir? | Store Postgres | Postgres sin vectores nativos o fuera de v1 |
| G-26 | ¿Está FTS5 disponible en el SQLite del binding? | Léxico con FTS5 | Léxico BM25 en proceso |

- **Puertas F0 de las que depende**: G-24, G-25, G-26.

## Cambios necesarios en el SPEC (r7)

Estado: **cerrada** = decidida y sin cambio en el SPEC; **abierta** = el SPEC r6 debe cambiar en r7.

| # | Sección r6 | Qué dice r6 | Qué decide D-36 | Estado |
| --- | --- | --- | --- | --- |
| I-01 | §8.3, §14.1, §14.2, §19 (F12) | `min_score` obligatorio y sin defecto | Defecto `0.0`; calibración opcional; `Doctor :warn` sin bloquear. Cambian también la validación cruzada de §14.2 y el AC de F12 | aplicada en r7 |
| I-02 | §7.4, §8.6, §14.1 | «El RAG es un store aparte», sin opción | Clave `store_backend`; en v1 solo `separate`; `shared` es `config_error` | aplicada en r7 |
| I-03 | §8.1 | Siete piezas | Siete piezas (A1 aplazado) | cerrada (P-1) |
| I-04 | §4.7, §9.1 | El RAG no está registrado como tool | `rag_query` registrada; `tool_enabled` | aplicada en r7 |
| I-05 | §5.9, §8.6, `docs/01` F11 | `ETS` figura como store | `ETS` no es un store del RAG | aplicada en r7 |
| I-06 | §7.2, §5.9, §14.1 `[memory]` | La memoria KV solo existe en ETS | `shared` aplazado a v1.1 con su mensaje de error | cerrada (P-7) |
| I-07 | §4.12, §16.3 | `Doctor` sin `calibrate_rag` | `calibrate_rag/2` con F1@5 (precisión sobre resultados devueltos, valores candidatos observados, empate al menor) | aplicada en r7 |
| I-08 | §4.7 | `query/2` admite módulos como opciones | La tool no los expone: `query`, `top_k`, `filter` | aplicada en r7 |
| I-09 | §5.7, §6.11 | `DecisionSpec` solo para modelos | Ya no hace falta en v1 | cerrada (P-1) |
| I-10 | §6.12 M2 | La `DecisionView` solo contiene texto del caller | Sin classifier no hay conflicto; en v1.1 no se clasifica lo redactado por el modelo | cerrada (P-1, P-2) |
| I-11 | §14.1 `[rag]` | Solo `max_document_bytes`, `max_chunks_per_document`, `rrf_k` | Añadir `strategy`, `tool_enabled`, `store_backend` y el store por defecto | aplicada en r7 |
| I-12 | §19 F11/F12, `docs/01` | `SQLite` y `Postgres` en F12 | SQLite es el defecto de uso real: ¿pasa a F11? | resuelta (D-92) |
| I-13 | §15 T-15, §9.3 | El aislamiento por consumer cubre memoria, sesiones y caché | El índice del RAG es común a todos; `Doctor :warn` con más de un consumer y `rag_query` en `:auto` | aplicada en r7 |
| I-14 | §2.4 | El RAG se inyecta en el paso de contexto | El enunciado original de la puerta 3 hablaba del «enrutado» | resuelta (D-92) |
| I-15 | §6.11 `router.embedding.min_similarity` | Obligatorio y sin defecto | ¿Misma política que `min_score` (defecto `0.0`, aviso sin bloqueo)? | resuelta (D-92) |
| I-16 | Anexo C | Sin puertas para SQLite ni Postgres | Añadir G-24, G-25, G-26 (y G-27, ver D-35) | aplicada en r7 |
| I-17 | §9.4, §12.1 | Tools del registro y del cliente | Como dice §9.4 | cerrada (P-8) |
| I-18 | `docs/06`, `docs/08` | Sin la configuración del RAG ni `calibrate_rag` | Añadir a la guía de operación | aplicada en r7 |
| I-24 | §5.3 | `Chunker` sin tamaño máximo de chunk declarado | Necesario para derivar el tope de `top_k` | aplicada en r7 |
| I-25 | §14.1, §4.12, §15 | No hay registro de consumers en la config | `Doctor` cuenta consumers para el aviso de P-6; hay que definir de dónde (`gateway.api_keys`, agentes) | aplicada en r7 |

**Evaluación del paquete**: su corrección C-02 («la clave debe estar presente; `0.0` significa sin umbral») queda sustituida por I-01; C-03 (`max_mib`, `reserve_mib`) no depende de D-36.
