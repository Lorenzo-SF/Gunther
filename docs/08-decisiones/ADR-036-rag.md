# ADR D-36 — RAG completo

- **Estado**: aceptada (DP0, r8)
- **Fecha**: 2026-10-25
- **Fuente**: SPEC-000-GUNTHER r8 §8, §4.7, §7.4, §9.1, §14.1; respuestas del dueño 8a a 8e y P-1 a P-8; D-92
- **Sustituye** a las versiones anteriores de este fichero.

## Porqué de las siete piezas

El RAG de Gunther tiene siete piezas, no una. La razón es que cada una resuelve un problema distinto y se puede implementar de formas distintas:

| Pieza          | Por qué                                                          | Sin ella                                                                                        |
| -------------- | ---------------------------------------------------------------- | ----------------------------------------------------------------------------------------------- |
| **Store**      | Persistir los chunks y sus vectores.                             | No hay RAG persistente.                                                                         |
| **Chunker**    | Dividir un documento en unidades indexables.                     | Un documento entero no cabe en el contexto, y la recuperación devuelve fragmentos irrelevantes. |
| **Embedder**   | Convertir texto en vectores para búsqueda semántica.             | Solo búsqueda léxica (BM25), que falla con sinónimos y paráfrasis.                              |
| **Retriever**  | Consultar el store con una estrategia (vector, lexical, hybrid). | El store no sabe qué consulta recibir.                                                          |
| **Reranker**   | Reordenar los resultados por relevancia.                         | Los resultados del retriever son ruidosos.                                                      |
| **Rewriter**   | Reformular la consulta para mejorar la recuperación.             | Consultas ambiguas o cortas no recuperan bien.                                                  |
| **Evaluación** | Medir si la recuperación es buena.                               | No hay forma de saber si el RAG funciona.                                                       |

**Son siete y no ocho** porque el classifier de consulta (A1) se aplazó a v1.1 (P-1). Un classifier de consulta decide qué estrategia usar por consulta; sin él, `hybrid` es un defecto sólido.

**SQLite es el store por defecto de uso real** (no `Memory`) porque `Memory` no persiste y el RAG sin persistencia no es un RAG. `Memory` queda para tests. `Postgres` queda para producción multinodo.

**`min_score` tiene defecto `0.0`** (no obligatorio) porque un umbral fijo no es calibrable sin corpus. `Doctor.calibrate_rag/2` lo calibra cuando hay corpus; sin él, se acepta todo lo no ortogonal.

**RRF es 1-based** (CE-29) porque la fórmula estándar usa `1 / (k + rank)` con `rank` empezando en 1. 0-based cambia la escala y no es RRF.

**`rag_query` es una tool** (D-36, P-5) porque el modelo puede decidir consultar el RAG sin que el usuario lo sepa. `opts.rag` en `chat/2` inyecta el contexto automáticamente; `rag_query` permite que el modelo lo pida cuando lo necesite.

**`store_backend = "separate"` en v1** (P-7) porque `MemoryStore` persistente no existe todavía. `shared` requiere un store común para memoria KV y RAG, que llega en v1.1.

## Contexto

D-36 existe como «RAG completo», pero el SPEC r6 reconocía que el RAG seguía sin decisiones escritas (§8; riesgo R-09). Lo que §8 ya contiene se conserva: RRF 1-based, `min_score` aplicado antes de la fusión, IDs estables, reindexado incremental por `content_hash`, citas, filtros con `:unsupported_filter`, límites de ingesta y documentos como entrada no confiable. Este ADR cierra el porqué.

## Decisión

### 8a · Siete piezas; el classifier de consulta (A1) se aplaza a v1.1 (P-1)

Piezas: store, chunker, embedder, retriever, reranker, rewriter y evaluación (SPEC §8.1). **No hay octava pieza en v1.**

- La estrategia de recuperación (`:vector`, `:lexical`, `:hybrid`, `:multi_query`) se elige por `opts.strategy` o por `[rag] strategy = "hybrid"` (defecto).
- Motivo (dueño): `hybrid` es un defecto sólido; modificar `DecisionSpec` para admitir estrategias es sobreingeniería en v1, y es coherente con D-56 y D-72.
- **A1 en v1.1**, con estas condiciones ya fijadas: no se clasifica cuando la consulta la redacta el modelo (P-2); la verificación es por resultado: `recall@5` con límite inferior del intervalo de Wilson frente a la línea base «siempre `hybrid`» (P-3), calculado sobre conteos agregados (relevantes recuperados / relevantes totales del corpus).

### 8b · Stores

