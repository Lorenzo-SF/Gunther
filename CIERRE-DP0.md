# CIERRE-DP0 — Decisiones del dueño sobre Gunther

**Tipo:** registro de decisiones del dueño sobre el proyecto Gunther.
**Estado:** vinculante desde la fecha de firma.
**Fecha:** 2026-10-26.
**Base:** `SPEC-000-GUNTHER_r7.md`, §21 (preguntas Q-01 a Q-16) y §1.6 (D-48 a D-92).
**Efecto inmediato:** cierra **DP0**, abre **F0** y produce `SPEC-000-GUNTHER_r8.md`.
**Referenciado desde:** `SPEC-000-GUNTHER_r8.md` §21 y Anexo D; `CHANGELOG.md`; `README.md`; `docs/08-decisiones/README.md`; `docs/13-registro-de-fases.md`.
**Ubicación:** raíz del repositorio.

---

## 1. DP0 — Aprobación de ADRs D-48 a D-92

Los **45 ADRs** (D-48 a D-92) pasan a estado **`aceptada`**. No se rechaza ninguno. Los matices que se introducen abajo como «nota del dueño» se aplican como cambios de r8.

| Bloque                       | ADRs        | Estado        | Nota                                                                |
| ---------------------------- | ----------- | ------------- | ------------------------------------------------------------------- |
| Ejecución y resiliencia      | D-48 a D-62 | **aceptadas** | D-48: ver Q-14                                                      |
| Identidad, alcance, amenazas | D-63 a D-73 | **aceptadas** | D-71 y D-72 formalizan decisiones ya tomadas por el dueño           |
| Coral                        | D-74 a D-86 | **aceptadas** | D-85: ver Q-09. D-78: `Arrea` como anfitrión opcional; no se fuerza |
| Resoluciones r7              | D-87 a D-92 | **aceptadas** | D-92: se acepta el traslado de SQLite a F11                         |

**Consecuencia:** `docs/08-decisiones/README.md` actualiza el estado de D-48 a D-92 a `aceptada`. DP0 cerrado.

---

## 2. Respuestas a las preguntas abiertas (§21 del SPEC r7)

### Q-09 — Coral y ganchos G1–G9

**Decisión: se confirma la delegación.**

- **G1 a G9 entran en v1**, en las fases que indica §22.14 (F1, F3, F4, F5, F7, F8, F14).
- **La coral (`F18`–`F22`) se entrega después de 1.0**, con los ganchos ya previstos.
- **N-15** (sobrecoste por paso de coral): **50 ms p99**, medido en F18 con el benchmark de 100 ejecuciones concurrentes, sin contar modelos ni tools. Si el benchmark revela que 50 ms no son medibles con la instrumentación disponible, se sube hasta el valor que sí lo sea y se documenta; el umbral no bloquea nada antes de F18.

**Por qué se confirma la delegación.** La alternativa —publicar sin ganchos y añadirlos en un major bump— rompe SemVer (§4.14) sin ahorrar trabajo real: cada gancho es una opción o un campo, no un módulo. El coste de meterlos ahora es bajo y acotado; el de meterlos después es un `2.0.0`.

### Q-10 — Votación de enrutado (`:routing_vote`)

**Decisión: se mantiene.** D-46 sigue vigente como modalidad `:routing_vote` de la coral. No se retira porque el corpus del router puede verificar si aporta valor (§6.11); si no aporta, se queda declarada pero apagada por defecto, igual que `:win_rate_binary`.

### Q-11 — DSL, datos y TOML

**Decisión: los tres a la vez, condicionado a G-31.**

Si G-31 pasa (propiedad: la misma definición por las tres vías da un `Plan` idéntico, con errores con línea en el DSL), se publican los tres. Si G-31 falla, **el DSL no entra en F20**; datos y TOML sí. No se pospone el DSL más allá de G-31 porque el DSL es lo que hace usable la coral para alguien que no quiera escribir mapas de Elixir.

### Q-12 — `expand` y exposición de la coral por el gateway

**Decisión: `expand` desactivado por defecto; la coral no se expone por el gateway en v1.**

`expand` añade superficie de ataque (T-18) y no se necesita hasta que haya una modalidad que la use. La coral por el gateway multiplicaría la superficie del gateway sin demanda: quien quiera la coral, la usa desde Elixir. Las dos son reversibles por configuración o por nueva versión menor.

### Q-13 — `Gunther.Coral` sustituye a `Hive` y `Voice`

**Decisión: sí, sustituye.** No hay código publicado todavía (`README.md`: «no hay código publicado»). `Hive` y `Voice` no existen como módulos reales; eran nombres de r5. `Gunther.Coral` es el nombre definitivo. D-30, D-46 y D-56 se actualizan en r8 para leer «coral» donde decían «colmena»; el glosario ya recoge «mesa camilla = mente colmena = `:hive` de la coral».

### Q-14 — ¿Existe `Arrea.Resource` y está publicado?

**Decisión: sí, existe y está publicado.** Lo confirma D-13 con medición («23 KB, tests, `main` desde el 2026-10-10, publicado»). La vacilación de r5 era de **búsqueda**, no de existencia.

**Pero el ledger se queda propio en v1.** Razones:

1. La semántica de `foreign` y `available` de §11.3 es **específica de GPU** (medida por proceso, quiescencia, memoria unificada). `Arrea.Resource` no la tiene y añadirla es trabajo que pertenece a este proyecto.
2. La integración forzada —usar `Arrea.Resource` como capa base y envolverlo— **cuesta más** que mantener `Gunther.Resource.Ledger` como módulo autónomo, porque hay que traducir entre dos vocabularios sin ganancia.
3. La regla D-13 («a Arrea sube lo que Arrea use para sí, o lo pida un segundo consumidor») **sigue vigente**: si el ledger es útil a dos consumidores, sube a Arrea entonces, no ahora.

**Efecto sobre D-91:** la regla «ledger propio hasta que G-28 demuestre lo contrario» **se mantiene tal cual**, pero la condición «demuestre lo contrario» pasa a ser: _«que `Arrea.Resource`, con su API pública actual, permita implementar `foreign` y `available` de §11.3 sin duplicar medidas ni introducir acoplamiento»_. G-28 no bloquea F1; solo condiciona si el módulo propio se simplifica a fachada en F2.

**Efecto sobre Q-14:** cerrada. No hay más preguntas pendientes sobre `Arrea.Resource`.

### Q-15 — Los tres niveles de D-09

**Decisión: la interpretación literal que ofrece la pregunta es la correcta.** Concretamente:

- **Nivel 1: reglas específicas del consumer.** Se añaden a §6.8 como `[[consumers.<id>.rules]]` con la **misma forma** que las reglas globales (`when`, `action`, `target`, `weight`). Se evalúan **antes** que las globales.
- **Nivel 2: reglas globales.** Las `[[rules]]` actuales de §6.8, sin cambios.
- **Nivel 3: `default_model` del consumer.** Ya exigido en §14.1.

**Regla de evaluación:** las reglas de nivel 1 de un consumer se aplican **solo** a las peticiones de ese consumer. Las de nivel 2 se aplican a todos. La precedencia es: `veto` de nivel 1 > `veto` de nivel 2 > `force` de nivel 1 > `force` de nivel 2 > `prefer` de nivel 1 > `prefer` de nivel 2 > `default_model`. Dos `force` en el mismo nivel en desacuerdo se intersecan (regla de §6.8). Esta es la única lectura consistente con D-09 y con §6.8.

**Cambio concreto en r8:** §6.8 (nueva §6.8.1), §14.1 (esquema), validaciones cruzadas de §14.2 y AC de F4 (§19) se actualizan para incluir `[[consumers.<id>.rules]]` y la precedencia.

### Q-16 — Taxonomía cerrada de skills

**Decisión: se mantiene cerrada.** Razones:

1. **Previsibilidad del catálogo.** Un provider que declare `capabilities = ["code", "rag", "xyz"]` sin que `xyz` exista rompe la validación y la trazabilidad. La lista cerrada obliga a que cualquier skill nueva sea un cambio de contrato deliberado.
2. **Filtros rápidos del router.** Los skills son lo que el router filtra en `opts.require` y en `[[rules]].target.capability`. Una lista cerrada permite validar en carga, no en cada petición.
3. **Coste de ampliar.** Añadir una skill nueva es un cambio de contrato (SPEC §4.14), lo que está bien: aparece en el CHANGELOG y se decide a propósito.

La lista `[:code, :reasoning, :redaction, :vision, :audio, :tools, :embeddings]` cubre v1. Si hace falta una octava, se añade con versión mayor. **Aprobada.**

---

## 3. Política de ejecución de F0

Como dueño, se fija cómo se ejecutan las 31 puertas G-01 a G-31 y qué se hace si el entorno no permite alguna.

### 3.1. Regla general

Todas las puertas se ejecutan en F0, **en el orden que permitan las dependencias**. El resultado se registra en `docs/13-registro-de-fases.md` con el formato de `docs/04-f0-puertas.md`. Una puerta con resultado `PASA` o `FALLA` con rama B aplicada **cierra** la puerta. Una puerta que **no se puede ejecutar** por falta de hardware o de tiempo se marca `BLOQUEADA`, se aplica provisionalmente la rama B y se anota la fecha de re-ejecución.