| Store                                | Rol en v1                                       | Estado                                 |
| ------------------------------------ | ----------------------------------------------- | -------------------------------------- |
| `Memory`                             | Defecto para pruebas                            | Sin dependencias; no persiste          |
| `SQLite` (`sqlite-vec` + FTS5)       | **Defecto para uso real**                       | Sin servidor; cubre vector y léxico    |
| `Postgres` (`pgvector` + `tsvector`) | Producción y multinodo                          | Cuando el despliegue ya tiene Postgres |
| `ETS`                                | **No es un store del RAG**: es interno (cachés) | Se retira de la lista de stores        |

**Matriz de §0.6** (solo hechos \[V\], puertas \[G\] o propiedades del diseño):

| Criterio             | Memory                                         | SQLite + sqlite-vec                                                                                                                           | Postgres + pgvector             |
| -------------------- | ---------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------- |
| Búsqueda vectorial   | Fuerza bruta en proceso (propiedad del diseño) | KNN por **fuerza bruta (exacto)**; el índice «rescore» ya fusionado en el proyecto sigue siendo fuerza bruta sobre vectores cuantizados \[V\] | Sin verificar \[G-25\]          |
| Búsqueda léxica      | BM25 en proceso (SPEC §5.9)                    | FTS5 \[G-26\]                                                                                                                                 | `tsvector` \[G-25\]             |
| Rendimiento a escala | Limitado por la memoria de la VM               | Coste lineal con el número de vectores, por ser fuerza bruta \[V\]; **el punto de corte se mide en F12**, no se fija aquí                     | Sin verificar \[G-25\]          |
| Robustez             | No persiste                                    | Un fichero; escritura concurrente a comprobar \[G-24\]                                                                                        | Servidor externo                |
| Seguridad            | Sin superficie adicional                       | Extensión cargable: solo desde una ruta de la config del operador \[G-24\]                                                                    | Credenciales y red del servidor |
| Operabilidad         | Sin dependencias                               | Sin servidor; depende de cargar la extensión desde Elixir \[G-24\]                                                                            | Exige operar Postgres           |

La matriz **confirma** la lectura del dueño. Condiciones: el defecto SQLite depende de **G-24** y **G-26** (rama B de G-24: vectores en una tabla normal puntuados en proceso, búsqueda exacta a costa de rendimiento). Que el plan sitúe SQLite en F11 mientras es el defecto de uso real está en la tabla final (I-12).

### 8c · `min_score` y `calibrate_rag/2` (P-4)

- `min_score = 0.0` por defecto (sin umbral). Se documenta como «acepta todo lo no ortogonal; se recomienda calibrar con el corpus de recuperación». La regla «un coseno exactamente 0.0 no entra» (§8.3) sigue vigente. La calibración es opcional; `Doctor` emite `:warn` si no se ha ejecutado `calibrate_rag` para el embedder configurado, y **no bloquea el arranque**. Un defecto declarado con su procedimiento de calibración cumple la regla 2 de §0.6.
- **`Gunther.Doctor.calibrate_rag/2`**: para cada valor candidato de `min_score`, ejecuta las consultas del corpus de recuperación (`relevant_ids`, §16.3), calcula **F1@5** y elige el valor de **F1@5 máxima**; si todas las F1@5 son 0, usa `0.0`.
  - Por consulta: `recall@5 = |relevantes ∩ top5| / |relevantes|`; `precision@5 = |relevantes ∩ top5| / |resultados devueltos|` (los que superan `min_score`, como máximo 5; si no se devuelve ninguno, precisión 0); `F1@5 = 2·P·R / (P + R)` (0 si `P + R = 0`). Se promedia sobre las consultas.
  - **La precisión se divide por los resultados devueltos y no por 5**: con denominador fijo 5, subir el umbral nunca mejoraría la precisión y el máximo sería siempre `0.0`, con lo que la calibración no discriminaría.
  - Valores candidatos: los valores distintos de puntuación observados en los resultados del corpus, más `0.0`. Ante empate, el menor.

### 8d · El RAG como tool: una API, cuatro puertas

| Puerta                    | Cómo se invoca                                                                                                                                    | Quién decide consultar |
| ------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------- | ---------------------- |
| 1. API directa            | `Gunther.Rag.query/2`                                                                                                                             | El código del usuario  |
| 2. Tool `rag_query`       | Se registra al arrancar en `Gunther.Tools` con `source: :local` y `permission: :auto`; `[rag] tool_enabled = true` por defecto (`false` la apaga) | El modelo              |
| 3. `opts.rag` en `chat/2` | Inyecta el contexto en el flujo, antes de decidir                                                                                                 | El llamador            |
| 4. Agentes, MCP y gateway | Por el registro de tools y las vías normales                                                                                                      | Según la vía           |

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

Classifier de consulta en v1 (A1): aplazado a v1.1 por sobreingeniería.
`min_score` obligatorio sin defecto (r6): descartado por el dueño.
Exponer las opciones de módulo de `query/2` como esquema de la tool: descartado (P-5).
`ETS` como store del RAG (r6 §8.6): descartado por el dueño.
`store_backend = shared` en v1: aplazado a v1.1 (P-7).