### 3.2. Clasificación por dependencia del entorno

| Bloque                       | Puertas                                                            | Requisito                              | Estrategia                                                                       |
| ---------------------------- | ------------------------------------------------------------------ | -------------------------------------- | -------------------------------------------------------------------------------- |
| **Ejecutable hoy**           | G-01, G-05, G-07, G-16, G-17, G-22, G-23, G-27, G-31               | Proyecto Mix vacío                     | Ejecutar en F0 sin esperar                                                       |
| **Ejecutable con llama.cpp** | G-09 a G-14, G-18, G-24, G-26, G-29, G-30                          | Un binario de `llama-server` instalado | Ejecutar en F0 si hay binario; si no, `BLOQUEADA` con rama B provisional y fecha |
| **Ejecutable con GPU**       | G-10, G-11 (identidad física y atribución por proceso), G-19, G-20 | Al menos un GPU con CUDA o ROCm        | Ejecutar en F0 si hay GPU accesible; si no, `BLOQUEADA` con rama B provisional   |
| **Ejecutable con red**       | G-03, G-04, G-06, G-06b, G-08, G-15, G-25, G-28                    | Dependencias de Elixir descargadas     | Ejecutar en F0                                                                   |
| **Ejecutable con Arrea**     | G-28 (código de Arrea)                                             | `mix deps.get` de Arrea                | Ejecutar en F0 si Arrea resuelve                                                 |
| **Ejecutable con SQLite**    | G-24, G-26                                                         | Binding de SQLite                      | Ejecutar en F0                                                                   |

### 3.3. Regla de «rama B provisional»

Aplicar la rama B provisionalmente **no es un fracaso**: es la forma que el SPEC ya prevé para que el diseño no dependa del resultado. Cuando se aplique, el registro debe incluir:

- `Resultado: BLOQUEADA`.
- `Rama aplicada: B (provisional)`.
- `Motivo: sin hardware / sin binario / sin red`.
- `Fecha objetivo de re-ejecución: al cerrar F2 (o la fase que la consuma)`.

Y el AC de la fase que dependa de esa puerta se cierra con la rama B aplicada, no con la rama A pendiente.

### 3.4. Qué no se permite

- **No se permite** marcar una puerta como `PASA` sin ejecutarla. Si es `BLOQUEADA`, se dice `BLOQUEADA`.
- **No se permite** reabrir una puerta cerrada salvo que aparezca evidencia nueva (nueva versión de la librería, cambio de hardware). En ese caso, se reabre con una entrada nueva en el registro; la anterior se conserva.
- **No se permite** empezar F1 sin que las puertas que la bloquean (G-01, G-05, G-07, G-16, G-17, G-21, G-23) estén `PASA` o `BLOQUEADA con rama B aplicada`.

### 3.5. Orden recomendado de ejecución

1. **G-01, G-17, G-05, G-07, G-16** (dependencias y nombre).
2. **G-06, G-06b, G-08, G-22, G-23, G-27** (comandos, SDK, auditoría).
3. **G-09, G-12, G-14, G-18** (llama.cpp y decisor).
4. **G-10, G-11** (GPUs) — si hay hardware.
5. **G-24, G-26, G-25** (SQLite / Postgres).
6. **G-19, G-20** (mTLS y proxy) — si hay red.
7. **G-28** (Arrea) — depende de F0-02.
8. **G-15, G-29, G-30, G-31** (MCP, caché, continuidad, DSL).
9. **G-02, G-03, G-04** (resiliencia) — no bloquean F1 pero sí F5.

**G-02, G-03, G-04, G-13, G-21** pueden quedar `BLOQUEADA` hasta F5, F6 o F1 respectivamente; no bloquean el arranque.

---

## 4. Modificaciones concretas al SPEC para r8

Las siguientes filas se aplican al SPEC como cambios de r8.

| #         | Sección                                | Cambio                                                                                                                                                                                  |
| --------- | -------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **M-01**  | §6.8, §14.1, §14.2, §19                | Añadir `[[consumers.<id>.rules]]` con la misma forma que `[[rules]]` y la precedencia de Q-15. AC de F4 añade la prueba de precedencia.                                                 |
| **M-02**  | §17 N-15                               | Valor fijado: **50 ms p99**.                                                                                                                                                            |
| **M-03**  | §0.2, §1.3, §1.5, §4.9, §5, §10.2, §22 | Reemplazar «colmena / mesa camilla / Hive / Voice» por «coral» en la prosa y por `Gunther.Coral` en el código, salvo donde se refiera a la modalidad `:hive`. El glosario ya lo recoge. |
| **M-04**  | §21 Q-14                               | Cerrar Q-14 con la respuesta de §2 de este documento. D-91 mantiene la regla pero con la condición de Q-14 explicitada.                                                                 |
| **M-05**  | §21 Q-15                               | Cerrar Q-15 con la respuesta de §2.                                                                                                                                                     |
| **M-06**  | §21 Q-16                               | Cerrar Q-16 con la respuesta de §2.                                                                                                                                                     |
| **M-07**  | §21 Q-09 a Q-13                        | Confirmar las respuestas por delegación con los matices de §2.                                                                                                                          |
| **M-08**  | §21 Q-01 a Q-08                        | Marcarlas como cerradas (ratificación).                                                                                                                                                 |
| **M-09**  | `docs/08-decisiones/README.md`         | Actualizar estado de D-48 a D-92 a `aceptada`.                                                                                                                                          |
| **M-10**  | `docs/12-roadmap.md`                   | Coral (F18–F22): «aprobada, v1.1+, con G1–G9 en v1».                                                                                                                                    |
| **M-11**  | `docs/13-registro-de-fases.md`         | Fila DP0 completa con fecha, AC, desviaciones, decisiones nuevas.                                                                                                                       |
| **CE-34** | §6.8.1, §14.1, §14.2, §19              | Cierre de especificación de D-09 y D-87: sintaxis y precedencia de `[[consumers.<id>.rules]]`.                                                                                          |

---

## 5. Definición operativa de «listo para implementar»

A partir de esta fecha, el proyecto está en estado **«listo para implementar F0 y arrancar F1»** si y solo si se cumplen estas tres cosas:

1. **DP0 cerrado** — hecho por este documento.
2. **F0 con al menos las puertas que bloquean F1 ejecutadas o `BLOQUEADA` con rama B aplicada** — pendiente de ejecutar G-01, G-05, G-07, G-16, G-17, G-21, G-23.
3. **Proyecto Mix creado en el repositorio** — pendiente, pero trivial: `mix new gunther --sup` y las dependencias de §0.3.

**No es necesario** que el resto de F0 esté cerrada para empezar F1. F1 (config, errores, cache, cancel, command corto, telemetría, doctor esqueleto) **no depende de hardware ni de llama.cpp**. Se puede ejecutar en paralelo con las puertas restantes.

---

## 6. Encargo al agente

Con este documento, el agente tiene permiso explícito para:

1. **Aplicar M-01 a M-11 y CE-34 al SPEC y a los documentos**, generando `SPEC-000-GUNTHER_r8.md` y actualizando `docs/`.
2. **Crear el proyecto Mix vacío** en el repositorio con la estructura de `05-estructura-del-repositorio.md` y las dependencias de §0.3, sin código de producción todavía.
3. **Ejecutar F0** según la política de §3 de este documento, empezando por las puertas que bloquean F1.
4. **Abrir F1** en paralelo con las puertas que no bloquean, según §3.5.
5. **Mantener `docs/13-registro-de-fases.md`** al día; una puerta sin registro no está cerrada.
6. **No reabrir** ninguna decisión de D-48 a D-92 sin una razón nueva y documentada en un ADR con estado `propuesta` que el dueño tenga que aprobar.

**Si en el camino aparece una contradicción real del SPEC** (no una que se resuelva con M-01 a M-11), la regla D-10 manda: se detiene el trabajo, se escribe la corrección como revisión `rN+1`, y se continúa. No se implementa lo que no está en el SPEC.

**Si una puerta F0 falla**, se aplica la rama B ya escrita. No se improvisa: las dos ramas de cada puerta están diseñadas. El dueño solo interviene si la rama B **también** falla.

---

## 7. Estado del proyecto a fecha de este documento

| Elemento     | Estado                                                                                               |
| ------------ | ---------------------------------------------------------------------------------------------------- |
| DP0          | **Cerrado** (este documento)                                                                         |
| F0           | **En ejecución** (política en §3)                                                                    |
| Q-01 a Q-16  | **Todas cerradas**                                                                                   |
| D-01 a D-92  | **Todas aceptadas** (con las notas de r7 y r8)                                                       |
| Código       | Sin publicar; proyecto Mix pendiente de crear                                                        |
| Próximo hito | Cerrar las puertas que bloquean F1 (G-01, G-05, G-07, G-16, G-17, G-21, G-23) y abrir F1 en paralelo |

---

## 8. Firma

**Dueño del proyecto:** `[firma]`  
**Fecha:** 2026-10-26  
**Efecto:** DP0 cerrado. r8 producido. F0 abierto.