## Consecuencias

Una implementación, cuatro puertas; la tool `rag_query` expone el contenido indexado a quien llegue al registro de tools, incluidos clientes MCP autenticados (aceptado con `Doctor :warn`).
Dependencias de puertas nuevas: **G-24, G-25 y G-26**.
Reaparecen para v1.1: A1 y `MemoryStore` persistente (en `docs/12-roadmap.md`).

## Verificación

AC de F11 y F12 (SPEC §19), con los cambios de la tabla de abajo.
Puertas nuevas (en el Anexo C):

| Puerta | Pregunta y test                                                                                      | Rama A                        | Rama B                                        |
| ------ | ---------------------------------------------------------------------------------------------------- | ----------------------------- | --------------------------------------------- |
| G-24   | ¿Se carga `sqlite-vec` desde el binding de SQLite de Elixir y funcionan las escrituras concurrentes? | Store SQLite con `sqlite-vec` | Vectores en tabla normal puntuados en proceso |
| G-25   | ¿Funcionan `pgvector` y `tsvector` desde el cliente de Postgres de Elixir?                           | Store Postgres                | Postgres sin vectores nativos o fuera de v1   |
| G-26   | ¿Está FTS5 disponible en el SQLite del binding?                                                      | Léxico con FTS5               | Léxico BM25 en proceso                        |

- **Puertas F0 de las que depende**: G-24, G-25, G-26.

## Cambios necesarios en el SPEC (r7)

Estado: **cerrada** = decidida y sin cambio en el SPEC; **aplicada en r7** = el SPEC cambió.

| #    | Sección                                 | Cambio                                                                                             | Estado             |
| ---- | --------------------------------------- | -------------------------------------------------------------------------------------------------- | ------------------ |
| I-01 | §8.3, §14.1, §14.2, §19 (F12)           | `min_score` con defecto `0.0`; calibración opcional; `Doctor :warn` sin bloquear                   | aplicada en r7     |
| I-02 | §7.4, §8.6, §14.1                       | Clave `store_backend`; en v1 solo `separate`; `shared` es `config_error`                           | aplicada en r7     |
| I-03 | §8.1                                    | Siete piezas (A1 aplazado)                                                                         | cerrada (P-1)      |
| I-04 | §4.7, §9.1                              | `rag_query` registrada; `tool_enabled`                                                             | aplicada en r7     |
| I-05 | §5.9, §8.6, `docs/01` F11               | `ETS` no es un store del RAG                                                                       | aplicada en r7     |
| I-06 | §7.2, §5.9, §14.1 `[memory]`            | `shared` aplazado a v1.1 con su mensaje de error                                                   | cerrada (P-7)      |
| I-07 | §4.12, §16.3                            | `calibrate_rag/2` con F1@5                                                                         | aplicada en r7     |
| I-08 | §4.7                                    | La tool no expone módulos                                                                          | aplicada en r7     |
| I-09 | §5.7, §6.11                             | `DecisionSpec` solo para modelos                                                                   | cerrada (P-1)      |
| I-10 | §6.12 M2                                | Sin classifier no hay conflicto; en v1.1 no se clasifica lo redactado por el modelo                | cerrada (P-1, P-2) |
| I-11 | §14.1 `[rag]`                           | Añadir `strategy`, `tool_enabled`, `store_backend` y el store por defecto                          | aplicada en r7     |
| I-12 | §19 F11/F12, `docs/01`                  | SQLite pasa a F11                                                                                  | resuelta (D-92)    |
| I-13 | §15 T-15, §9.3                          | El índice del RAG es común a todos; `Doctor :warn` con más de un consumer y `rag_query` en `:auto` | aplicada en r7     |
| I-14 | §2.4                                    | El RAG se inyecta en el paso de contexto                                                           | resuelta (D-92)    |
| I-15 | §6.11 `router.embedding.min_similarity` | Defecto `0.0`; aviso sin bloqueo                                                                   | resuelta (D-92)    |
| I-16 | Anexo C                                 | Añadir G-24, G-25, G-26, G-27                                                                      | aplicada en r7     |
| I-17 | §9.4, §12.1                             | Tools del registro y del cliente                                                                   | cerrada (P-8)      |
| I-18 | `docs/06`, `docs/08`                    | Configuración del RAG y `calibrate_rag`                                                            | aplicada en r7     |
| I-24 | §5.3                                    | Tamaño máximo de chunk declarado                                                                   | aplicada en r7     |
| I-25 | §14.1, §4.12, §15                       | Registro de consumers en la config                                                                 | aplicada en r7     |

**Evaluación del paquete**: su corrección C-02 («la clave debe estar presente; `0.0` significa sin umbral») queda sustituida por I-01; C-03 (`max_mib`, `reserve_mib`) no depende de D-36.
