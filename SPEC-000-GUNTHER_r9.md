# SPEC-000-GUNTHER — Especificación completa (r9)

> **Punto único de conocimiento de Gunther** (antes Candil, D-63). Si algo no está aquí, no está decidido. Si está aquí y en otro sitio, el otro sitio es un error.
>
> **Estado**: r9, **aprobada por el dueño. DP0 cerrado. F0 cerrado. F1 cerrado.** **Base**: r8 más el cambio de toolchain de §0.3 y N-11 (instrucción del dueño del 2026-10-28: las mismas versiones que `ropero`). **Fecha de r9**: 2026-10-28.
>
> **Etiquetas**, para quien implemente:
>
> - **\[V\]** verificado por r6 el 2026-10-25 contra una fuente pública consultada; la fuente se cita en el Anexo C.
> - **\[V5\]** verificado por r5 contra README o ficheros públicos de hex.pm / GitHub y **no reverificado** por r6. Se reverifica en F0 con el test de la puerta correspondiente.
> - **\[G-nn\]** **puerta F0**: hecho externo que no está verificado. El diseño de este documento **no depende de cuál sea el resultado**: el Anexo C define, para cada puerta, el test binario y la rama de diseño de cada resultado.
> - **\[P\]** propuesta de r6 que cambia o añade una decisión (D-63 en adelante). En r8 todas están aceptadas (DP0).
> - **\[CE-nn\]** cierre de especificación: detalle que faltaba en una decisión ya tomada. No es decisión nueva y no entra en el ADR.

**Qué cambia de r8 a r9** (detalle en el Anexo D)

1.  **Toolchain del proyecto** (§0.3, N-11): Erlang **28.5.0.7** y Elixir
    **1.19.5-otp-28**, los mismos que `ropero`. Antes de r9 el documento
    decia «OTP 27 (CI en 27 y 28)» con Elixir 1.19, y el repositorio fijaba
    27.3 / 1.19.1. La instruccion es del dueño (2026-10-28): **un solo
    toolchain para todo el ecosistema**, para que el codigo que se escribe
    en un repositorio funcione igual en los demas.
2.  **Correcciones editoriales** (E-01 a E-06, detalle en el Anexo D §E.3): sin
    cambio de comportamiento. El bloque TOML de §6.8.1 pasa a ser valido y su
    precedencia se aclara (los vetos se acumulan; la privacidad va en `veto`);
    `Arrea.Resource` deja de afirmar que esta publicado en Hex; el recuento de
    puertas de F0 pasa a 32; y la Regla final dice «una fase» en vez de «el
    juego».

**Qué cambia de r7 a r8** (detalle en el Anexo D)

1.  **Reglas por consumer** (M-01, Q-15): nueva §6.8.1 con `[[consumers.<id>.rules]]` y precedencia completa. AC de F4 ampliados. Tres filas nuevas en §6.10. `CE-34` cierra D-09 y D-87.
2.  **N-15 = 50 ms p99** (M-02, Q-09).
3.  **Renombrado colmena / mesa camilla / Hive / Voice → coral / `Gunther.Coral`** (M-03, Q-13). Tabla en §0.2; API en §4.9; §1.3, §1.5, §5, §10.2, §22 actualizadas.
4.  **`Arrea.Resource` existe en `main` según la medición del dueño (D-13); su publicación en Hex está pendiente de G-28; ledger propio en v1** (M-04, Q-14). D-48 y D-91 con nota; §3.2 actualizada; condición de fachada para G-28.
5.  **Taxonomía cerrada de skills ratificada** (M-06, Q-16).
6.  **Q-01 a Q-16 cerradas**; §21 reescrita; §1.7 nueva con el estado de las decisiones; DP0 cerrado.

> **Nota sobre versiones.** Este documento es **r9**, la revisión vigente. `SPEC-000-GUNTHER_r8.md` y `SPEC-000-GUNTHER_r7.md` se conservan como **histórico** y no deben usarse para implementar. Las referencias a "r8", "r7", "r6" o "r5" en los Anexos A, B y D son históricas: describen cambios que ya están aplicados en r9.

---

## 0 · Preliminares

### 0.1 Cómo se usa este documento

| Rol                    | Qué lee                           | Qué produce                                     |
| ---------------------- | --------------------------------- | ----------------------------------------------- |
| **Dueño del diseño**   | §1, §19, §20, §21                 | Aprobación o rechazo (DP0 cerrado en r8)        |
| **Implementador**      | §2 a §6 y la sección de su módulo | Código que pasa el AC de su fase (§19)          |
| **Revisor**            | Todo; busca contradicciones       | Correcciones al documento, no al código         |
| **Extensor (tercero)** | §4, §5, §14                       | Un behaviour registrado con su test de contrato |

**Regla de oro**: lo que no está en §4 y §5 no es contrato. Lo que sí está cambia solo con versión mayor.

### 0.2 Convenciones

- `atom()` en `snake_case`; `binary()` es UTF-8; `ms` milisegundos; `MiB` mebibytes (VRAM, nunca megabytes decimales); `tok` token de un LLM.
- **D-XX** decisión del dueño (ADR en `docs/08-decisiones/`). **AC** criterio de aceptación (§19). **CE-nn** cierre de especificación. **G-nn** puerta F0.
- **\[CONTRATO\]** firme, cambiar exige versión mayor. **\[REFERENCIA\]** implementación que cumple un contrato. **\[EXTENSIÓN\]** punto de extensión. **\[ECOSISTEMA\]** dependencia de una librería hermana.
- Dinero: **enteros en micro-dólares** (`cost_micros`), nunca `float`. Los precios se declaran por millón de tokens. Coste = `ceil(tokens × precio_por_mtok_micros / 1_000_000)` (redondeo hacia arriba, entero).
- Tiempo: las duraciones se miden con reloj monotónico (`System.monotonic_time/1`); las marcas de calendario son `DateTime` UTC. **Nunca se comparan relojes de pared entre máquinas** (§18.8).

**Renombrado (D-63):**

| Antes (Candil)                                           | Ahora (Gunther)                                            |
| -------------------------------------------------------- | ---------------------------------------------------------- |
| Namespace `Candil.*`                                     | `Gunther.*`                                                |
| Paquete Hex `candil`                                     | `gunther` (disponibilidad del nombre: G-16)                |
| `candil.toml`                                            | `gunther.toml`                                             |
| `CANDIL_INSTANCE_ID`, marca `candil-<instancia>-<alias>` | `GUNTHER_INSTANCE_ID`, marca `gunther-<instancia>-<alias>` |
| Eventos `[:candil, ...]`                                 | `[:gunther, ...]`                                          |
| Cabeceras `X-Candil-*`                                   | `X-Gunther-*`                                              |
| `SPEC-000-CANDIL`                                        | `SPEC-000-GUNTHER`                                         |

El nombre antiguo solo aparece en el Anexo A. Las librerías hermanas (`arrea`, `apero`, `trebejo`, `alaja`) **no cambian de nombre**.

**Renombrado de la coral (M-03, Q-13):**

| Antes (r6)                                                 | Ahora (r8)                                                                                                                                 |
| ---------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------ |
| «Mente colmena»                                            | «Coral» (concepto general)                                                                                                                 |
| «Mesa camilla»                                             | «Coral» (mismo concepto, nombre histórico)                                                                                                 |
| «Voz» (participante de la mente colmena)                   | «Miembro de la modalidad `:hive`» de la coral (con política de modelo propia)                                                              |
| `Gunther.Hive` (módulo)                                    | `Gunther.Coral`                                                                                                                            |
| `Gunther.Voice` (behaviour)                                | Absorbido por `Coral.Member`; los cuatro behaviours nuevos de la coral son `:coral_mode`, `:consensus`, `:step`, `:run_store` (§22.14, G9) |
| `Hive.tell/2`, `Hive.broadcast/1`, `Hive.register_voice/3` | `Coral.tell/2`, `Coral.broadcast/1`, `Coral.register_member/3` (§4.9, §22)                                                                 |
| `Voice.maybe_rank/3`                                       | `Member.maybe_rank/3`                                                                                                                      |
| Modalidad `:hive`                                          | Modalidad `:hive` (misma; ahora modalidad de coral)                                                                                        |

Los documentos históricos (r5, r6, r7) y los ADRs de D-30 y D-46 conservan el vocabulario antiguo, marcado como histórico; donde el lector vea «colmena», «voz» o «mesa camilla», debe leer «coral» o «miembro de la modalidad `:hive`», respectivamente.

### 0.3 Versiones y dependencias

| Componente                           | Mínimo                                | Por qué                                          |
| ------------------------------------ | ------------------------------------- | ------------------------------------------------ |
| Elixir                               | **1.19.5-otp-28** \[V5\]              | `apero` 4.x declara `elixir: ~> 1.19`; el mismo que `ropero` |
| OTP                                  | **28.5.0.7**                           | El mismo que `ropero`. El CI usa esa combinacion |
| Plataformas del controlador          | Linux, macOS ≥ 13 (best-effort), WSL2 | Windows nativo no. `Apero.OS` detecta WSL \[V5\] |
| Plataformas del agente de nodo (§18) | Linux, macOS ≥ 13 (best-effort), WSL2 | Las mismas                                       |

**Ecosistema `Lorenzo-SF`** (D-47):

| Librería  | Versión         | Rol en Gunther                                                              | Opcional |
| --------- | --------------- | --------------------------------------------------------------------------- | -------- |
| `arrea`   | `~> 3.0` \[V5\] | Circuit breaker, bulkhead, rate limiter, validación de comandos, telemetría | No       |
| `apero`   | `~> 4.0` \[V5\] | Crypto, Conf, Env, Retry, OS puro, Proc puro, File                          | No       |
| `trebejo` | `~> 2.0` \[V5\] | SafeCommand, Proc (señales, lsof), OS, File (watch)                         | No       |

El README de `arrea` 3.0.0 lista `Bulkhead` y `CircuitBreaker` y declara que todos sus procesos viven bajo `Arrea.Supervisor` con `:rest_for_one` y dos Registries globales (`Arrea.Registry`, `Arrea.CircuitBreaker.Registry`) \[V\]. Existe además un paquete de terceros, `resiliency`, con `CircuitBreaker`, `Bulkhead` (con `max_wait`), `RateLimiter` (con `weight`), `BackoffRetry` y `SingleFlight` \[V\]; entra en la matriz de decisión de G-02 como alternativa evaluada, no como dependencia.

Hex lista las versiones 4.0.0, 3.1.0, 3.0.0, 2.2.0, 2.1.0, 2.0.0 y 1.0.0 (retirada) de `arrea` \[V\]; `~> 3.0` excluye 4.0.0, y el README de 4.0.0 es idéntico al de 3.1.0, por lo que no permite saber qué cambió (G-17, G-28).

Comprobaciones obligatorias en F0 (Anexo C): `mix deps.tree` limpio y sin ciclos (G-01); versiones reales publicadas frente a la insignia del README de `arrea` (G-17).

**Otras dependencias**:

| Dependencia                                                               | Tipo        | Para qué                                        |
| ------------------------------------------------------------------------- | ----------- | ----------------------------------------------- |
| `jason`, `finch`, `telemetry`                                             | Obligatoria | JSON, HTTP/2 y streaming, eventos               |
| `:ssl` y `:public_key` (OTP)                                              | Obligatoria | mTLS hacia nodos (§18), TLS saliente            |
| Validador de JSON Schema (`jsv` u otro; criterio de elección en F0) \[P\] | Obligatoria | Validar argumentos de tools y structured output |
| `plug` + `bandit`                                                         | Opcional    | Gateway, servidor MCP HTTP, **agente de nodo**  |
| `exqlite` / `postgrex` + pgvector                                         | Opcional    | Stores SQLite y Postgres                        |
| `opentelemetry`                                                           | Opcional    | Puente de trazas (§13)                          |

`toml` no es dependencia directa: la carga la hace `Apero.Conf` \[V5: soporta JSON, YAML y TOML\]. Si no expone el parser que se necesita, F0 lo decide (G-07 cubre la rama).

### 0.4 Estructura del paquete \[P — D-49\]

Un único paquete Hex con dependencias `optional: true` y namespaces estrictos:

- `Gunther.Core` (router, catálogo, behaviours, registry, engine, resiliencia, **cliente de nodos**) no puede referenciar `Gunther.Gateway`, `Gunther.MCP.Server`, `Gunther.Rag`, `Gunther.Agent`, `Gunther.Coral` ni `Gunther.Node.Agent`.
- `Gunther.Node.Agent` (servidor del nodo, §18) es opcional y depende de `plug` y `bandit`.
- La CI lo comprueba con `mix xref graph`. Si el paquete duele, se parte en apps; no se parte por adelantado.
- Cada módulo opcional se carga con `Code.ensure_loaded?/1` y falla con `config_error` claro si falta su dependencia.

### 0.5 Documentos hermanos

| Documento                      | Rol                                                                                                                                                                                                                                                                                                           |
| ------------------------------ | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `docs/08-decisiones/README.md` | El **porqué** de D-01 a D-92. **Debe viajar con este SPEC**: sin él, las decisiones marcadas con † en §1.4 no son interpretables                                                                                                                                                                              |
| `CIERRE-DP0.md`                | Registro firmado por el dueño del cierre de DP0: aprobación de D-48 a D-92, cierre de Q-01 a Q-16, política de ejecución de F0                                                                                                                                                                                |
| `CHANGELOG.md`                 | Cambios de código entre versiones                                                                                                                                                                                                                                                                             |
| `examples/`                    | Referencia de uso ejecutable                                                                                                                                                                                                                                                                                  |
| `LICENSE`, `NOTICE`            | **Apache-2.0** (D-73, decidido por el dueño: licencia abierta con atribución). Exige conservar el aviso de copyright y el `NOTICE` en toda redistribución, que es el reconocimiento al autor. Permite uso, modificación y redistribución; la política de contribución (abajo) es independiente de la licencia |
| `CONTRIBUTING.md`              | Política: **no se aceptan cambios directos**; quien quiera proponer una modificación abre un _issue_ en GitHub; el autor lo evalúa y, si le interesa, lo implementa y publica                                                                                                                                 |
| `docs/10-recomendaciones.md`   | Modelos y configuraciones recomendados (no vinculantes, D-72)                                                                                                                                                                                                                                                 |

### 0.6 Regla de no-suposición \[P — D-64\]

Este documento se rige por cuatro reglas, comprobables:

1.  **Afirmaciones externas** (sobre librerías, binarios, protocolos, hardware, modelos): llevan \[V\] con fuente (Anexo C), \[V5\], o \[G-nn\] con test y ramas. Una afirmación externa sin etiqueta es un defecto del documento.
2.  **Números**: cada cifra es (a) un **parámetro** con defecto declarado como decisión y procedimiento de calibración, (b) el resultado de una **fórmula** escrita, o (c) un **umbral de requisito** del dueño (§17). Una cifra que describe cómo se comporta el mundo sin medición está prohibida.
3.  **Comportamiento**: todo caso límite tiene una fila en una tabla de decisión. Prohibido «razonable», «normalmente», «suele».
4.  **Lint de documento** (CI de F0): falla si el texto normativo contiene, fuera de código y de citas, alguna de estas cadenas: `supon`, `estim`, `aproximad` (salvo el modo `approximate` de §7.6), `probablement`, `razonable`, `unos cientos`, `creo que`, `~` delante de cifra.

**Qué significa «el mejor» en este documento**: cada elección entre alternativas se resuelve con una **matriz de criterios** (rendimiento, robustez, escalabilidad, seguridad, operabilidad) cuyas filas se rellenan con hechos \[V\], \[G\] o propiedades del diseño. Si un criterio no se puede rellenar con un hecho, la matriz lo declara y la decisión queda condicionada a su puerta.

---

## 1 · La tesis

### 1.1 Qué es Gunther

**Gunther es una librería de Elixir para usar N modelos de lenguaje configurados como si fueran uno.** El cliente apunta a Gunther una vez y no elige modelo: manda una petición y Gunther decide a quién va, con qué certeza y qué declara. **El centro de gravedad es el enrutado; la inferencia local es un backend más** (D-01), local en la máquina, **gestionada en otra máquina** (§18) o en la nube. **Gunther es un framework y no tiene CLI** (D-31).

### 1.2 El criterio de aceptación global

> **Un tercero define esto y funciona sin tocar Gunther.**

Se comprueba con un test que solo se puede escribir si el punto de extensión existe de verdad (§5.14).

### 1.3 El modelo mental

| Concepto               | Qué es                                                                                                                                                               | Dónde vive                    |
| ---------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ----------------------------- |
| **skill**              | Qué sabe hacer un modelo: `:code`, `:reasoning`, `:redaction`, `:vision`, `:audio`, `:tools`, `:embeddings`. Taxonomía cerrada (D-02), ratificada en r8 (Q-16)       | Catálogo (§14)                |
| **recurso**            | Memoria de un device, en MiB enteros (D-03)                                                                                                                          | Ledger (§11)                  |
| **device**             | Un slot de memoria con **identidad física** (D-65)                                                                                                                   | Detector (§5.12, §11.2)       |
| **provider**           | Un destino de inferencia. Registro abierto (D-17)                                                                                                                    | `Gunther.Provider` (§5.1)     |
| **nodo**               | Otra máquina cuyo engine se gestiona como propio (D-66)                                                                                                              | §18                           |
| **decisión**           | A qué modelo va una petición, con ranking y traza                                                                                                                    | `Gunther.Router.route/2` (§6) |
| **modelo de decisión** | Modelo especializado que ordena candidatos (D-68)                                                                                                                    | §6.11                         |
| **tool**               | Función invocable por el modelo, local o MCP                                                                                                                         | `Gunther.Tools` (§9)          |
| **coral**              | La infraestructura integrada de Gunther más la base para organizar grupos de agentes; colmena, equipo de trabajo y votación de enrutado son modalidades suyas (D-74) | `Gunther.Coral` (§22)         |
| **miembro**            | Un proceso en ejecución que desempeña un rol en una modalidad de la coral (D-14, D-74)                                                                               | `Coral.Member` (§22)          |
| **plan**               | Estructura de datos única que describe roles, pizarra y pasos de una coral                                                                                           | §22.5                         |
| **pizarra**            | Memoria compartida de una ejecución de la coral                                                                                                                      | §22.6                         |

En código, en inglés: `capabilities` para skills y `vram_mb` para recursos. En prosa, «skill» y «recurso».

### 1.4 Decisiones D-01 a D-47

Resumen de una línea. El porqué vive en el ADR. Las marcadas con † no se entienden sin él.

| #     | Idea                                                     | #     | Idea                                                                                                                |
| ----- | -------------------------------------------------------- | ----- | ------------------------------------------------------------------------------------------------------------------- |
| D-01  | El centro de gravedad es el enrutado                     | D-25  | Agentes sin nombre: identidad derivada                                                                              |
| D-02  | Taxonomía de skills cerrada. **Ratificada en r8 (Q-16)** | D-26  | Clave desconocida en config: aviso, no fallo. **Excepción de r6 (CE-H11)**: error en secciones de seguridad (§14.2) |
| D-03  | Capacidad entera, cuota decimal                          | D-27† | Device y peso calculado; `vram_mb` es cota inferior                                                                 |
| D-04† | N/A ≠ 0; «no lo sé» es un estado                         | D-28† | Device = slot con nombre, una fuente de medida. **Refinado por D-65**                                               |
| D-05† | Las siete hermanas desde su `main`                       | D-29  | El LLM decide (capa `:llm`). **Refinado por D-68**                                                                  |
| D-06  | Sin clasificador ni embedder por defecto                 | D-30  | «Mente colmena» como nombre. **Sustituida por D-74 en el nombre (M-03, Q-13)**                                      |
| D-07  | Enrutado = fase 3 (ahora F4)                             | D-31  | Framework sin CLI                                                                                                   |
| D-08  | `one_for_all` = `rest_for_one` con peticiones atómicas   | D-32  | Tool-calling de primera clase                                                                                       |
| D-09  | Refusal configurable: `fail`, `wait`, `degrade`          | D-33  | Salidas estructuradas                                                                                               |
| D-10  | Fase cerrada por ejecución real                          | D-34  | Multimodal passthrough                                                                                              |
| D-11† | Lo no decidido, escrito                                  | D-35  | MCP con transporte propio                                                                                           |
| D-12  | Gunther no juzga respuestas                              | D-36  | RAG completo (ADR en `ADR-036-rag.md`)                                                                              |
| D-13† | Frontera con Arrea                                       | D-37  | Sesiones como contrato                                                                                              |
| D-14  | «Agente» = el proceso                                    | D-38  | Prompts versionados                                                                                                 |
| D-15  | Scheduler justo + prioridad como peso                    | D-39  | Evaluación como contrato                                                                                            |
| D-16  | Arrea mide, Gunther consume (ver D-48)                   | D-40  | Guardrails                                                                                                          |
| D-17  | `Provider` = registro                                    | D-41  | Reparto en v1 (Selector + Placer)                                                                                   |
| D-18† | La librería es sustrato                                  | D-42  | Cancelación propagada                                                                                               |
| D-19  | `rest_for_one` no se implementa                          | D-43  | Contexto gestionado                                                                                                 |
| D-20† | Breaker: ahora es `Arrea.CircuitBreaker`                 | D-44  | Caché de completions (retirada de v1)                                                                               |
| D-21† | `:degrade` se reinterpreta (= D-23)                      | D-45  | Registry por instancia                                                                                              |
| D-22  | Memoria = mapa KV                                        | D-46  | Contrato de voces. **Revisada por D-74 (M-03, Q-13)**                                                               |
| D-24  | = D-19                                                   | D-47  | Integración con el ecosistema (revisada en §3)                                                                      |

Notas de r8:

- **D-30** y **D-46** quedan sustituidas en lo relativo a «colmena / mesa camilla / voz» por D-74. Los nombres `Hive`, `Voice` y `register_voice/3` de r5/r6 no existen como módulos en r8; ver la tabla de renombrado de §0.2 y el ADR D-74.
- **D-48** y **D-91** se mantienen con la nota de Q-14 (§3.2).

### 1.5 Decisiones de r5 \[P\], aún pendientes

| #    | Propuesta                                                                                                                                | §         | Estado en r8                                                                         |
| ---- | ---------------------------------------------------------------------------------------------------------------------------------------- | --------- | ------------------------------------------------------------------------------------ |
| D-48 | El ledger de recursos es de Gunther (`Gunther.Resource.Ledger`). `Arrea.Resource` no se adopta en v1 (existe en `main` según la medición del dueño (D-13); su publicación en Hex está pendiente de G-28; ver Q-14) | 3.2, 11.3 | aceptada                                                                             |
| D-49 | Un paquete, dependencias opcionales, CI de fronteras                                                                                     | 0.4       | aceptada                                                                             |
| D-50 | Ejecución de comandos en dos modos: corto (`SafeCommand`) y proceso largo (sin shell, validado antes)                                    | 3.4       | aceptada                                                                             |
| D-51 | Pipeline de resiliencia con orden fijo                                                                                                   | 2.5       | aceptada                                                                             |
| D-52 | Failover entre candidatos: `Decision` lleva el ranking completo                                                                          | 2.5, 6.7  | aceptada                                                                             |
| D-53 | El scheduler se parte en Selector y Placer                                                                                               | 5.8, 11.4 | aceptada                                                                             |
| D-54 | MCP en la revisión 2026-07-28, con compatibilidad 2025-11-25                                                                             | 9.2       | aceptada                                                                             |
| D-55 | La caché de decisiones guarda solo el ranking puro                                                                                       | 6.5       | aceptada                                                                             |
| D-56 | Hive y voces a v1.1 experimental; en v1, varios `Classifier`                                                                             | 10.2      | **Sustituida por D-74 (M-03, Q-13)**: la colmena es la modalidad `:hive` de la coral |
| D-57 | `Response.warnings`; `:degraded` deja de ser un error                                                                                    | 4.2       | aceptada                                                                             |
| D-58 | Behaviour `Gunther.Tokenizer`                                                                                                            | 7.6       | aceptada                                                                             |
| D-59 | Behaviour `Gunther.Detector` (**ampliado por D-65 y D-69**)                                                                              | 5.12      | aceptada                                                                             |
| D-60 | Modelo de amenazas; gateway en loopback por defecto                                                                                      | 15        | aceptada                                                                             |
| D-61 | `stop/1` apaga los engines propios por defecto; el reaper solo mata lo marcado                                                           | 2.8       | aceptada                                                                             |
| D-62 | `Provider.send/2` a `chat/2`; `Hive.send/2` a `Coral.tell/2` (M-03)                                                                      | 5.1, 10.2 | aceptada                                                                             |

### 1.6 Decisiones nuevas de r6 \[P\]

Treinta (D-63 a D-92: las de r6, la adenda de la coral y las resoluciones de r7), motivadas por peticiones explícitas del dueño. **Todo lo demás de r6 son cierres de especificación (CE) y no abren decisión** (Anexo B).

> **Actualización de r8 (DP0):** todas las decisiones D-48 a D-92 han sido **aceptadas** por el dueño. Ver `docs/08-decisiones/README.md` actualizado y §21 para las preguntas cerradas.

| #    | Propuesta                                                                                                                                                                                                                                                                                                    | §                |
| ---- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ | ---------------- |
| D-63 | El proyecto se llama **Gunther** (tabla de renombrado en §0.2)                                                                                                                                                                                                                                               | 0.2              |
| D-64 | Regla de no-suposición y lint de documento                                                                                                                                                                                                                                                                   | 0.6              |
| D-65 | El device se identifica por `physical_id`; el ledger se indexa por él, no por el nombre de backend. El detector por defecto consulta `--list-devices` del binario de engine                                                                                                                                  | 5.12, 11.2, 11.8 |
| D-66 | **Nodos remotos gestionados**: plano de control propio (HTTPS + mTLS) y plano de datos mediado por el agente de nodo; el backend RPC de llama.cpp queda excluido \[V\]                                                                                                                                       | 18               |
| D-67 | Los **perfiles de engine** se definen en el nodo; el controlador nunca envía líneas de comando ni rutas                                                                                                                                                                                                      | 18.4             |
| D-68 | **Modelos de decisión especializados**: toda decisión del router y de los miembros de la coral pasa por un `Classifier` con `DecisionSpec`; autoridad acotada; activación condicionada a evaluación                                                                                                          | 6.11, 6.12, 10.2 |
| D-69 | Backends GPU soportados en v1: **CUDA, Vulkan, ROCm, Metal** y CPU, con matriz de capacidades por backend                                                                                                                                                                                                    | 11.7             |
| D-71 | **Alcance fijado por el dueño**: Windows fuera; Gunther **no descarga ni distribuye modelos**; gestiona arranque y parada de los instalados con tope de memoria y de conteo (`placement.max_loaded_models`); el decisor debe ser multilingüe y multi-tipo y **no se fija un modelo**, lo elige la evaluación | 3.4, 6.11, 11.4  |
| D-70 | El lanzamiento de procesos largos se hace a través de un contrato `Spawner` con requisitos medibles; la implementación se elige por la matriz de G-08                                                                                                                                                        | 3.4              |
| D-72 | **El modelo decisor es agnóstico y personalizable**: plantilla, parser, forma de salida e idiomas son configuración; las recomendaciones viven en la documentación; la verificación es **relativa a una línea base con intervalo de confianza**, no a umbrales fijados a mano                                | 6.11, 16.4       |
| D-73 | Publicación: paquete `gunther` en Hex; licencia con atribución al autor; política de contribución por _issues_ en GitHub (§0.5)                                                                                                                                                                              | 0.5              |
| D-74 | **La coral**: infraestructura integrada más una base de agentes organizados; colmena (antes «mesa camilla») y equipo de trabajo son modalidades. Sustituye a Hive y Voice; revisa D-30, D-46 y D-56                                                                                                          | 22               |
| D-75 | Un solo `Plan` como estructura interna; tres vías (datos, TOML, DSL de Elixir); condiciones de lenguaje cerrado; el TOML no ejecuta código                                                                                                                                                                   | 22.5, 22.10      |
| D-76 | Terminación garantizada: grafo acíclico, bucles acotados y todos los límites declarados                                                                                                                                                                                                                      | 22.5, 22.11      |
| D-77 | Pizarra por ejecución con versión, autor, comparación y cambio, suscripción acotada y acceso por rol; promoción explícita a `Memory`                                                                                                                                                                         | 22.6             |
| D-78 | Mensajería nativa de OTP en estrella, buzones acotados y correlación; `Run`, `Member` y `Monitor` propios con la forma de Leader, Worker y Monitor de Arrea; Arrea como anfitrión opcional según G-28                                                                                                        | 22.7, 22.15      |
| D-79 | Consenso como behaviour; texto libre solo mediante juez o síntesis                                                                                                                                                                                                                                           | 22.8             |
| D-80 | `Gunther.Context`: sobre único de contexto en toda la coral                                                                                                                                                                                                                                                  | 22.3             |
| D-81 | Contexto portable y política de cambio de modelo, verificada con corpus de continuidad                                                                                                                                                                                                                       | 22.12            |
| D-82 | Afinidad de caché en el router como preferencia blanda configurable                                                                                                                                                                                                                                          | 22.12            |
| D-83 | Reanudación al menos una vez por paso, con registro de intención de llamadas con efectos y `on_uncertain`                                                                                                                                                                                                    | 22.11            |
| D-84 | Planes dinámicos (`expand`): opcionales y apagados por defecto                                                                                                                                                                                                                                               | 22.5.3           |
| D-85 | Ganchos G1 a G9 a decidir antes de 1.0                                                                                                                                                                                                                                                                       | 22.14            |
| D-86 | Evoluciones propuestas para Arrea (A-1 a A-8), sin cambiar su dominio                                                                                                                                                                                                                                        | 22.15            |
| D-87 | Sección `[consumers.<id>]` con `default_model` obligatorio, `priority` opcional, envejecimiento del `Selector` y **reglas por consumer** (`[[consumers.<id>.rules]]`) con la precedencia de §6.8.1 (resuelve J-05, J-08 y Q-15)                                                                              | 5.8, 6.8.1, 14.1 |
| D-88 | Defecto del refusal: `wait`; las dos reglas que ningún valor puede cambiar (ni vetados ni números que mienten) (resuelve J-04)                                                                                                                                                                               | 6.9              |
| D-89 | Colocación y medida: tres estados de la reserva, reintento en otro device, capas enteras, una sola fuente de medida por device (convenciones A y B) (resuelve J-12 a J-16)                                                                                                                                   | 11.1, 11.3       |
| D-90 | Memoria KV con autor, versión y `superseded_by`; evento de calidad del provider (resuelve J-06, J-11)                                                                                                                                                                                                        | 7.2, 13.1        |
| D-91 | Precedencias entre D-01 a D-28 y el SPEC vigente (resuelve J-00 a J-03, J-07, J-09, J-10). **Q-14 cerrada en r8**                                                                                                                                                                                            | 1.4, Anexo B.3   |
| D-92 | Resoluciones del RAG y adjuntos: SQLite en F11, `router.embedding.min_similarity` con defecto y verificación, límite de cuerpo del gateway con adjuntos (resuelve I-12, I-14, I-15, I-20)                                                                                                                    | 8, 12.2          |

### 1.7 Estado de las decisiones en r8

| Bloque                | Rango       | Estado en r8                                                                               |
| --------------------- | ----------- | ------------------------------------------------------------------------------------------ |
| Decisiones originales | D-01 a D-28 | `aceptada` (con las notas de r7 y las de §1.4 de r8)                                       |
| Decisiones de r6      | D-29 a D-47 | `aceptada` (D-34, D-35, D-36, D-38, D-41, D-44 ya lo estaban; el resto ratificadas en DP0) |
| Decisiones de r6      | D-48 a D-62 | `aceptada` (DP0, r8)                                                                       |
| Decisiones de r6      | D-63 a D-73 | `aceptada` (DP0, r8)                                                                       |
| Coral                 | D-74 a D-86 | `aceptada` (DP0, r8)                                                                       |
| Resoluciones r7       | D-87 a D-92 | `aceptada` (DP0, r8)                                                                       |
| Preguntas abiertas    | Q-01 a Q-16 | **Todas cerradas** (§21)                                                                   |

---

## 2 · Arquitectura

### 2.1 Módulos, eje y fases

| #   | Módulo                  | Qué es                                                                                                                 | Fases (§19)                   |
| --- | ----------------------- | ---------------------------------------------------------------------------------------------------------------------- | ----------------------------- |
| 01  | Routing y ciclo de vida | Decide a qué modelo va cada prompt; el engine ocupa la GPU solo cuando hace falta; engines locales y de nodos          | F1 a F6, F15                  |
| 02  | Contexto compartido     | Sesiones, memoria KV, compactación, plantillas                                                                         | F8                            |
| 03  | RAG                     | Chunker, embedder, store, retriever, reranker, rewriter, eval                                                          | F11, F12                      |
| 04  | MCP y tools             | Registro único; servidor y cliente MCP                                                                                 | F7, F13                       |
| 05  | Agentes                 | Agente-proceso                                                                                                         | F14                           |
| 06  | La coral                | Grupos de agentes organizados por un plan: modalidades (colmena, equipo, propias), pizarra, mensajería, consenso y DSL | F18 a F22 (posteriores a 1.0) |

El **reparto** es el eje: `Selector` (equidad) + `Placer` (colocación) (D-41); sin él no hay reparto que medir.

### 2.2 Los procesos

| Proceso                      | Naturaleza                                                                                                                                            | Ciclo de vida                 | Estado                                                                                                               |
| ---------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------- | ----------------------------- | -------------------------------------------------------------------------------------------------------------------- |
| **Router**                   | Función **sin efectos sobre el engine**. Lee catálogo, caché y memoria; puede llamar a embedder y clasificador. **No es pura**: la capa `:llm` es I/O | Por llamada                   | `%Decision{}`                                                                                                        |
| **Engine**                   | Proceso por modelo (local o remoto): reserve → start → health → run → stop                                                                            | Por modelo cargado            | `:reserved → :starting → :running → :stopping → :stopped` (también `:failed`, `:crashed`, `:unreachable` en remotos) |
| **Sesión**                   | Hilo conversacional                                                                                                                                   | Abrir y cerrar es del usuario | `:open → :compacting → :open`, `:closed`                                                                             |
| **Conexión de nodo**         | Un proceso por nodo remoto: heartbeat, espejo del ledger, eventos                                                                                     | Por nodo configurado          | `:connecting → :connected → :unreachable` (§18.5)                                                                    |
| **Coral** (v1.1 en adelante) | Ejecuciones de grupos de agentes                                                                                                                      | Por ejecución                 | Plan, pizarra y miembros (§22)                                                                                       |

**Regla**: el router no conoce al engine. Se comunican por el catálogo: el router elige un alias y el engine lo resuelve a un destino real (local, de nodo o externo).

### 2.3 El árbol de supervisión

`Gunther.start_link/1` y `Gunther.child_spec/1` arrancan:

```
Gunther.Supervisor (one_for_one, hijos en este orden)
├── Config.Server          valida y guarda la config; swap atómico de snapshot
├── Catalog.Server         modelos, providers, nodos; snapshots inmutables versionados
├── TaskSupervisor         Task.Supervisor para fan-out, clasificadores, streams
├── Telemetry.Bridge       reenvía eventos selectivos de Arrea y Apero (§3.5)
├── Memory.Server          KV en ETS
├── Cache.Decisions        caché propia con tope y LRU exacto (CE-06)
├── Selector.Server        estado del reparto por consumer (CE-09)
├── Tools.Server           tabla única de tools
├── Resilience.Supervisor  breakers, bulkheads y rate limiters por provider y modelo
├── Resource.Ledger        ledger de recursos (D-48), indexado por physical_id (D-65)
├── Placement              semáforos de colocación, uno por nodo (§11.4)
├── Node.Supervisor        DynamicSupervisor: una conexión por nodo remoto (§18)
├── Engine.Supervisor      DynamicSupervisor: un engine por modelo cargado
├── Session.Supervisor     DynamicSupervisor
├── MCP.Client.Supervisor  DynamicSupervisor
├── Agent.Supervisor       DynamicSupervisor
└── Coral.Supervisor       solo con `[coral] enabled = true` (§22)
```

`Gunther.Gateway` y `Gunther.MCP.Server` **no están en el árbol** (D-31): los arranca la aplicación del usuario. El **agente de nodo** (`Gunther.Node.Agent`) tampoco: es una aplicación aparte que corre en el otro PC (§18.2).

**Estrategias**: raíz `one_for_one`; los `DynamicSupervisor`, `one_for_one`. `rest_for_one` no se implementa (D-19).

**Sin `rest_for_one`, la consistencia sale de la rehidratación.** Cada hijo con estado debe poder reconstruirse tras un reinicio:

- **Ledger**: en `init/1` mide con el `Detector` de cada nodo, y **reconcilia** los engines vivos (CE-05, §2.8): los adopta si superan la verificación de identidad; si no, no los toca. Si un engine vivo no se puede reconciliar, el device se marca `usable: false` hasta resolverlo.
- **Catalog**: se reconstruye desde `Config.Server`.
- **Conexiones de nodo**: se reconstruyen desde el catálogo y reconcilian con el nodo por `GET /engines` y `GET /leases` (§18.5).
- **Engines**: son procesos del SO; mueren con su `Port` o los recoge el reaper (§2.8).

**Arrea y Apero arrancan solos** como aplicaciones OTP \[V5\]. Gunther no los supervisa. Su árbol interno usa `rest_for_one` \[V\] y no es asunto de Gunther.

### 2.4 El flujo de una petición

```
Gunther.chat(messages, opts)
 0. Validar forma, roles y tamaño máximo           → :invalid_request
 1. Guardrails de input (§16.1)                     → :guardrail_input_veto
 2. Contexto: sesión (§7.1) + memoria KV (§7.2) + RAG (§8)
      el contenido de RAG y de tools se marca untrusted (§15)
 3. Decisión: Router.route/2 → %Decision{ranked: [...]}   (§6)
      el modelo de decisión solo ve texto de autoría del caller (§6.12)
 4. Admisión: presupuesto (§11.6) y refusal (§6.9)
 5. Ejecución con failover sobre decision.ranked:
      pipeline de resiliencia (§2.5) → engine local, engine de nodo o provider
      structured output con validación y reintento (§4.2) si hay response_format
 6. Tool loop si hay tool_calls y run_tools (§9.4), con permisos (§9.3)
 7. Guardrails de output (§16.2)
 8. Post: coste, telemetría, memoria, sesión, traza
 9. {:ok, %Response{warnings: [...], degraded: boolean}}
```

Cada paso se salta desde fuera:

| Opt                 | Efecto                                 | Defecto |
| ------------------- | -------------------------------------- | ------- |
| `decision: :none`   | No enruta; exige `model:`              | `:auto` |
| `trace: true`       | Incluye la traza en la respuesta       | `false` |
| `memory: false`     | No lee ni escribe la memoria KV        | `true`  |
| `session: nil`      | Sin sesión                             | `nil`   |
| `rag: nil`          | Sin RAG                                | `nil`   |
| `guardrails: false` | Sin guardrails                         | `true`  |
| `run_tools: false`  | Devuelve los `tool_calls` sin ejecutar | `true`  |

### 2.5 El pipeline de resiliencia \[P — D-51, D-52\]

Orden de fuera a dentro:

| #   | Capa               | Primitiva                                                 | Por qué en esta posición                                                                          |
| --- | ------------------ | --------------------------------------------------------- | ------------------------------------------------------------------------------------------------- |
| 1   | Retry              | `Apero.Retry` \[V5\] (backoff exponencial con jitter)     | Fuera de todo, para reintentar la cadena completa. Solo si `retryable?`; respeta `retry_after_ms` |
| 2   | Rate limit         | `Arrea.RateLimiter` por provider \[V5\]                   | Dentro del retry: cada intento es una llamada real y consume cuota                                |
| 3   | Bulkhead           | `Arrea.Bulkhead` por modelo \[V5\]                        | Dentro del retry: el slot se ocupa durante la llamada, no durante el backoff                      |
| 4   | Circuit breaker    | `Arrea.CircuitBreaker` por provider \[V5\]                | Lo más interno: solo ve fallos reales del provider                                                |
| 5   | Timeout de intento | `retry.attempt_timeout_ms`                                | Acota cada llamada                                                                                |
| 6   | Llamada            | `Provider.chat/2` o `stream/3` (o el backend remoto, §18) |                                                                                                   |

**Presupuesto de tiempo \[CE-12\]**: `opts.timeout` es el **plazo total** de la petición (retries, failovers y structured retries incluidos). Al empezar se fija `deadline = monotonic_now + timeout`. Cada intento recibe `min(retry.attempt_timeout_ms, deadline − now)`. Si `deadline − now ≤ 0`, `{:error, :timeout}`. Un backoff nunca duerme más de `deadline − now`.

**Qué hace cada error \[CE-13\]** (tabla completa; un error que no esté aquí es `:internal_error`):

| Error                                                             | Retry (capa 1)                 | Failover              | Cuenta en breaker             |
| ----------------------------------------------------------------- | ------------------------------ | --------------------- | ----------------------------- |
| timeout de intento                                                | Sí                             | Sí, tras agotar retry | Sí                            |
| error de conexión, `:node_unreachable`                            | Sí                             | Sí, tras agotar retry | Sí                            |
| 5xx                                                               | Sí                             | Sí, tras agotar retry | Sí                            |
| 429 con `retry_after_ms` ≤ `deadline − now`                       | Sí, esperando `retry_after_ms` | Sí, tras agotar retry | No (alimenta al rate limiter) |
| 429 con `retry_after_ms` > `deadline − now`                       | No                             | Sí, inmediato         | No                            |
| otros 4xx                                                         | No                             | No                    | No                            |
| `:bulkhead_full`                                                  | No                             | Sí, inmediato         | No                            |
| `:rate_limited` local                                             | No                             | Sí, inmediato         | No                            |
| breaker abierto (`:provider_unavailable`)                         | No                             | Sí, inmediato         | n/a                           |
| `:overloaded` (bulkhead global)                                   | No                             | No                    | No                            |
| `:invalid_structured_output` tras agotar `structured.max_retries` | No                             | Sí                    | No                            |
| `:stream_interrupted` antes del commit (§2.9)                     | Sí                             | Sí                    | Sí                            |
| `:stream_interrupted` después del commit                          | No                             | No                    | Sí                            |
| `:cancelled`, vetos de guardrail, `:invalid_request`              | No                             | No                    | No                            |

**Failover**: pasa al siguiente candidato de `decision.ranked`, hasta `router.max_failovers` (defecto 2). Cada salto queda en `Decision.degraded` y como warning `:failover`. Reintentos, saltos e iteraciones del tool loop **se acumulan** contra el mismo presupuesto (§11.6) y el mismo plazo.

### 2.6 Concurrencia y backpressure

| Nivel      | Primitiva               | Límite                                | Al llenarse                                  |
| ---------- | ----------------------- | ------------------------------------- | -------------------------------------------- |
| Por modelo | `Arrea.Bulkhead`        | `max_concurrency` (4)                 | `{:error, :bulkhead_full}`, falla rápido     |
| Total      | `Arrea.Bulkhead` global | `router.max_in_flight` (256)          | `{:error, :overloaded}` con `retry_after_ms` |
| Sesiones   | `Session.Supervisor`    | `sessions.max_sessions` (1024)        | `:too_many_sessions`                         |
| Agentes    | `Agent.Supervisor`      | `agents.max_agents` (64)              | `:too_many_agents`                           |
| Nodos      | Conexión de nodo        | `nodes.max_inflight_control` por nodo | `:overloaded`                                |

Nunca se bloquea al caller sin timeout. **Toda tabla ETS y toda cola de Gunther tiene tope declarado** (§17). Se elimina `queue_max` del esquema de modelos.

### 2.7 Aislamiento: instancias

`Gunther.start_link(registry: MyRegistry, name: MyGunther)` (D-45) aísla dos árboles en la misma VM. Tests `async: true`: cada test arranca su propio árbol.

**Límite conocido**: `Arrea.Registry`, `Arrea.CircuitBreaker.Registry` y la config de Arrea (`config :arrea, :engine`) son **globales** \[V\]. Todos los nombres de breaker, bulkhead y rate limiter llevan el prefijo `{Gunther, instance, ...}`. Si `Arrea.CircuitBreaker` no admite umbrales por breaker (G-02), `circuit_breaker.*` queda global y se documenta; la rama alternativa de G-02 evalúa `resiliency`.

### 2.8 Arranque y parada \[P — D-61\]

**Arranque**: validar config (fallar pronto con `config_error`) → `Gunther.Doctor` opcional (§4.12) → reaper y reconciliación → hijos en orden → carga de modelos `resident` (§6.11).

**Marca de instancia**: todo proceso lanzado por Gunther lleva el argumento inerte `--alias gunther-<instance>-<alias>` (el flag `--alias` existe en `llama-server` \[V\]). No se usa el nombre del ejecutable para identificar nada.

**Estado en disco \[CE-05\]**: `<state_dir>/instances/<instance_id>/engines.json`, escrito de forma atómica (`Apero.File`). Un registro por engine: `{alias, node, os_pid, port, started_at_unix, binary_realpath, args_sha256, reserved_mib, device_physical_id}`.

**Reconciliación (CE-05)**, para cada registro, en este orden y sin saltarse pasos:

| Paso | Comprobación                                                                                                   | Si falla                                                                                     |
| ---- | -------------------------------------------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------- |
| 1    | `os_pid` vivo (`Trebejo.Proc`)                                                                                 | Borrar registro, liberar reserva                                                             |
| 2    | La línea de comandos del PID contiene la marca exacta `--alias gunther-<instance>-<alias>` (cómo se lee: G-13) | El PID fue reutilizado por otro programa: borrar registro **sin enviar señales**             |
| 3    | `GET /v1/models` del puerto devuelve `id` igual a la marca (con la clave de API del engine)                    | Registro dudoso: no adoptar; SIGTERM → SIGKILL solo porque el paso 2 confirmó que es nuestro |
| 4    | `GET /health` responde 200 \[V: endpoint público\]                                                             | `:starting` hasta `engine.start_timeout_ms`; si vence, matar y borrar                        |
| 5    | Adoptar: `ledger.acquire(device, holder, reserved_mib)`                                                        | Si no cabe, matar y borrar                                                                   |

Esto cubre el caso de `keep_engines: true` seguido de un cierre manual del `llama-server` por el usuario: el paso 1 o el 2 lo detectan y no queda reserva fantasma. Si G-13 falla (no se puede leer la línea de comandos en el SO), **no se adopta nunca**: se mata lo que el registro identifique con PID y puerto coincidentes con respuesta de identidad (paso 3) y se arranca limpio.

**Parada** (`Gunther.stop/1`): drenar (no admitir peticiones nuevas, esperar hasta `shutdown_timeout_ms`, 30 000), parar los engines propios con SIGTERM, esperar y escalar a SIGKILL, liberar el ledger y **liberar los leases remotos** (§18.5). `keep_engines: true` los deja vivos y avisa por log. Un `Port` cerrado no mata un `llama-server` si el proceso no vigila su stdin, por eso la parada usa señales por PID.

### 2.9 Cancelación y streaming \[CE-14, CE-15\]

**Token de cancelación** (D-42): `Gunther.Cancel.new() :: %Gunther.Cancel{ref: :atomics.atomics_ref()}` (creada con `:atomics.new(1, signed: false)`). `Gunther.cancel(token)` hace `:atomics.put(ref, 1, 1)`; `cancelled?(token)` lee `:atomics.get(ref, 1) == 1`. Es O(1) y válido entre procesos. El provider recibe `opts.cancelled?` (función de aridad 0). Todo `Task` hijo de una petición se arranca bajo `TaskSupervisor` y se enlaza al token.

**Commit de un stream** (CE-15). Un stream se considera **empezado (commit)** en el instante en que Gunther entrega al cliente el primer `Chunk` que cumple **alguna** de: `delta` no vacío, `tool_call_delta` no nulo, `finish_reason` no nulo. Los chunks previos (anuncio de rol, metadatos, `delta` vacío) se **retienen** en un buffer interno de tamaño máximo `stream.pre_commit_buffer_chunks` (16). Reglas:

| Situación                                    | Comportamiento                                                                               |
| -------------------------------------------- | -------------------------------------------------------------------------------------------- |
| Error antes del commit                       | Failover según §2.5 (retry, luego siguiente candidato), con los chunks retenidos descartados |
| Error después del commit                     | `{:error, :stream_interrupted}`; sin failover ni retry                                       |
| Stream cierra sin ningún chunk con contenido | Commit en el cierre; `Response.content = ""` y warning `:empty_response`                     |
| Buffer pre-commit lleno sin contenido        | Commit forzado (se entregan los retenidos)                                                   |

**`stream!/2`** (idiomático) se implementa con `Stream.resource/3`: el productor es una tarea bajo `TaskSupervisor`; el consumidor demanda por lotes. Backpressure: el productor espera confirmación tras cada entrega y mantiene como máximo `stream.max_buffered_chunks` (64) sin consumir; al llenarse, deja de leer del socket (TCP aplica contrapresión). Si el consumidor abandona la enumeración (`after_fun`), se activa el token de cancelación, se espera hasta `stream.cancel_grace_ms` (1000) y se mata la tarea. **Invariante testeable**: tras abandonar un `stream!`, ningún proceso de la petición sigue vivo pasado `cancel_grace_ms`.

---

## 3 · Integración con arrea, apero y trebejo

**Veredicto**: las tres librerías se integran donde ya resuelven el problema. Esta sección sustituye a D-47 en su forma de r4.

### 3.1 Principios

1.  **Se integra donde la librería ya resuelve el problema** y reimplementarlo no aporta nada: hash, carga de config, retry, circuit breaker, bulkhead, rate limit, validación de comandos.
2.  **No se integra donde el encaje es forzado**: el ledger de VRAM, el worker pool para `llama-server`, `SafeCommand` como transporte de procesos largos y la caché con tope (requisitos de §3.3).
3.  **Capa anticorrupción**: cada librería se toca desde un módulo de frontera (§3.6). Si una cambia, afecta a un fichero.
4.  **Una sola fuente de telemetría** hacia el consumidor, por puente selectivo (§3.5).
5.  **Etiquetas honestas**: cada fila dice qué es \[V5\] y qué es \[G\]. Las puertas se convierten en tests de F0 con ramas definidas (Anexo C).

### 3.2 Arrea: resiliencia y ejecución

| Módulo de Arrea                               | ¿Se usa?                     | Dónde y cómo                                                                                                                                                                                                                                                                                                                                                                                 | Estado                                                                                                                        |
| --------------------------------------------- | ---------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------- |
| `Arrea.CircuitBreaker`                        | **Sí**                       | §2.5 capa 4. Un breaker por provider, nombre `{Gunther, instancia, :breaker, provider}`                                                                                                                                                                                                                                                                                                      | \[V5\] existe y hace single-flight. **G-02** (umbrales por breaker, firma de `call`) y **G-03** (una sola sonda en half-open) |
| `Arrea.Bulkhead`                              | **Sí**                       | §2.6, capa 3. Uno por modelo y uno global                                                                                                                                                                                                                                                                                                                                                    | \[V\] listado en el README de 3.0.0. \[V5\] falla rápido. **G-04** (firma)                                                    |
| `Arrea.RateLimiter`                           | **Sí**                       | §2.5 capa 2, por provider; config `rpm` y `tpm` en `[providers.X]`                                                                                                                                                                                                                                                                                                                           | \[V5\] envuelve `Apero.RateLimit`. **G-04** (API)                                                                             |
| `Arrea.Command` vía `Trebejo.SafeCommand`     | **Sí, solo comandos cortos** | §3.4                                                                                                                                                                                                                                                                                                                                                                                         | \[V5\]                                                                                                                        |
| `Arrea.Validation.Validator`                  | Sí, indirecto                | Valida ejecutables y argumentos de procesos largos antes del `spawn`                                                                                                                                                                                                                                                                                                                         | \[V5\] reglas: `no_rm_rf`, `no_sudo`, `no_dd`, `no_mkfs`, `no_fork_bomb`, inyección                                           |
| `Arrea.Telemetry`                             | Sí, por puente               | §3.5                                                                                                                                                                                                                                                                                                                                                                                         | \[V5\]                                                                                                                        |
| `Arrea.Result`, `Arrea.Error`                 | Solo en frontera             | `Gunther.Command` los traduce a `Gunther.Error`                                                                                                                                                                                                                                                                                                                                              | \[V5\]                                                                                                                        |
| `Arrea.WorkerPool`                            | **No en v1**                 | Un modelo local es un proceso con slots internos (`--parallel`) \[V\]; su concurrencia la limita el bulkhead                                                                                                                                                                                                                                                                                 | \[V5\] existe                                                                                                                 |
| **`Arrea.Resource`**                          | **No en v1** (D-48)          | Ledger propio. **Confirmado en r8 (Q-14):** `Arrea.Resource` **existe en `main` según la medición del dueño (D-13); su publicación en Hex está pendiente de G-28** (D-13: 23 KB, tests, `main` desde 2026-10-10). Se queda propio en v1 porque la semántica de §11.3 (`foreign` por proceso, `available` con quiescencia, memoria unificada) no está en `Arrea.Resource` y envolverlo cuesta más que mantenerlo. G-28 puede proponer una fachada en una fase posterior | Confirmado por D-13; ledger propio ratificado en Q-14                                                                         |
| `Arrea.Retry`                                 | No existe                    | Se usa `Apero.Retry`                                                                                                                                                                                                                                                                                                                                                                         | \[V5\] ausente                                                                                                                |
| `Arrea.run/2`, `Leader`, `Worker`, `Policies` | No                           | Gunther usa `Task.Supervisor` y `Task.async_stream`                                                                                                                                                                                                                                                                                                                                          | \[V\]                                                                                                                         |
| `Arrea.Config`                                | No escribir                  | Es global (`config :arrea, :engine`)                                                                                                                                                                                                                                                                                                                                                         | \[V\]                                                                                                                         |

### 3.3 Apero: utilidades puras

| Módulo de Apero                                                | Dónde y cómo                                                                                                                                                                                                         | Estado                                                   |
| -------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | -------------------------------------------------------- |
| `Apero.Crypto.sha256/1`                                        | IDs de documento y chunk (§8.5), claves de caché (§6.5), huella del catálogo, hash de argumentos                                                                                                                     | \[V5\] digest hexadecimal                                |
| `Apero.Conf.load/1`                                            | `Gunther.Config.Loader` (§14)                                                                                                                                                                                        | \[V5\] TOML, YAML, JSON. **G-07** si el parser no encaja |
| `Apero.Env`                                                    | Secretos: `api_key_env` se resuelve con `Apero.Env.fetch!/1`. **`.env` se carga solo si `config.dotenv = true` (defecto `false`)** \[CE-17\]: una carga automática es una fuente de filtraciones silenciosas         | \[V5\]                                                   |
| `Apero.Retry.with/2`                                           | §2.5 capa 1                                                                                                                                                                                                          | \[V5\]. **G-05** (predicado `retryable?`, `retry_after`) |
| `Apero.OS`                                                     | `Gunther.Platform`: elige `Detector` y rutas (WSL: `/usr/lib/wsl/lib`; macOS: Metal; contenedor: avisa de límites de cgroup)                                                                                         | \[V5\]                                                   |
| `Apero.Proc.command_exists?/1`                                 | `Gunther.Doctor`: comprueba que existe el ejecutable. **Internamente usa `which`, que es un subproceso trivial**; la garantía es «no se ejecuta el binario comprobado», no «no se lanza ningún subproceso» \[CE-16\] | \[V5\] `which`, `command_exists?`, `vm_memory`           |
| `Apero.File`                                                   | Persistencia atómica de `SessionStore`, `AgentStore` y `engines.json`                                                                                                                                                | \[V5\]                                                   |
| `Apero.Crypto` (cifrado)                                       | Cifrar y firmar (HMAC) lo persistido en disco (§15)                                                                                                                                                                  | \[V5\] AES-256-GCM                                       |
| `Apero.Cache`                                                  | **No se usa** \[CE-06\]. Los requisitos de Gunther (tope de entradas, LRU exacto, espacio de nombres por instancia, eventos) están en `Gunther.Cache`                                                                | Ver Anexo B                                              |
| `Apero.Llm.Health`, `Apero.Llm.ConfigManager`                  | Revisar solapamiento                                                                                                                                                                                                 | **G-21**                                                 |
| `Apero.Network`, `Apero.Packages`, `Apero.RateLimit` (directo) | No                                                                                                                                                                                                                   | —                                                        |

**`Gunther.Cache` \[CE-06\]** (sustituye a la caché sobre `Apero.Cache`): módulo propio con estos requisitos, todos con test:

| Requisito                      | Mecanismo                                                                                                                                                                                                                                                                          |
| ------------------------------ | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ----- | --------------------------------------------- |
| Tope de entradas `max_entries` | Contador en `:counters`; una inserción que lo supere expulsa antes de insertar                                                                                                                                                                                                     |
| Expulsión LRU **exacta**       | Dos tablas ETS: `data` (`{key, value, expires_at, last_used}`) e `index` (`ordered_set` de `{{last_used, seq}, key}`, donde `seq` sale de un contador `:atomics` y garantiza claves únicas: dos accesos en el mismo instante no colisionan). Expulsa el primer elemento del índice |
| TTL                            | Se comprueba al leer; barrido periódico cada `cache.sweep_interval_ms` (30 000)                                                                                                                                                                                                    |
| Escrituras serializadas        | Un `GenServer` propietario; lecturas directas a ETS con `read_concurrency: true`                                                                                                                                                                                                   |
| Actualización de `last_used`   | `GenServer.cast` desde el lector (consistencia eventual: una lectura puede quedar sin registrar si el sistema está sobrecargado; el tope y la corrección no dependen de ello)                                                                                                      |
| Espacio de nombres             | La clave incluye `{Gunther, instance, kind}`                                                                                                                                                                                                                                       |
| Observabilidad                 | `[:gunther, :cache, :hit                                                                                                                                                                                                                                                           | :miss | :evict]` con el hash de clave, nunca el valor |

### 3.4 Trebejo y `Gunther.Command`: shell y procesos

| Módulo de Trebejo                                                              | ¿Se usa?                     | Dónde y cómo                                                                                                  | Estado                                    |
| ------------------------------------------------------------------------------ | ---------------------------- | ------------------------------------------------------------------------------------------------------------- | ----------------------------------------- |
| `Trebejo.SafeCommand`                                                          | **Sí, solo comandos cortos** | `Gunther.Command.run/3`                                                                                       | \[V5\] envuelve `Arrea.Command.execute/2` |
| `Trebejo.Proc`                                                                 | **Sí**                       | Reaper y reconciliación (§2.8); `lsof` del puerto antes de arrancar; SIGTERM y SIGKILL. **No lanza procesos** | \[V5\]. **G-06b**: firmas exactas         |
| `Trebejo.OS`                                                                   | **Sí**                       | `Detector.Cpu`: memoria de sistema; arquitectura; aviso si corre como root                                    | \[V5\]                                    |
| `Trebejo.File`                                                                 | Sí, opcional                 | Recarga en caliente de `gunther.toml` (§14.4)                                                                 | \[V5\]                                    |
| `Trebejo.Docker`                                                               | Post-v1                      | Engines contenerizados                                                                                        | \[V5\] existe                             |
| `Trebejo.Network`, `Git`, `SSH`, `Kubernetes`, `Compress`, `Packages`, `Image` | **No**                       | Fuera de alcance. `Doctor` puede **sugerir** un comando como texto; nunca instala ni descarga                 | —                                         |

**Por qué `SafeCommand` no es el único punto de ejecución (D-50)**:

1.  Ejecuta a través de shell autodetectado y puede cargar ficheros de configuración del shell \[V5\]. `Gunther.Command.run` fuerza `/bin/sh` y desactiva la carga si la opción existe (G-06).
2.  Es una lista negra \[V5\]: defensa en profundidad, no frontera de seguridad. La frontera es que **ningún dato del modelo ni del usuario llega nunca a un comando** (§15) y que los argumentos se citan con quoting POSIX.
3.  Devuelve al terminar \[V5\]: no sirve de transporte duplex.
4.  Un `Port` cerrado no mata el proceso si este no vigila su stdin.

**`Gunther.Command`: dos modos y una sola puerta.**

| Modo  | API                      | Mecanismo                                                                                                                    | Para qué                                                                          |
| ----- | ------------------------ | ---------------------------------------------------------------------------------------------------------------------------- | --------------------------------------------------------------------------------- |
| Corto | `run(cmd, args, opts)`   | `Trebejo.SafeCommand`, `/bin/sh`, timeout real                                                                               | `nvidia-smi`, `rocm-smi`, `llama-fit-params`, `llama-server --list-devices`, `ps` |
| Largo | `spawn(cmd, args, opts)` | Valida con las mismas reglas; ejecutable de la **lista de permitidos**; abre el proceso **sin shell** a través del `Spawner` | `llama-server`, servidores MCP stdio                                              |

**Lista de permitidos \[CE-18\]** (`[commands] allow`): cada entrada es `{name, path, sha256?}`. Al arrancar se resuelve `path` a `realpath`; si hay `sha256`, se compara con el hash del fichero y un desajuste es `config_error`. En cada `spawn` se vuelve a resolver y se compara el `realpath` y el inodo con los fijados; un cambio **impide el lanzamiento** (`:command_blocked`). Un ejecutable fuera de la lista no se lanza nunca.

**Construcción de argumentos \[CE-19\]**: Gunther **no acepta líneas de comando libres**. Los argumentos de `llama-server` los produce `Gunther.Engine.LlamaCpp.ArgsBuilder` a partir de campos validados del perfil (§14). El perfil puede añadir `extra_args` solo si cada flag figura en `[engines.X] allowed_extra_args`. El README de `llama-server` documenta un flag que activa herramientas de agente integradas, incluidas ejecución de comandos y escritura de ficheros, y avisa de no usarlo en entornos no confiables \[V\]; el ArgsBuilder **no tiene campo** para ese flag y no puede añadirse por `allowed_extra_args` (lista de flags prohibidos en el código, con test).

**Contrato `Spawner` \[D-70, CE-20\]**: interfaz interna con requisitos medibles. Cada requisito tiene un test en F0 (G-08).

| Req. | Requisito                                                                                        | Obligatorio             |
| ---- | ------------------------------------------------------------------------------------------------ | ----------------------- |
| R1   | Sin shell intermedio                                                                             | Sí                      |
| R2   | `env` explícito: el proceso **no hereda** el entorno de la VM salvo las variables de `env_allow` | Sí                      |
| R3   | Directorio de trabajo (`cd`)                                                                     | Sí                      |
| R4   | `stdout` y `stderr` separados                                                                    | No (ver abajo)          |
| R5   | El hijo muere si muere la VM sin cooperación del hijo                                            | No (el reaper lo cubre) |
| R6   | `os_pid` disponible para señales                                                                 | Sí                      |
| R7   | Código de salida entregado al propietario                                                        | Sí                      |
| R8   | Contrapresión (lectura bajo demanda, `active: :once`)                                            | Sí                      |

Línea base: `Port.open({:spawn_executable, ruta}, args:, env:, cd:, ...)` con `:binary`, `:exit_status`, `:use_stdio`, `{:line, n}` o `:stream`. Un `Port` de Erlang ofrece `:stderr_to_stdout` y no un canal separado para `stderr` (R4) \[G-08: se comprueba\]. Consecuencias, normativas:

| Proceso            | `stderr`                                                            | Framing                                                                                                                                                      | Motivo                                                                                |
| ------------------ | ------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------ | ------------------------------------------------------------------------------------- |
| `llama-server`     | `:merge` (con `stdout`)                                             | `{:line, 8192}` a un anillo de las últimas `engine.log_lines` (2000) líneas                                                                                  | La salud se mide por HTTP; los logs sirven solo para diagnosticar un arranque fallido |
| Servidor MCP stdio | `:inherit` (va al `stderr` de la VM; **no** se mezcla con `stdout`) | `{:line, 65536}` con **reensamblado de `{:noeol, fragmento}`** hasta `mcp.max_message_bytes` (4 MiB); superarlo cierra la conexión con `:mcp_protocol_error` | Mezclar `stderr` en `stdout` corrompería el JSON-RPC                                  |

Si F0 demuestra que un candidato (por ejemplo `muontrap` o `erlexec`; su existencia y capacidades se verifican en G-08) cumple R1 a R8 **incluidos R4 y R5**, es elegible como implementación del `Spawner` bajo el mismo contrato. Regla de adopción: pasa todos los tests de R1 a R8, tiene una versión publicada en los últimos 24 meses y licencia OSI. Si ninguno la cumple, se queda la línea base con las consecuencias de la tabla.

**Regla de código**: ningún `System.cmd`, `:os.cmd` ni `Port.open` fuera de `Gunther.Command`. Se comprueba con grep en CI.

### 3.5 Telemetría: puente selectivo

`Gunther.Telemetry.Bridge` hace `:telemetry.attach_many` solo sobre los eventos que Gunther necesita y emite el equivalente con prefijo `[:gunther, ...]` y `trace_id` cuando el proceso llamante lo lleva en sus metadatos. Mapeo explícito: `[:arrea, :circuit_breaker, :open]` → `[:gunther, :breaker, :opened]`; `[:arrea, :validation, :failed]` → `[:gunther, :command, :blocked]`. El resto de eventos de Arrea y Apero siguen disponibles bajo su propio prefijo.

### 3.6 Módulos de frontera

| Módulo                  | Envuelve                                                                | Responsabilidad                                  |
| ----------------------- | ----------------------------------------------------------------------- | ------------------------------------------------ |
| `Gunther.Command`       | `Trebejo.SafeCommand`, `Arrea.Validation`, `Apero.Proc`, `Trebejo.Proc` | Dos modos, `Spawner`, marca de instancia, reaper |
| `Gunther.Resilience`    | `Arrea.CircuitBreaker`, `Bulkhead`, `RateLimiter`, `Apero.Retry`        | El pipeline de §2.5 como `call/3`                |
| `Gunther.Cache`         | ETS                                                                     | Caché con tope y LRU (§3.3)                      |
| `Gunther.Config.Loader` | `Apero.Conf`, `Apero.Env`, `Trebejo.File`                               | Carga, secretos, recarga                         |
| `Gunther.Platform`      | `Apero.OS`, `Trebejo.OS`                                                | SO, arquitectura, elección de `Detector`         |

**Regla**: fuera de estos cinco módulos, ningún otro del núcleo nombra `Arrea.`, `Apero.` ni `Trebejo.` (grep en CI). Excepción: los providers de referencia pueden usar `Apero.Crypto` y `Apero.Env`.

### 3.7 Verificación y plan B

Cada \[G\] de este documento tiene en el **Anexo C** su test binario y las dos ramas de diseño. Los tests corren en F0 y semanalmente en CI con `mix deps.update` de las tres hermanas. **Si una puerta falla, el diseño no se improvisa: se ejecuta la rama B ya escrita.** Las tres librerías son del mismo autor: ante una carencia, la primera opción es contribuir la mejora upstream, salvo que sea específica del dominio LLM.

---

## 4 · La API pública

Lo que no esté aquí es interno y puede cambiar sin aviso.

### 4.1 Ciclo de vida

```elixir
Gunther.start_link(opts) :: {:ok, pid} | {:error, term()}
Gunther.child_spec(opts) :: Supervisor.child_spec()
Gunther.stop(pid_o_nombre, opts \\ []) :: :ok
Gunther.health(pid_o_nombre) :: %{status: :ok | :degraded | :down, engines: [...], providers: [...], nodes: [...]}
```

| Opt                         | Defecto              | Efecto                                       |
| --------------------------- | -------------------- | -------------------------------------------- |
| `:name`                     | `Gunther.Supervisor` | Nombre del supervisor                        |
| `:config`                   | `gunther.toml`       | Ruta o mapa (§14)                            |
| `:registry`                 | `Gunther.Registry`   | Registry por instancia (D-45)                |
| `:telemetry_prefix`         | `[:gunther]`         | Prefijo de eventos                           |
| `:keep_engines` (en `stop`) | `false`              | `true` deja vivos los engines locales (§2.8) |

### 4.2 Inferencia

```elixir
Gunther.chat(messages | binary(), opts) :: {:ok, Response.t()} | {:error, Error.t()}
Gunther.stream(messages | binary(), opts, on_chunk) :: {:ok, Response.t()} | {:error, Error.t()}
Gunther.stream!(messages | binary(), opts) :: Enumerable.t()   # §2.9
Gunther.embed(texts, opts) :: {:ok, [[float()]]} | {:error, Error.t()}
```

`messages`: lista de `%{role: :user | :assistant | :system | :tool, content: content()}` o un `binary()`. `content()`: `binary()` o lista de parts `%{type: :text, text: _}`, `%{type: :image, url: _ | data: _, mime: _}`, `%{type: :audio, data: _, mime: _}` (D-34).

| Grupo      | Opt                                                            | Tipo y defecto                                                                                                                                                                            |
| ---------- | -------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Decisión   | `:model`                                                       | `atom() \| nil`, fuerza el destino (pin)                                                                                                                                                  |
|            | `:require`                                                     | `%{skills: [atom], locality: [:local \| :lan \| :cloud], tags: [atom]} \| nil`. Restringe el conjunto elegible **por llamada** (gancho G1); un `veto` o `force` de §6.8 siempre prevalece |
|            | `:consumer`                                                    | `atom()`, `:default`                                                                                                                                                                      |
|            | `:decision`                                                    | `:auto \| :none`; `:none` exige `:model`                                                                                                                                                  |
|            | `:trace`, `:trace_id`                                          | `false`; `binary() \| nil`                                                                                                                                                                |
| Contexto   | `:memory`, `:session`, `:rag`, `:compaction`                   | `true`, `nil`, `nil`, el de config                                                                                                                                                        |
| Inferencia | `:temperature`, `:top_p`, `:max_tokens`, `:stop`, `:seed`      | `0.7`, `1.0`, `nil`, `[]`, `nil`                                                                                                                                                          |
|            | `:timeout`                                                     | ms, **plazo total** (§2.5)                                                                                                                                                                |
|            | `:cancel`                                                      | `%Gunther.Cancel{}` (§2.9)                                                                                                                                                                |
|            | `:response_format`                                             | `:text \| :json \| {:json_schema, schema}` (§4.2.1)                                                                                                                                       |
|            | `:tools`, `:tool_choice`, `:run_tools`, `:max_tool_iterations` | `nil`, `:auto`, `true`, `5`                                                                                                                                                               |
|            | `:approve_tools`                                               | `[tool_call_id]`, aprueba tools en `:confirm` (§9.3)                                                                                                                                      |
|            | `:prompt`                                                      | `{nombre, versión} \| nil`                                                                                                                                                                |
|            | `:guardrails`                                                  | `boolean()`, `true`                                                                                                                                                                       |
|            | `:budget`                                                      | `%{max_cost_micros: n, max_tokens: n}` (§11.6)                                                                                                                                            |
|            | `:context`                                                     | `%Gunther.Context{}` (§22.3, gancho G2). Sin él se crea uno por defecto con estas opciones; si discrepan, ganan las opciones explícitas                                                   |

**Adjuntos (D-34)**: Gunther **no procesa** imágenes ni audio: no los redimensiona, no los convierte y no valida su formato; los envía tal cual al provider. `[[models]] max_attachment_bytes` fija el límite por tipo (defecto **20 MiB** para imágenes y **50 MiB** para audio); un adjunto mayor es `{:error, :invalid_request}` con `details.attachment_too_large`. El límite se mide sobre los bytes de `data`; un adjunto dado por `url` no se descarga ni se mide (lo resuelve el provider).

#### 4.2.1 Salida estructurada con fallback \[CE-01, D-33\]

Caso que r5 dejó sin especificar: un provider sin soporte nativo devolvía texto libre y `Response.structured` quedaba `nil` en silencio. Queda así:

1.  **Normalización**: el `schema` se normaliza a claves string y se valida como esquema (con el validador de §0.3). Un esquema inválido es `:invalid_request`.
2.  **Modo** (`structured.mode`, defecto `:auto`): si `supports?(:structured_output, model)` es `true`, se usa el mecanismo **nativo** del provider; si no, el modo **prompt**. `:native` y `:prompt` fuerzan uno de los dos. Forzar `:native` sobre un provider sin soporte es `:no_candidates` con `filtered: :no_structured_output`.
3.  **Nativo**: se envía el esquema al provider. Si el provider rechaza el esquema por características no soportadas (`:unsupported_schema`), se hace **una** degradación a modo prompt para ese candidato, con warning `:structured_fallback`.
4.  **Prompt**: se añade al `system` el esquema y la instrucción de responder **solo** con JSON.
5.  **Validación siempre**, también tras el modo nativo: `Jason.decode` y validación contra el esquema. En modo prompt, antes de decodificar, se recorta el espacio y se retira una única valla de código (` ```json … ``` `) si envuelve todo el contenido; no se hace ninguna otra extracción.
6.  **Reintento con retroalimentación**: si la validación falla, se repite la llamada añadiendo el error de validación y la salida inválida truncada a `structured.feedback_bytes` (2048). Hasta `structured.max_retries` (2) veces **sobre el mismo candidato**; cada reintento pasa por el pipeline de §2.5 y se acumula contra presupuesto y plazo.
7.  **Agotados los reintentos**: el candidato falla con `:invalid_structured_output`; el failover pasa al siguiente candidato que soporte el modo pedido (§2.5). Sin más candidatos: `{:error, :invalid_structured_output}`.
8.  **`:json`** (sin esquema): mismos pasos sin validación de esquema; solo JSON bien formado.
9.  **Con `stream`**: la validación ocurre **al terminar**. Si falla, `{:error, :invalid_structured_output}` tras haber entregado los chunks (no hay reintento tras el commit, §2.9). Está documentado y tiene test.

**Invariante**: si `response_format` es `:json` o `{:json_schema, _}`, un `{:ok, response}` **siempre** lleva `structured` distinto de `nil` y válido. Nunca `nil` en silencio.

```elixir
%Gunther.Response{
  content: binary(),
  model: atom(),                 # alias ganador
  provider: atom(),
  node: atom() | nil,            # nodo que sirvió la petición, nil si local o externo
  usage: %{input: n, output: n, cached_input: n | nil, reasoning: n | nil},
  finish_reason: :stop | :length | :tool_calls | :content_filter | :error,
  reasoning: binary() | nil,
  tool_calls: [%{id: _, name: _, arguments: map()}] | nil,
  structured: term() | nil,
  session: binary() | nil,
  trace: map() | nil,
  warnings: [%{code: atom(), message: binary(), details: map()}],
  degraded: boolean(),           # [CE-18b] ver regla abajo
  latency_ms: n,
  cost: %{input_micros: n, output_micros: n, total_micros: n} | nil,
  cache_hit: boolean(),
  provider_request_id: binary() | nil
}
```

**`degraded` \[CE-18b\]**: `true` si `Decision.degraded` no está vacío **o** hay algún warning con `code` en `[:degraded, :failover, :llm_timeout, :classifier_error, :classifier_unverified, :embedding_unavailable, :structured_fallback]`. `:context_compacted`, `:guardrail_modified` y `:empty_response` **no** cuentan. El consumidor distingue «respondió bien» de «respondió degradado» sin inspeccionar `warnings`.

```elixir
%Gunther.Decision{
  chosen: atom(), provider: atom(), node: atom() | nil,
  ranked: [atom()],              # D-52: ranking completo para failover
  reason: :cache | :pin | :rule | :embedding | :llm | :fallback | :veto | :force,
  layers_ran: [atom()],
  candidates_per_layer: [%{layer: atom(), before: n, after: n}],
  filtered: [%{model: atom(), reason: atom()}],
  degraded: [atom()],
  decision_model: %{id: atom(), kind: atom(), report_id: binary()} | nil,
  affinity: %{model: atom(), applied: boolean()} | nil,   # gancho G4 (§22.12)
  consumer_rules_applied: [atom()],   # M-01: `name` de las reglas de consumer que actuaron
  global_rules_applied: [atom()],     # M-01: `name` de las reglas globales que actuaron
  trace_id: binary(), duration_ms: n, timestamp: DateTime.t()
}

%Gunther.Error{code: atom(), message: binary(), retryable?: boolean(),
               retry_after_ms: n | nil, details: map(), cause: term() | nil}

%Gunther.Rag.Hit{id: _, chunk: _, score: float(), source: _, metadata: map(),
                 lexical: float() | nil, vector: float() | nil, rerank: float() | nil}

%Gunther.Stream.Chunk{delta: binary(), tool_call_delta: map() | nil,
                      finish_reason: atom() | nil, usage: map() | nil}
```

Los tool-calls en streaming salen como deltas con `index` y `arguments_fragment` (formato OpenAI). Gunther **acumula** los fragmentos y emite un `tool_call` completo al terminar.

### 4.3 El enrutado, aislado

```elixir
Gunther.Router.route(messages, opts) :: {:ok, Decision.t()} | {:error, Error.t()}
Gunther.Router.trace(decision) :: map()
```

`route/2` no llama a ningún modelo salvo que la capa `:llm` esté activa (§6.3). Es la función que mide el tribunal (§16.3).

### 4.4 Catálogo

```elixir
Gunther.Catalog.list() :: [model_info]
Gunther.Catalog.get(alias) :: {:ok, model_info} | :error
Gunther.Catalog.reload() :: :ok | {:error, Error.t()}   # swap atómico; en error se conserva el snapshot anterior
```

### 4.5 Cancelación

```elixir
Gunther.Cancel.new() :: Cancel.t()
Gunther.cancel(token) :: :ok
```

El provider **debe** consultar `opts.cancelled?.()` entre chunks y abortar (D-42). El `ContractTest` lo comprueba con un provider lento.

### 4.6 Memoria y sesiones

```elixir
Gunther.Memory.put(key, value, opts) / get(key, default, opts) / delete(key, opts) / keys(opts)
Gunther.Memory.put_new(key, value, opts) :: :ok | {:error, :exists}   # atómico (:ets.insert_new)
Gunther.Session.open(name, opts) :: {:ok, Session.t()} | {:error, Error.t()}
Gunther.Session.append(name, role, content) / history(name) / compact(name) / close(name) / list()
```

**`Session.open/2` \[CE-08\]**: abre **o reabre** de forma automática, en este orden: (1) si la sesión está cargada, la devuelve; (2) si el `SessionStore` tiene una guardada con ese nombre, la **carga** y la devuelve; (3) si no existe, la crea, salvo `create: false`, que devuelve `{:error, :session_not_found}`. No hay un `load/1` público: una sola operación. **Las sesiones tienen espacio de nombres por consumer** (`{consumer, name}`, CE-30): dos consumers pueden usar el mismo nombre sin verse. Una sesión `:closed` no se reabre (`:session_closed`). Una sesión descargada por `idle_ttl_seconds` sin `SessionStore` en disco **se pierde**, y `open/2` crea una nueva; con `Disk` se reabre con su historial.

**`Session.last_call/1`** (gancho G4) devuelve `%{model, provider, input, cached_input} | nil`, tomado de `Response.usage` de la última llamada de esa sesión; lo usan el cambio de modelo y la afinidad (§22.12). **Memoria (D-22, D-90)**: `Memory.put/3` acepta `author:` y `if_version:` (comparación y cambio, gancho G8); cada entrada guarda `meta: %{author, version, superseded_by}` y `Memory.supersede(key, new_key)` marca la anterior. Con espacio de nombres por consumer (`:global` es el ámbito compartido).

### 4.7 RAG

```elixir
Gunther.Rag.index(document, opts) :: :ok | {:error, Error.t()}
Gunther.Rag.query(text, opts) :: {:ok, [Hit.t()]} | {:error, Error.t()}
Gunther.Rag.delete(doc_id) / reindex(doc_id) / stats()
```

Opciones de `index`: `:source`, `:metadata`, `:chunker`, `:embedder`, `:store`, `:async`. Opciones de `query`: `:top_k` (5), `:strategy` (`:hybrid`), `:rerank` (`false`), `:rewrite` (`false`), `:filter`, `:min_score`, `:store`, `:retriever`, `:reranker`, `:rewriter` (estas cuatro, **solo para quien llama por API**: la tool `rag_query` no las expone). El RAG se consulta por cuatro puertas con una sola implementación: API directa, tool `rag_query`, `opts.rag` en `chat/2` y agentes, MCP y gateway (§8.8). Detalle en §8.

### 4.8 Tools y MCP

```elixir
Gunther.Tools.register(name, opts)
#   opts: description:, schema:, handler: fn args, ctx -> {:ok, term} | {:error, term} end,
#         source: :local | {:mcp, conn_id}, timeout_ms: 30_000, permission: :auto | :confirm | :deny,
#         side_effects: :none | :idempotent | :unsafe
Gunther.Tools.unregister(name) / list() / invoke(name, args, ctx)

Gunther.MCP.Server.start_link(transport: :stdio | {:http, port: n}, name: _)
Gunther.MCP.Client.connect({:stdio, cmd, args} | {:http, url, opts}) :: {:ok, conn}
Gunther.MCP.Client.import_tools(conn) / list_tools(conn) / disconnect(conn)
```

### 4.9 Agentes y coral

```elixir
Gunther.Agent.run(%Gunther.Agent{module:, consumer:, session:, tools:, hitl:, max_turns:, budget:, max_duration_ms:, initial:}, opts) :: {:ok, pid}
#   opts: :name, :store (AgentStore), :context (%Gunther.Context{}), :parent (pid; gancho G3)
Gunther.Agent.resume(pid, %{approve: [id], deny: [id], input: _}) / status(pid) / stop(pid)

# v1.1 (coral)
Gunther.Coral.run(mode_or_plan, input, opts) :: {:ok, run_ref} | {:error, Error.t()}
#   mode_or_plan: nombre de modalidad (p. ej. :hive) con sus parámetros, o un %Gunther.Coral.Plan{}
#   opts: :consumer, :budget, :max_duration_ms, :trace, :store, :context
Gunther.Coral.await(run_ref, timeout_ms) / status(run_ref) / events(run_ref) :: Enumerable.t()
Gunther.Coral.resume(run_ref, %{approve: [...], deny: [...], input: _}) / cancel(run_ref)

# v1.1 (registro de modalidades propias)
Gunther.Coral.register_mode(name, module, opts) :: :ok
Gunther.Coral.list_modes() :: [atom()]
```

**Notas:**

- `Coral.run/2` es la **única puerta de entrada**. Los miembros no se registran uno a uno: se declaran en los parámetros de la modalidad (`:hive` recibe `members:`; `:teamwork` recibe `roles:` y `steps:`). Esto simplifica la API frente a `Hive.register_voice/3` y hace que la pizarra y los límites sean por ejecución, no globales.
- `Coral.tell/2` y `Coral.broadcast/1` existen para la mensajería externa **hacia** una ejecución en curso (equivalente a lo que en r6 era `Hive.tell/2`), pero no son la vía principal de comunicación entre miembros: eso es `Coral.Message` (§22.7).
- `Coral.await/2` sustituye al `GenServer.call` bloqueante entre voces: no bloquea, devuelve un `Enumerable` de eventos.
- `Gunther.Voice` **no existe como behaviour** en r8. Los cuatro behaviours nuevos de la coral son `:coral_mode`, `:consensus`, `:step`, `:run_store` (§22.14, G9).

### 4.10 Gateway

```elixir
Gunther.Gateway.start_link(port: 4000, bind: {127, 0, 0, 1}, auth: :api_key, api_keys: [...], tls: [...])
Gunther.Gateway.stop()
```

Endpoints y reglas en §12.

### 4.11 Prompts, evaluación, registro, test de contrato, utilidades de test

```elixir
Gunther.Prompt.register(name, version, template) / render(name, version, assigns) / list() / delete(name, version)
Gunther.Eval.run(spec, opts) :: %{name:, metrics:, passed:, tolerance:, details:}
Gunther.Registry.register(type, module, opts) / unregister(type, module) / list(type) / resolve(type, module)
use Gunther.ContractTest, behaviour: Gunther.Embedder
Gunther.Testing   # público: Provider.Mock con guion, FakeGPU, FakeNode, helpers de instancia aislada
```

### 4.12 Doctor \[P\]

```elixir
Gunther.Doctor.run(opts) :: %{checks: [%{name:, status: :ok | :warn | :fail, hint: binary()}]}
Gunther.Doctor.calibrate_router(corpus, opts) :: {:ok, report_id} | {:error, Error.t()}   # §6.11
Gunther.Doctor.calibrate_rag(corpus, opts) :: {:ok, report_id} | {:error, Error.t()}      # §8.3
Gunther.Doctor.calibrate_overhead(backend, opts) :: {:ok, mib} | {:error, Error.t()}      # §11.3, convención B
```

Función, no CLI (D-31). Comprueba con `Apero.Proc.command_exists?/1` que existen los ejecutables de la config; versión de Elixir y OTP; permisos; puertos libres con `Trebejo.Proc`; si corre como root; el resultado de `--list-devices` por binario de engine y la coherencia de los dispositivos (§11.8); la conectividad y la identidad de cada nodo (§18); y el estado de verificación de cada modelo de decisión (§6.11).

### 4.13 El contrato de errores

Todos los errores son **valores**, no excepciones. El framework solo lanza si está roto (config inválida al arrancar). Un código que no esté aquí es `:internal_error` y hay que añadirlo.

| HTTP           | Códigos                                                                                                                                                                                                                                                                                                                            |
| -------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| 400            | `:invalid_request`, `:tool_not_found`, `:tool_invalid_arguments`                                                                                                                                                                                                                                                                   |
| 402            | `:budget_exceeded`, `:budget_exhausted`                                                                                                                                                                                                                                                                                            |
| 403            | `:tool_denied`, `:board_forbidden`                                                                                                                                                                                                                                                                                                 |
| 404            | `:session_not_found`, `:prompt_not_found`, `:eval_corpus_not_found`                                                                                                                                                                                                                                                                |
| 409            | `:tool_confirmation_required`, `:version_conflict`                                                                                                                                                                                                                                                                                 |
| 410            | `:session_closed`                                                                                                                                                                                                                                                                                                                  |
| 422            | `:invalid_structured_output`, `:guardrail_input_veto`, `:guardrail_output_veto`, `:context_overflow`, `:result_too_large`, `:board_full`, `:invalid_plan_fragment`                                                                                                                                                                 |
| 429            | `:rate_limited` (con `Retry-After`)                                                                                                                                                                                                                                                                                                |
| 499            | `:cancelled`                                                                                                                                                                                                                                                                                                                       |
| 500            | `:config_error` (antes de arrancar), `:tool_error`, `:store_error`, `:embedder_error`, `:chunker_error`, `:retriever_error`, `:reranker_error`, `:guardrail_error`, `:command_failed`, `:command_blocked`, `:internal_error`                                                                                                       |
| 502            | `:mcp_connection_failed`, `:mcp_protocol_error`, `:node_protocol_error`                                                                                                                                                                                                                                                            |
| 503            | `:no_candidates`, `:no_model_available`, `:overloaded`, `:refused_capacity`, `:refused_timeout`, `:provider_unavailable`, `:bulkhead_full`, `:too_many_sessions`, `:too_many_agents`, `:no_gpu`, `:memory_unknown`, `:gpu_layers_fixed`, `:no_room`, `:node_unreachable`, `:node_auth_failed`, `:device_unusable`, `:mailbox_full` |
| 504            | `:timeout`                                                                                                                                                                                                                                                                                                                         |
| el del backend | `:provider_error`                                                                                                                                                                                                                                                                                                                  |
| sin HTTP       | `:stream_interrupted`, `:classifier_error` (la capa se salta)                                                                                                                                                                                                                                                                      |

`retryable?` es `true` para: `:no_model_available`, `:overloaded`, `:provider_unavailable`, `:bulkhead_full`, `:refused_timeout`, `:rate_limited`, `:too_many_sessions`, `:too_many_agents`, `:mcp_connection_failed`, `:stream_interrupted`, `:timeout`, `:memory_unknown`, `:no_room`, `:node_unreachable`, `:device_unusable`; depende del backend en `:provider_error`, `:store_error`, `:embedder_error`, `:retriever_error`, `:tool_error` y `:command_failed`; es `false` en el resto, incluidos `:node_auth_failed` (no se resuelve reintentando) y `:tool_confirmation_required`.

**Avisos, no errores \[D-57\]**: `{:ok, %Response{warnings: [...]}}` con `:degraded`, `:failover`, `:llm_timeout`, `:classifier_error`, `:classifier_unverified`, `:embedding_unavailable`, `:structured_fallback`, `:context_compacted`, `:guardrail_modified`, `:empty_response`.

### 4.14 Versionado y compatibilidad

Público = §4 + §5 + los structs de §4.2. SemVer estricto; `1.0.0` es la primera versión pública. Un cambio de comportamiento observable exige versión mayor o `@deprecated` con una versión de margen, nombrando versión de sustitución y de eliminación. `mix.exs` publica este documento en `extras`.

### 4.15 Nodos y modelos de decisión

```elixir
Gunther.Nodes.list() :: [%{id: atom(), state: :connecting | :connected | :unreachable, devices: [...], engines: [...]}]
Gunther.Nodes.status(id) :: {:ok, map()} | {:error, Error.t()}
Gunther.DecisionModels.list() :: [%{id: atom(), kind: atom(), state: :unverified | :verified | :active | :failed, report_id: binary() | nil}]
Gunther.DecisionModels.status(id) :: {:ok, map()} | {:error, Error.t()}
```

---

## 5 · Los puntos de extensión

**Trece comportamientos registrables en v1**, más `Gunther.Agent`, que **es un behaviour (define callbacks) pero no se registra** en el registry: se pasa como `module:` en `%Gunther.Agent{}`. La coral añade cuatro más: `:coral_mode`, `:consensus`, `:step` y `:run_store` (§22.14, G9). Todos son **\[EXTENSIÓN\]**.

| `type`           | Behaviour                                | §    |
| ---------------- | ---------------------------------------- | ---- |
| `:provider`      | `Gunther.Provider`                       | 5.1  |
| `:embedder`      | `Gunther.Embedder`                       | 5.2  |
| `:chunker`       | `Gunther.Chunker`                        | 5.3  |
| `:retriever`     | `Gunther.Retriever`                      | 5.4  |
| `:reranker`      | `Gunther.Reranker`                       | 5.5  |
| `:rewriter`      | `Gunther.QueryRewriter`                  | 5.6  |
| `:classifier`    | `Gunther.Classifier` (ampliado por D-68) | 5.7  |
| `:selector`      | `Gunther.Selector`                       | 5.8  |
| `:store`         | `Gunther.Store`                          | 5.9  |
| `:guardrail`     | `Gunther.Guardrail`                      | 5.10 |
| `:tokenizer`     | `Gunther.Tokenizer`                      | 5.11 |
| `:detector`      | `Gunther.Detector` (ampliado por D-65)   | 5.12 |
| `:session_store` | `Gunther.SessionStore`                   | 5.13 |

### 5.1 `Gunther.Provider`

```elixir
@callback chat(messages, opts) :: {:ok, Result.t()} | {:error, term()}          # D-62
@callback stream(messages, opts, on_chunk) :: {:ok, Result.t()} | {:error, term()}
@callback embed(texts, opts) :: {:ok, [[float()]]} | {:error, term()}
@callback models() :: [atom()]
@callback capabilities(model) :: [atom()]
@callback modalities(model) :: [:text | :image | :audio | :video]
@callback supports?(:tools | :structured_output | :streaming | :prompt_cache | :logprobs, model) :: boolean()
@callback pricing(model) :: %{input_per_mtok_micros: n, output_per_mtok_micros: n} | nil
```

- `chat/2` y no `send/2`: definir `send/2` en un módulo obliga a `import Kernel, except: [send: 2]`.
- `opts` trae `:model_id`, `:tools`, `:tool_choice`, `:response_format`, `:temperature`, `:top_p`, `:max_tokens`, `:stop`, `:seed`, `:timeout`, `:cancelled?`. **`:messages` no se duplica** dentro de `opts`.
- `Result.t()`: `content`, `reasoning`, `tool_calls`, `finish_reason`, `usage`, `provider_request_id`, `cost`.
- **Precedencia**: lo declarado en `[[models]]` (skills, modalidades, precios) **gana** a lo que declare el provider.
- Un provider sin `stream/3` o `embed/2` devuelve `{:error, :not_supported}`; el motor ya lo filtró con `supports?/2`.
- **Referencia en v1**: `OpenAI`, `Anthropic`, `Ollama`, `LlamaCpp`, `Mock`. Antes de escribir cinco clientes HTTP con parsing SSE, F3 aplica una matriz de decisión (criterios: mantenimiento reciente, licencia, soporte de streaming SSE, cancelación, control de TLS, tamaño de dependencias) sobre los clientes Elixir candidatos (`req_llm`, `langchain` u otros que F3 encuentre); su existencia y capacidades se verifican en F3 (G-22). El contrato de Gunther sigue siendo propio.
- **`LlamaCpp`** tiene tres modos de destino: `managed_local` (Gunther lanza el engine), `managed_node` (un nodo lo gestiona, §18) y `external` (URL ya existente, sin gestión). Los dos primeros usan el mismo `Gunther.Engine.Backend` (§11.1, §18.6).

### 5.2 `Gunther.Embedder`

`embed(texts, opts)`, `dimensions/0`, `max_batch_size/0`, `model_id/0`. Gunther trocea en lotes y los paraleliza con `Task.async_stream`. `model_id/0` es contrato: al cambiarlo, los vectores viejos son inválidos y se reindexa (§8.5).

### 5.3 `Gunther.Chunker`

`max_chunk_bytes() :: pos_integer() | nil` es un callback **opcional**: si el chunker acota el tamaño de sus chunks, lo declara; lo usa `rag_query` para derivar el tope de `top_k` (§8.8).

`chunk(content, opts) :: {:ok, [%{content:, metadata:, parent_id:}]} | {:error, term()}`. Referencia: `Fixed`, `Recursive`, `Semantic`, `ParentDocument`.

### 5.4 `Gunther.Retriever`

`search(query, opts) :: {:ok, [Hit.t()]} | {:error, term()}`, con `opts` `:store`, `:embedder`, `:top_k`, `:filter`, `:min_score`. Referencia: `Vector`, `Lexical`, `Hybrid` (RRF), `MultiQuery`.

### 5.5 `Gunther.Reranker` y 5.6 `Gunther.QueryRewriter`

`rerank(query, hits, opts)` reordena; opcional. `rewrite(query, opts) :: {:ok, [binary()]}`.

### 5.7 `Gunther.Classifier` \[D-68\]

```elixir
@callback decision_spec() :: Gunther.DecisionSpec.t()
@callback rank(view :: DecisionView.t(), candidates, ctx) ::
            {:ok, %{ranking: [atom()], confidence: float() | nil}} | {:abstain, reason :: atom()} | {:error, term()}
```

`ctx` trae `:consumer`, `:timeout_ms` y `:cancelled?`. **No trae** `chat`, `Gunther.chat` ni acceso a la sesión completa (§6.12). `DecisionView` es el único insumo (§6.12). El clasificador **ordena, no juzga** (D-12, D-29): no puede añadir candidatos ni quitar los vetados. Si falla o expira, la capa se salta con warning `:llm_timeout` o `:classifier_error`. El `DecisionSpec` se define en §6.11.

### 5.8 `Gunther.Selector` \[D-53, CE-09\]

`next(candidates, state) :: {:ok, atom(), state}`. Reparto justo entre candidatos **ya elegibles**: round-robin por defecto (D-15), con la prioridad como peso. **El `state` es por consumer y por conjunto de candidatos**: la clave es `{consumer, sha256(candidatos ordenados)}`. Vive en `Selector.Server` (ETS con tope `selector.max_states` 10 000 y LRU de `Gunther.Cache`). Un consumer con mucho tráfico no desplaza el reparto de otro. **No decide colocación en GPU**: eso es el Placer (§11.4).

### 5.9 `Gunther.Store`

```elixir
@callback put(id, chunks, metadata) :: :ok | {:error, term()}
@callback fetch(id) :: {:ok, map()} | {:error, term()}
@callback search_by_vector(vector, opts) :: {:ok, [Hit.t()]} | {:error, term()}
@callback search_by_metadata(filter, opts) :: {:ok, [Hit.t()]} | {:error, term()}
@callback search_by_text(query, opts) :: {:ok, [Hit.t()]} | {:error, term()}
@callback content_hashes(doc_id) :: {:ok, %{chunk_id => hash}} | {:error, term()}
@callback stream(opts) :: Enumerable.t()
@callback delete(id) :: :ok | {:error, term()}
@optional_callbacks search_by_text: 2
```

Sin `search_by_text`, las estrategias `:lexical` e `:hybrid` (§8.2) no se pueden implementar. SQLite lo cubre con FTS5; Postgres con `tsvector`; `Memory` con un BM25 en proceso. Filtros: igualdad y rango obligatorios; el resto, opcional.

### 5.10 `Gunther.Guardrail`

`check(kind :: :input | :output, content, ctx) :: :ok | {:veto, reason} | {:modify, new_content}`. Semántica y límites en §16.

### 5.11 `Gunther.Tokenizer` \[D-58\]

`count(text_o_messages, model) :: {:ok, non_neg_integer()} | {:error, term()}` y `approximate?() :: boolean()`. Detalle en §7.6.

### 5.12 `Gunther.Detector` \[D-59, D-65, D-69\]

```elixir
@callback devices(opts) :: {:ok, [Device.t()]} | {:error, term()}
@callback measure(physical_id) :: {:ok, %{total_mib: n, free_mib: n, attribution: :per_process | :none, source: :engine | :system,
                                          processes: [%{pid: n, mib: n}] | nil}} | {:error, term()}

# Device.t():
%{physical_id: binary(), name: binary(), backend: :cuda | :vulkan | :rocm | :metal | :cpu,
  backend_name: binary(),        # p. ej. "CUDA0", "Vulkan0"
  kind: :discrete | :unified,    # unified exige límite explícito (§11.8)
  capacity_mib: n, free_mib: n | nil, usable: boolean(), reason: atom() | nil}
```

Referencias: `LlamaCpp` (por defecto; ejecuta `<binario> --list-devices`, §11.7), `Nvidia` (`nvidia-smi`), `Rocm` (`rocm-smi` o `amd-smi`), `Metal`, `Cpu` (`Trebejo.OS`). `Gunther.Platform` elige por defecto con `Apero.OS`.

### 5.13 `Gunther.SessionStore`

`load(name)`, `save(name, session)`, `delete(name)`, `list()`. Referencia: `Memory` (ETS, defecto) y `Disk` (`Apero.File`, escritura atómica). El mismo contrato sirve para el `AgentStore` de §10.1 con el snapshot opaco de CE-07.

### 5.14 El registro y el test de contrato

```elixir
Gunther.Registry.register(type, module, opts) / unregister(type, module) / list(type) / resolve(type, module)
```

**Desde el TOML**: `[embedders.local] module = MyApp.Embedder` registra el módulo sin recompilar (§14).

`use Gunther.ContractTest, behaviour: B` comprueba: (1) forma del retorno según el `@callback`; (2) robustez: entrada mala devuelve `{:error, _}`, no lanza; (3) determinismo donde aplique; (4) cancelación: un provider lento aborta al cancelar; (5) para `Classifier`: respeta `DecisionSpec` (salida dentro de las etiquetas, sin candidatos nuevos, sin acceso a `chat`). Es el entregable que hace verificable la palabra «extensible».

---

## 6 · El motor de decisiones

### 6.1 Las capas y su orden

| #   | Capa         | Coste                             | Qué hace                                                                                     |
| --- | ------------ | --------------------------------- | -------------------------------------------------------------------------------------------- |
| 1   | caché        | Una lectura de ETS                | Decisión repetida (§6.5)                                                                     |
| 2   | pin          | Ninguno                           | El consumer fijó un modelo                                                                   |
| 3   | `:rule`      | Evaluación de reglas              | Reglas de la config (§6.8)                                                                   |
| 4   | `:embedding` | Una llamada al embedder           | Similitud prompt ↔ skills. Sin embedder registrado, no existe. Sujeta a verificación (§6.11) |
| 5   | `:llm`       | Una llamada al modelo de decisión | Modelo de decisión especializado (D-68). Sin él, no existe                                   |
| 6   | fallback     | Ninguno                           | «El modelo normal», con `fallback_strategy`                                                  |

El **coste de las capas 4 y 5 no tiene cifra en este documento**: se mide en F4 con el corpus (§16.3) y queda en el informe de verificación (§6.11). Gana la primera capa que opina; las siguientes no se pagan.

### 6.2 Precedencia

**Eje A, resolución (de más fuerte a más débil)**: `veto` (seguridad, elimina candidatos) → `force` (operador, fija el destino y gana al pin) → `pin` o `model:` (petición explícita) → capas blandas `:rule`, `:embedding`, `:llm` → `fallback`.

**Eje B, ejecución**: las capas corren por coste y una que resuelve corta las siguientes. **Una decisión es una petición, no una capa**: si pasa por tres capas, cuenta una vez; la traza dice cuáles corrieron.

**Regla de autoridad (D-68)**: `veto` y `force` son **reglas deterministas** evaluadas **antes** de cualquier modelo. Un modelo de decisión opera solo sobre el conjunto que queda tras ellas y **no puede modificarlo** (§6.12).

### 6.3 Cuándo corre el modelo de decisión, y cuánto puede tardar

`router.llm`: `never` (la capa no existe), `fallback` (defecto: solo si las baratas no resolvieron), `always`.

- **`router.llm_timeout_ms`** (parámetro, defecto 1500). Al vencer, la capa se salta, la decisión sigue con el fallback y la respuesta lleva el warning `:llm_timeout`. **El valor no es una estimación de lo que tarda el modelo**: la verificación de §6.11 exige que `llm_timeout_ms` sea mayor o igual que el p99 medido; si no lo es, el modelo no se activa.
- **`resident = true`** en el modelo de decisión: se carga al arrancar y no se descarga por inactividad (§11.1). Si cada clasificación obligara a expulsar y recargar el modelo de respuesta, el sistema se pasaría el tiempo moviendo VRAM. El dispositivo del modelo de decisión (`device = :auto | :cpu | physical_id`) lo fija la configuración; **la elección entre CPU y GPU la decide la medición** del informe de §6.11, no una regla a priori.
- **`router.llm_warm_cache`** (defecto `false`): si es `true`, una clasificación que expira sigue en segundo plano y deja su resultado en la caché para peticiones parecidas.
- Un modelo de decisión se mide en F4. No se admite ninguna cifra de latencia de terceros como dato de diseño: la cifra publicada por Katanemo para Arch-Router (mediana y p99 en su hardware) es una afirmación de su autor sobre su entorno \[V\] y no sustituye a la medición propia.

### 6.4 La coral no es una fuente de decisión

La coral no produce una cuarta opinión en paralelo. Lo que sabe entra como **contexto** antes de decidir; su voto va **por la capa `:llm`**, con su coste y su traza (D-46), y por los **mismos modelos de decisión** (§6.11). En v1, varios `Classifier` registrados se combinan por agregación de rankings (Borda) en `router.classifiers`:

| Regla              | Definición                                                                                                                                        |
| ------------------ | ------------------------------------------------------------------------------------------------------------------------------------------------- |
| Entrada            | Los rankings de los clasificadores **activos** (§6.11) que no se abstienen, restringidos al conjunto elegible                                     |
| Puntos             | Un candidato en la posición `p` (1-based) de una lista de `n` recibe `n − p` puntos, multiplicados por el `weight` del clasificador (defecto 1.0) |
| Suma               | Se suman por candidato                                                                                                                            |
| Desempate          | (1) mayor suma de `weight` de reglas `prefer` que casan; (2) orden de `fallback_strategy`; (3) orden alfabético del alias. Determinista           |
| Todos se abstienen | Fallback                                                                                                                                          |

### 6.5 La caché de decisiones \[D-55\]

- **Clave**: `sha256` de la forma canónica de `{consumer, pin, force, firma de requisitos, hash del catálogo, último mensaje de usuario normalizado}`. La **firma de requisitos** incluye modalidades presentes, `tools`, `response_format`, skills pedidas y `rag`. El **hash del catálogo** cubre modelos, providers, nodos, **reglas (globales y de consumer)**, `DecisionSpec`s y su estado de verificación.
- **Qué se cachea**: solo el **ranking puro** (lo que producen `:rule`, `:embedding` y `:llm`). La **disponibilidad** (breaker, bulkhead, ledger, estado de nodo) se reevalúa siempre.
- **Invalidación**: `Catalog.reload/0` cambia el hash del catálogo y vacía la caché.
- TTL `router.cache.ttl_seconds` (300); `router.cache.max_entries` (10 000) con la expulsión LRU de `Gunther.Cache` (§3.3); local al nodo del controlador; se apaga con `router.cache.enabled = false`.
- `[:gunther, :router, :cache_hit | :cache_miss]` llevan el hash de clave, nunca el prompt.

### 6.6 La traza

Mapa con `layers_ran`, `candidates_per_layer`, `chosen`, `ranked`, `reason`, `duration_ms`, `degraded`, `filtered` (con motivo, por ejemplo `:no_vision` o `:consumer_veto`), `cost_estimate`, `decision_model` (id, tipo, `report_id`), `consumer_rules_applied`, `global_rules_applied` y `decision_input_sha256` (hash de lo que vio el modelo de decisión, §6.12). **Sin traza no hay enrutado.**

### 6.7 Ranking y failover \[D-52\]

`Decision.ranked` contiene **todos** los candidatos elegibles, ordenados: primero los que opinaron las capas, después el resto según `fallback_strategy` (`last`, `first`, `round_robin`, `least_used`). `chosen` es el primero servible. El failover de §2.5 consume esta lista.

Con `router.affinity = "prefer"` (§22.12), el ranking suma `router.affinity_weight` al modelo de la última llamada de la sesión si esa llamada reportó `cached_input > 0`; es una preferencia blanda entre candidatos elegibles que nunca sobrescribe veto, force ni pin. La traza lleva `Decision.affinity`.

### 6.8 Las reglas

Una regla tiene:

| Campo    | Tipo                                                             | Significado                                                                                                       |
| -------- | ---------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------- |
| `name`   | string, único en el espacio combinado con las reglas de consumer | Aparece en la traza                                                                                               |
| `when`   | mapa, opcional                                                   | Condición (abajo). Sin `when`, la regla aplica siempre                                                            |
| `action` | `force \| prefer \| veto`                                        | Sin sinónimos                                                                                                     |
| `target` | mapa, **obligatorio**                                            | A quién afecta: `models` (alias), `provider`, `node`, `capability`, `locality` (`local \| lan \| cloud`) o `tags` |
| `weight` | float                                                            | Solo con `prefer`                                                                                                 |

- **`veto`** elimina los candidatos que casan con `target`. Ejemplo: si el prompt contiene «privado», vetar `locality = cloud`. **Las restricciones de privacidad se expresan como reglas, nunca como criterio de un modelo de decisión** (§6.12).
- **`force`** restringe el conjunto a los que casan con `target`.
- **`prefer`** sube su puntuación en `weight`.
- Varias reglas: se aplican en orden; `veto` gana a `force` y a `prefer`; dos `force` en desacuerdo se intersecan; si queda vacío, `:no_candidates` con `details.filtered`.

**`when`**: `{any: [...]}`, `{all: [...]}`, `{contains: _}`, `{regex: _}`. El texto y los patrones se normalizan (minúsculas, sin diacríticos). Las regex se compilan al cargar y se ejecutan con `match_limit` (parámetro `router.regex_match_limit`) para acotar el backtracking. **`{lang: _}` sale de v1**: exige un detector de idioma que no existe como behaviour; pasa a v1.1.

Los modelos tienen dos atributos: `locality` (`local \| lan \| cloud`) y `tags`. **`lan`** es un destino en red privada gestionado por Gunther (nodo, §18) o declarado como externo privado.

#### 6.8.1 Reglas por consumer \[M-01, M-05, Q-15, CE-34\]

Cada consumer puede declarar sus propias reglas, con la **misma forma** que las globales:

```toml
[consumers.analista]
default_model = "qwen_27b"

[[consumers.analista.rules]]
name = "analista_sin_cloud"
action = "veto"
target = { locality = "cloud" }
```

Campos de cada regla de consumer: `name` (único en el espacio combinado con `[[rules]]`), `when` (opcional; sin `when`, la regla aplica siempre), `action` (`veto`, `force` o `prefer`), `target` y `weight` (solo con `prefer`).

- **Alcance.** Una regla de consumer se evalúa **solo** para las peticiones de ese consumer.
- **Precedencia completa.** Los vetos **se acumulan**: el de consumer y el global eliminan candidatos y no entran en conflicto entre sí; ambos prevalecen sobre cualquier `force`. La precedencia decide los conflictos entre el resto: `force` de consumer > `force` global > `prefer` de consumer > `prefer` global > `default_model` del consumer (orden de CIERRE-DP0 Q-15: veto de consumer > veto global > force de consumer > force global > prefer de consumer > prefer global > default_model). Dos `force` en el mismo nivel en desacuerdo se intersecan; si el resultado es vacío, `:no_candidates` con `details.filtered`. **Una restricción de privacidad debe expresarse como `veto` (§6.12 M3), no como `force`**, porque un `force` de consumer prevalece sobre uno global.
- **Interacción con el pin.** Un `model:` en la petición (pin) sigue cediendo a `veto` y `force`, tanto del consumer como globales (regla de §6.2).
- **Interacción con el refusal.** Un consumer cuyo `default_model` es vetado por sus propias reglas y sin otro candidato produce `:no_candidates` en lugar de `:refused_capacity`. Son casos distintos: `:refused_capacity` es «hay un modelo pero no cabe»; `:no_candidates` es «no hay un modelo elegible».
- **Traza.** `Decision` añade `consumer_rules_applied: [name]` y `global_rules_applied: [name]`. El `name` es el del campo `name` de cada regla.
- **Caché.** La clave de §6.5 incluye el hash de `[[consumers.*.rules]]` a través del «hash del catálogo», que se extiende a las reglas de consumer.

**Estado de `when` en una regla de consumer.** `when` es **opcional**; sin `when`, la regla aplica siempre. Esto permite declarar un `veto` incondicional para un consumer (por ejemplo, «este consumer nunca usa cloud»), que es la forma más común de privacidad por consumer.

**Validación en carga (§14.2).** Una regla de consumer con `action = "veto"` sin `when` cuyo `target` casa con el `default_model` del mismo consumer es `config_error`: el consumer no puede arrancar porque su propio `default_model` es inelegible.

### 6.9 Refusal

| Política  | Qué hace                                                                                                                                                                                                                            |
| --------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `fail`    | `{:error, :refused_capacity}`                                                                                                                                                                                                       |
| `wait`    | Espera a que el ledger libere recursos, **por suscripción, no por sondeo** (`Ledger.subscribe/1`, que incluye los devices de nodos vía el espejo de §18.5), hasta `refusal.wait_ms`; si vence, `:refused_timeout` con `Retry-After` |
| `degrade` | **Es una acción**: pasa al siguiente servible de `decision.ranked` aunque tenga menos skills, anota `Decision.degraded` y el warning `:degraded`. Si no queda ninguno, `:refused_capacity` (D-21)                                   |

**Defecto (D-88)**: `[refusal] policy = "wait"` con `wait_ms` 10 000.

**Dos reglas que ningún valor puede cambiar (D-09)**: (1) ninguna política devuelve un modelo vetado: es seguridad, no política; (2) `:refused_capacity` y `:refused_timeout` llevan `details: %{requested_mib: n, available_mib: n | :unknown, capacity_mib: n | :unknown}`: nunca un número que signifique «no se sabe» (D-04).

### 6.10 Casos borde

| Caso                                                                                          | Comportamiento                                                                                                |
| --------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------- |
| `messages` vacío o `role` desconocido                                                         | `:invalid_request`                                                                                            |
| `model:` apunta a un alias inexistente                                                        | `:invalid_request` con `details.alias`                                                                        |
| `veto` deja 0 candidatos                                                                      | `:no_candidates` con `details.filtered`                                                                       |
| `force` apunta a un alias vetado                                                              | `:no_candidates` con `details.filtered`                                                                       |
| `:rule` resuelve a 1 candidato                                                                | Corta; no corren `:embedding` ni `:llm`                                                                       |
| `:rule` resuelve a varios                                                                     | Orden por puntuación agregada                                                                                 |
| Capa `:embedding` o `:llm` sin implementación registrada                                      | La capa no existe; se salta                                                                                   |
| Modelo de decisión en estado distinto de `:active`                                            | La capa se salta con warning `:classifier_unverified`                                                         |
| El modelo de decisión devuelve una etiqueta fuera de `routes`                                 | Se trata como abstención; contador `[:gunther, :classifier, :invalid_label]`                                  |
| El modelo de decisión devuelve una ruta cuyos modelos están todos fuera del conjunto elegible | Abstención                                                                                                    |
| Petición con imagen y ningún candidato con modalidad `:image`                                 | `:no_candidates`, `filtered` con `:no_vision`                                                                 |
| Nodo `:unreachable`                                                                           | Sus modelos salen del conjunto elegible con motivo `:node_unreachable`; la caché de decisiones no se invalida |
| Catálogo recargado a mitad de petición                                                        | La petición termina con el snapshot con que empezó                                                            |
| **Consumer con `default_model` vetado por sus propias reglas y sin otro candidato** (M-01)    | `:no_candidates`, `filtered` con `:consumer_veto`                                                             |
| **`consumer` en la petición que no está declarado en `[consumers.*]`** (M-01)                 | `:invalid_request` con `details.consumer`                                                                     |
| **Regla de consumer y regla global con el mismo `name`** (M-01)                               | `config_error` al cargar (nombres de regla únicos en el espacio combinado)                                    |

### 6.11 Modelos de decisión especializados \[D-68\]

**Requisito del dueño**: el motor de decisiones del router, y la coral que lo usa, se apoyan en modelos **especializados en decisiones**, no en un LLM de propósito general. **Requisito adicional (D-71)**: el decisor debe funcionar en **muchos idiomas** y para **varios tipos de decisión** (ruta por dominio o acción, complejidad fuerte/débil, intención, elegibilidad por capacidad).

**Agnosticismo y personalización (D-72).** El código de Gunther **no contiene nombres de modelos**. Todo lo que depende de un modelo concreto es configuración del operador: el alias del modelo, la plantilla de decisión (`prompt`: una plantilla incorporada por tipo o un módulo propio que implementa `render/2`), el intérprete de la salida (`parse`: uno incorporado o un módulo propio que implementa `parse/2`), la forma de salida (`output`) y los idiomas. Un decisor completamente propio se implementa como `Gunther.Classifier` (§5.7). **Las recomendaciones de modelos viven en la documentación (`docs/10-recomendaciones.md`), no en el código ni en los defectos de la config**, y son no vinculantes. El modelo que use el autor para desarrollo y uso personal es configuración suya y no forma parte del paquete.

**Ningún modelo único está fijado por este documento.** Los hechos de abajo muestran que cada familia cubre un tipo de decisión distinto y que ninguna tiene verificada la calidad multilingüe que se exige. El modelo ganador lo decide **la evaluación con el corpus multilingüe del operador** (más abajo), no una elección a priori. Candidatos a evaluar en F4: un modelo estilo Arch-Router (sujeto a licencia), un LLM pequeño con salida restringida como el que usa el enrutador de NVIDIA, y un clasificador de terceros vía `Classifier`. Un modelo candidato debe declarar y pasar los idiomas que el operador necesita.

**Qué hechos verificados sostienen el diseño** \[V\] (fuentes en el Anexo C):

| Hecho                                                                                                                                                                                                                                                                       | Consecuencia de diseño                                                                                                                                                                                                                                                                                                                                                                                                                                                                                |
| --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Arch-Router-1.5B es un modelo de 1,5 B parámetros que mapea consultas a **políticas definidas por el usuario** (dominio o acción) y responde con `{"route": "<nombre>"}`; admite la ruta `other`; existe en GGUF; su licencia es la de Katanemo                             | `kind: :preference_router`; la salida se restringe a una forma fija. **Licencia**: el texto de la licencia de Katanemo consultado (en el repositorio de otro modelo de la misma empresa, Arch-Function-3B; el de Arch-Router no se ha leído) permite uso comercial salvo que el modelo se empaquete y entregue como parte de un framework, proxy, middleware o producto de gateway, que exige licencia aparte. Gunther es un framework: por eso **no incluye ni distribuye modelos decisores** (D-71) |
| NVIDIA publica bajo Apache 2.0 un enrutador de código abierto con dos estrategias: clasificación de intención con un LLM Qwen de 1,7 B y una red neuronal sobre embeddings CLIP                                                                                             | Confirma que la clasificación de intención por un LLM pequeño es una estrategia en uso; se evalúa como candidato (abajo)                                                                                                                                                                                                                                                                                                                                                                              |
| Existe un clasificador de intención multilingüe de licencia Apache 2.0 basado en mmBERT (declara más de 1800 idiomas por transferencia entre idiomas), con 14 categorías académicas fijas y 77,9 % de exactitud declarada por su autor                                      | Es un clasificador de **categorías fijas**, no de rutas definidas por el operador, y es un codificador (no un GGUF): sirve como candidato para `:embedding` o `Classifier` de terceros, no como decisor general                                                                                                                                                                                                                                                                                       |
| RouteLLM trata el enrutado como **predicción de la probabilidad de que el modelo fuerte supere al débil** y decide con un **umbral** calibrable sobre una muestra de consultas; sus routers publicados son de matriz de factorización, BERT, LLM causal y ranking ponderado | `kind: :win_rate_binary`; el umbral se **calibra con corpus**, no se fija a priori                                                                                                                                                                                                                                                                                                                                                                                                                    |
| Existen ataques publicados que **redirigen** a los routers (inyección de secuencias que fuerzan la elección del modelo fuerte) y defensas específicas                                                                                                                       | Autoridad acotada y entrada restringida (§6.12); corpus adversario obligatorio                                                                                                                                                                                                                                                                                                                                                                                                                        |

**`Gunther.DecisionSpec`** (definición completa de un modelo de decisión; se declara en `[[decision_models]]`, §14):

```elixir
%Gunther.DecisionSpec{
  id: atom(),
  kind: :preference_router | :win_rate_binary | :general_llm,
  model: atom(),                         # alias del catálogo (local, nodo o externo)
  routes: %{route_name => %{description: binary(), models: [atom()]}},   # preference_router
  other: :abstain | route_name,          # qué hacer con la ruta "other"
  win_rate: %{strong: atom(), weak: atom(), threshold: float()},         # win_rate_binary
  output: {:json_schema, map()} | {:grammar, binary()},                  # forma fija de la salida
  max_input_tokens: pos_integer(),
  max_output_tokens: pos_integer(),      # defecto 32
  temperature: 0.0, seed: integer(),     # decisión determinista
  confidence: :logprobs | :none, min_confidence: float() | nil,
  resident: boolean(), device: :auto | :cpu | binary(),
  context_roles: [:user | :system],      # defecto [:user]; nunca :tool ni :assistant por defecto
  context_turns: pos_integer(),          # defecto 1
  prompt: {:builtin, atom()} | {:module, module()},   # plantilla de decisión; personalizable (D-72)
  parse: {:builtin, atom()} | {:module, module()},    # intérprete de la salida; personalizable (D-72)
  require_eval: boolean(),               # defecto true
  eval: %{corpus: path, adversarial_corpus: path,
          required_languages: [binary()],  # OBLIGATORIO si require_eval: idiomas que el operador necesita
          confidence: float(),             # defecto 0.95 (§6.11, intervalo de Wilson)
          min_top1_accuracy: float() | nil,# suelo absoluto OPCIONAL, además del criterio relativo
          max_p99_ms: pos_integer()}       # defecto router.llm_timeout_ms; no puede superarlo
}
```

**Tipos admitidos**:

| `kind`               | Qué es                                                                                                                                    | v1                                                                                                                                                                      |
| -------------------- | ----------------------------------------------------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `:preference_router` | Modelo que elige una **ruta** entre políticas descritas en lenguaje natural (estilo Arch-Router). `routes` mapea ruta → modelos ordenados | **Implementación de referencia, agnóstica del modelo**: cualquier modelo, de cualquier provider (local, de nodo o externo), con plantilla y parser configurables (D-72) |
| `:win_rate_binary`   | Modelo que devuelve `P(strong gana)`; `threshold ∈ [0, 1]`; estilo RouteLLM, entre dos modelos                                            | Solo contrato; implementación por terceros vía `Classifier`                                                                                                             |
| `:general_llm`       | Un LLM de propósito general usado como decisor                                                                                            | **Solo con `router.allow_general = true`** (defecto `false`); `Doctor` emite `:warn`; sujeto a la misma verificación                                                    |

**Prompt de decisión**: plantilla fija por `kind`, con el **prefijo estático primero** (descripción de las rutas) y el texto del usuario al final, para que el servidor reutilice la caché de prompt (`--cache-prompt` existe en `llama-server` \[V\]). Que la reutilización ocurre realmente se comprueba en G-12. La plantilla exacta de Arch-Router es la de su ficha de modelo; el test de conformidad de G-18 la valida con los ejemplos de esa ficha.

**Forma fija de la salida**: `llama-server` admite gramáticas GBNF (`--grammar-file`) \[V\]; que la petición acepte además un esquema JSON o una gramática por llamada, y bajo qué nombre de campo, es G-12. Rama A: restricción nativa. Rama B: se pide la forma en el prompt, se valida contra `output` y una salida inválida es **abstención**, nunca una conjetura.

**Confianza**: con `confidence: :logprobs`, la probabilidad del token de ruta se obtiene de las `logprobs` si el provider las ofrece (`supports?(:logprobs, model)`, G-12). Si `min_confidence` no es `nil` y la confianza es menor o no está disponible, el resultado es **abstención**.

**Ciclo de vida y activación (la evaluación manda)**:

| Estado        | Significado                                                                                                              | Capa `:llm`                                  |
| ------------- | ------------------------------------------------------------------------------------------------------------------------ | -------------------------------------------- |
| `:unverified` | Sin informe de evaluación válido                                                                                         | Saltada, warning `:classifier_unverified`    |
| `:verified`   | Hay un informe que cumple los umbrales de `eval` y está ligado al hash de {fichero del modelo, `DecisionSpec`, `routes`} | Se activa en el siguiente `Catalog.reload/0` |
| `:active`     | Verificado y cargado                                                                                                     | Corre                                        |
| `:failed`     | El informe no cumple umbrales o el modelo no arrancó                                                                     | Saltada, warning `:classifier_error`         |

`Doctor.calibrate_router(corpus)` ejecuta el corpus etiquetado y el adversario contra el modelo de decisión y escribe un informe `<state_dir>/eval/<report_id>.json` con: `top1_accuracy`, `top3_accuracy`, `abstain_rate`, `adversarial_drop` (diferencia de exactitud entre el corpus limpio y el adversario), latencia p50/p95/p99 de la clasificación de extremo a extremo, dispositivo usado y hash de ligadura. **Criterio de verificación relativo a una línea base (D-72)**, sin umbrales arbitrarios del dueño. Se calcula para **cada idioma de `eval.required_languages`** (campo `lang`, §16.3) sobre los casos `real` etiquetados por una persona (§16.4):

1.  **Línea base**: la mayor exactitud top-1 entre (a) solo `fallback` y (b) solo reglas más `fallback`, medidas sobre **los mismos casos**.
2.  **Exactitud del decisor con confianza**: límite inferior del **intervalo de Wilson** de su exactitud top-1 al nivel `eval.confidence` (0,95).
3.  **Verificado** exige: límite inferior del decisor **mayor** que la línea base, en **todos** los idiomas requeridos; lo mismo sobre el corpus adversario (límite inferior en casos adversarios mayor que la línea base en esos casos); `p99 ≤ max_p99_ms ≤ router.llm_timeout_ms`; y, si se fijó, `top1_accuracy ≥ min_top1_accuracy`. Un idioma con pocos casos produce un límite inferior bajo y **no se verifica**: no hace falta fijar un mínimo de casos, lo impone la estadística. **Cualquier cambio** en el fichero del modelo, el `DecisionSpec` o las rutas invalida el informe y devuelve el estado a `:unverified`. `require_eval = false` solo se admite con `router.allow_unverified = true` (defecto `false`; pensado para desarrollo; `Doctor` emite `:warn`).

**La capa `:embedding`** sigue el mismo ciclo. `router.embedding.min_similarity` tiene defecto `0.0` (D-92) y la capa **no actúa mientras esté `:unverified`**; `Doctor.calibrate_router/2` elige el valor de `min_similarity` que maximiza la exactitud top-1 de la capa sobre el corpus y después la verifica con el mismo criterio que a un decisor.

**Modelo residente**: los `DecisionSpec` con `resident = true` se cargan al arrancar por orden de `resident_priority` y se registran en el ledger como holders permanentes. Si no caben, el arranque continúa con esa capa deshabilitada y `Doctor` emite `:fail`.

**Coral (v1.1)**: un miembro con `maybe_rank/3` **no recibe** `Gunther.chat`. Recibe `ctx.decide(spec_id, view)`, que ejecuta un `DecisionSpec` verificado y devuelve un ranking. Un miembro no puede invocar un LLM libre para decidir. El `ContractTest` del miembro lo comprueba (§5.14). El criterio de promoción de D-56 se mide con este mismo corpus.

### 6.12 Seguridad del router \[D-68\]

Los routers son un objetivo de ataque: hay trabajos publicados que demuestran la redirección de un router hacia el modelo caro mediante secuencias añadidas al prompt, y otros que proponen defensas \[V\]. Controles, todos con test:

| #   | Control                                  | Cómo                                                                                                                                                                                                                                                             |
| --- | ---------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| M1  | **Autoridad acotada**                    | La salida del modelo de decisión se intersecta con el conjunto elegible de §6.2. Etiquetas desconocidas se ignoran. No puede añadir candidatos ni levantar vetos                                                                                                 |
| M2  | **Entrada restringida (`DecisionView`)** | Solo texto de autoría del caller con los roles de `context_roles`, truncado a `max_input_tokens`. **Excluye** resultados de tools, contenido de RAG, memoria KV, mensajes `assistant` y contenido MCP. Esto evita que un documento recuperado dirija la decisión |
| M3  | **Seguridad por reglas**                 | Privacidad, locality y coste máximo son `veto`/`force` deterministas, no criterios del modelo                                                                                                                                                                    |
| M4  | **Abstención**                           | Salida inválida, confianza baja o ruta `other` → fallback. Nunca se adivina                                                                                                                                                                                      |
| M5  | **Corpus adversario**                    | Parte de la verificación (§6.11): incluye secuencias de redirección; el decisor debe seguir superando la línea base, con el límite inferior del intervalo de confianza, sobre esos casos                                                                         |
| M6  | **Trazabilidad**                         | `decision_input_sha256` y `decision_model.report_id` en cada traza                                                                                                                                                                                               |
| M7  | **Coste acotado**                        | `max_output_tokens`, timeout y un bulkhead propio del modelo de decisión (`max_concurrency`) para que un flujo de peticiones no sature el decisor                                                                                                                |

---

## 7 · Sesiones, memoria y contexto

### 7.1 Sesiones (D-37)

Espacio de nombres por consumer (CE-30). Estado `:open → :compacting → :open`, o `:closed` (tras lo cual `append/3` devuelve `{:error, :session_closed}`). Almacenamiento **local al nodo del controlador** (ETS) detrás de `Gunther.SessionStore` (§5.13). Límites: `sessions.max_sessions` (1024), `sessions.idle_ttl_seconds` (3600), `sessions.max_turns_in_memory` (200). El comportamiento de `open/2` al reabrir está en §4.6 (CE-08). Una sesión persistida en disco puede cifrarse y firmarse (§15).

### 7.2 Memoria KV (D-22)

Mapa clave→valor con namespace por consumer (`mem:<consumer>:<key>`); `consumer: :global` es el ámbito compartido. Se sobrescribe o borra; caducidad opcional (`expires_at`); local al nodo; acotada por `memory.max_entries`. `put_new/3` usa `:ets.insert_new/2`, atómico. **La memoria no se escribe desde la salida del modelo sin pasar por una tool con permiso** (§9.3): un modelo no puede envenenar la memoria compartida por su cuenta.

**Campos por entrada (D-22, D-90)**: `value`, `expires_at`, `meta: %{author, version, superseded_by}`. `author` y `version` son opcionales y los rellena la coral (§22.6); `put/3` con `if_version:` falla con `{:error, :version_conflict}` si la versión no coincide.

### 7.3 Qué entra al prompt y en qué orden

`system` → plantilla versionada (`prompt:`) → memoria (hechos) → RAG (con citas) → historial de sesión → mensaje actual. Lo que viene de RAG, de resultados de tools y de MCP se delimita y se marca como **no confiable** (§15). Los guardrails de input se aplican **antes** de añadir contexto; `guardrails.pre_send = true` vigila también el prompt ensamblado.

### 7.4 Sesión, memoria y RAG: tres cosas distintas

|                       | Sesión            | Memoria KV         | RAG                         |
| --------------------- | ----------------- | ------------------ | --------------------------- |
| Qué guarda            | Turnos            | Hechos clave→valor | Chunks con vectores y citas |
| Pregunta que responde | ¿Qué hemos dicho? | ¿Qué sabemos?      | ¿Qué dicen los documentos?  |
| Compactable           | Sí                | No (se poda)       | No (se reindexa)            |
| Entra en el prompt    | Sí                | Sí                 | Sí, con cita                |
| Es fuente de decisión | No                | No                 | No                          |

La memoria común entre consumers es `Memory` con `consumer: :global`; la memoria común de una ejecución de la coral es su pizarra (§22.6). El RAG tiene su propio store (`[rag] store_backend = "separate"` en v1; `shared` produce `config_error` hasta v1.1, D-36) y se consulta como **tool** (`rag_query`, §8.8), además de por API y por `opts.rag`.

### 7.5 Compactación (D-43)

| Estrategia       | Qué hace                                 |
| ---------------- | ---------------------------------------- |
| `:none`          | Si no cabe, `:context_overflow`          |
| `:truncate`      | Descarta turnos antiguos hasta que quepa |
| `:summary`       | Resume los turnos antiguos               |
| `{:custom, mod}` | `mod.compact(history, max_tokens)`       |

Reglas: nunca se parte un par `tool_call` + `tool_result`; se conservan los mensajes `system` y los fijados; `:summary` se ejecuta **tras responder** (estado `:compacting`), salvo que no quepa, caso en que se usa `:truncate` como salvavidas síncrono. El modelo del resumen es `context.summary_model` (el más barato con skill suficiente). `opts.compaction` sobrescribe el defecto de config.

### 7.6 Contar tokens \[D-58, CE-21\]

Orden de preferencia:

1.  **Contador exacto del provider** (por ejemplo el endpoint de tokenización de `llama-server`, G-12).
2.  **`Gunther.Tokenizer`** registrado para ese modelo.
3.  **Modo `approximate`**: `tokens = ceil(caracteres / chars_per_token) × (1 + margin)`, con `chars_per_token` y `margin` **calibrados por modelo** con `Gunther.Doctor.calibrate_tokenizer(model, corpus)` contra el contador exacto: `chars_per_token` es el mínimo observado de caracteres por token y `margin` el máximo observado de `exacto / aproximado − 1`, acotado inferiormente a 0. Sin calibración guardada, **el modo `approximate` no está disponible para ese modelo**: si la compactación o `max_prompt_tokens` necesitan contar, el modelo sale del conjunto con `filtered: :no_token_counter`. La traza marca `approximate: true`.

Cada modelo declara `context_window`; `context.max_prompt_tokens` es el techo global.

---

## 8 · El RAG

Siete piezas, cada una detrás de un behaviour de §5: store, chunker, embedder, retriever, reranker, rewriter y evaluación (§16.3). D-36 existe y está aceptada en DP0.

### 8.1 El flujo canónico

```
documento → chunker → chunks → store (id estable + content_hash) + embedder → vectores
consulta  → rewriter (opcional) → [consultas]
          → retriever (vector | lexical | hybrid | multi_query)
          → min_score por retriever → fusión RRF si hay varias listas
          → reranker (opcional)
          → [Hit]
```

### 8.2 Estrategias

| Estrategia          | Qué hace                                                    | Cuándo                       |
| ------------------- | ----------------------------------------------------------- | ---------------------------- |
| `:vector`           | Similitud coseno                                            | Semántica                    |
| `:lexical`          | BM25 o equivalente (`Store.search_by_text/2`)               | Nombres propios, código, IDs |
| `:hybrid` (defecto) | RRF de vector + lexical                                     | Caso general                 |
| `:multi_query`      | El rewriter genera N consultas, cada una busca, se fusionan | Consultas ambiguas           |

### 8.3 Fusión y umbrales

- **`:hybrid` es RRF** sobre **posiciones**: `1 / (k + rango)` sumado por lista, con `k = rag.rrf_k` (parámetro, defecto 60) y **`rango` 1-based** (el primer resultado de cada lista tiene `rango = 1`) \[CE-29\]. `Hit.score` es el valor RRF; `Hit.vector` y `Hit.lexical` conservan los valores crudos.
- **`min_score` se aplica antes de la fusión**, por retriever: coseno para vector, BM25 dividido por el máximo de la consulta para lexical.
- **Un coseno exactamente `0.0` no entra**: condición `score != nil and score >= min_score and score != 0.0`.
- **Un vector de norma cero** es un error del embedder (`:embedder_error`), no un coseno `0.0` (C-12).
- **`min_score` tiene defecto `0.0`** (sin umbral; D-36): acepta todo lo no ortogonal. Se recomienda calibrarlo con `Gunther.Doctor.calibrate_rag/2`, que para cada valor candidato ejecuta las consultas del corpus de recuperación (`relevant_ids`, §16.3), calcula **F1@5** y elige el de F1@5 máxima (si todas son 0, `0.0`). Por consulta: `recall@5 = |relevantes ∩ top5| / |relevantes|`; `precision@5 = |relevantes ∩ top5| / |resultados devueltos|` (los que superan `min_score`, como máximo 5; sin resultados, 0); `F1@5 = 2·P·R / (P + R)` (0 si `P + R = 0`); se promedia sobre las consultas. **La precisión se divide por los devueltos y no por 5**: con denominador fijo, subir el umbral nunca la mejoraría y el máximo sería siempre `0.0`. Valores candidatos: los distintos de puntuación observados en el corpus más `0.0`; ante empate, el menor. `Doctor` emite `:warn` si no se ha calibrado el embedder configurado, y **no bloquea el arranque**.

### 8.4 Metadatos y filtros

Cada chunk lleva `metadata` (mapa libre). Operadores: igualdad `%{source: _}` y rango `%{date: {:>=, _}}` **obligatorios** en todo store; `{:in, [...]}` y `{:contains, _}` opcionales. Un store que no soporte un operador pedido devuelve `{:error, :unsupported_filter}`, no ignora el filtro.

### 8.5 IDs estables y reindexado incremental

- `doc_id = Apero.Crypto.sha256(source)` (si `source` es `inline`, el hash del documento).
- `chunk_id = doc_id <> «#» <> índice`. El `Hit.id` es este.
- `content_hash = Apero.Crypto.sha256(contenido del chunk)`, guardado junto al chunk.
- Al reindexar se compara `content_hash`: solo se re-embeben los chunks que cambiaron.
- Cada índice guarda `embedder.model_id/0` y un hash de la config del chunker. Si cualquiera cambia, el índice se invalida entero y `Gunther.Rag.reindex/1` lo reconstruye.

### 8.5b La cita

Cada resultado trae su cita y es contrato: `id`, `chunk`, `score`, `source`, `metadata`, más `lexical`, `vector` y `rerank` cuando existan.

### 8.6 Referencia en v1

| Pieza     | Implementaciones                                                                                                                                                                                             |
| --------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| Store     | `Memory` (defecto para pruebas), `SQLite` (`sqlite-vec` + FTS5; **defecto para uso real**, G-24, G-26), `Postgres` (`pgvector` + `tsvector`; producción y multinodo, G-25). `ETS` **no** es un store del RAG |
| Chunker   | `Fixed`, `Recursive`, `Semantic`, `ParentDocument`                                                                                                                                                           |
| Retriever | `Vector`, `Lexical`, `Hybrid`, `MultiQuery`                                                                                                                                                                  |
| Reranker  | `CrossEncoder` (requiere modelo local o servicio; opcional)                                                                                                                                                  |
| Rewriter  | `HyDE`, `Expand` (necesitan un clasificador o un modelo registrado)                                                                                                                                          |

### 8.7 Ingesta y seguridad

Límites: `rag.max_document_bytes` (10 MiB), `rag.max_chunks_per_document` (5000); la indexación `:async` tiene su propio bulkhead. **Los documentos son entrada no confiable**: pueden contener instrucciones dirigidas al modelo. Se delimitan y marcan al entrar al prompt (§7.3, §15); **el delimitado reduce el riesgo y no es una frontera de seguridad** (§15). El RAG no concede permisos a nada que contenga.

### 8.8 El RAG como tool: una API, cuatro puertas \[D-36\]

| Puerta                    | Cómo se invoca                                                                                                                     | Quién decide consultar |
| ------------------------- | ---------------------------------------------------------------------------------------------------------------------------------- | ---------------------- |
| 1. API directa            | `Gunther.Rag.query/2`                                                                                                              | El código del usuario  |
| 2. Tool `rag_query`       | Se registra al arrancar en `Gunther.Tools` con `source: :local` y `permission: :auto`; `[rag] tool_enabled = true` (defecto)       | El modelo              |
| 3. `opts.rag` en `chat/2` | Inyecta el contexto en el paso 2 del flujo (§2.4), **antes de decidir**                                                            | El llamador            |
| 4. Agentes, MCP y gateway | Por el registro de tools; el gateway ejecuta en el servidor las tools del registro y devuelve al cliente las que él definió (§9.4) | Según la vía           |

- **Condiciones de registro**: `Gunther.Rag` cargado (es opcional, §0.4) y un store configurado.
- **Esquema de `rag_query`**: `query` (obligatorio), `top_k` y `filter`. **No expone** `store`, `retriever`, `reranker` ni `rewriter`. `top_k` tiene un tope derivado de `tools.max_result_bytes`: `floor(tools.max_result_bytes / bytes máximos de un resultado)`, con `max_chunk_bytes/0` del chunker (§5.3) más la sobrecarga de la cita; si el chunker no lo declara, actúa solo el truncado de §9.1.
- **Permisos**: `:auto` por defecto; el operador puede cambiarlo con `tools.permissions`. `Doctor` emite `:warn` si hay más de un consumer en `[consumers]` y `rag_query` es `:auto`. **El índice es común a todos los consumers.**
- No es un paso fijo del pipeline. El resultado pasa por el truncado de §9.1 y se marca `untrusted` al entrar al prompt (§7.3).
- **Estrategia**: `opts.strategy` o `[rag] strategy = "hybrid"` (defecto). El classifier de consulta se aplaza a v1.1 (D-36).

### 8.9 `store_backend` \[D-36\]

`[rag] store_backend = "separate"` (único valor en v1): el RAG y la memoria KV tienen cada uno su store. `"shared"` produce `config_error` con el mensaje «shared requiere MemoryStore persistente, que llega en v1.1».

---

## 9 · MCP y tools

### 9.1 El registro único

Una sola tabla (`Gunther.Tools`) para tools locales y MCP (D-35).

- El `schema` es **JSON Schema** normalizado a claves string al registrar; los argumentos del modelo se validan contra él con el validador de §0.3. Límite: `tools.max_schema_bytes` (16 384).
- `side_effects: :none | :idempotent | :unsafe` (defecto `:unsafe`, gancho G7): lo usa la reanudación de la coral (§22.11).
- `handler` recibe `(args, ctx)` con `ctx` = `:consumer`, `:trace`, `:memory`, `:session`, `:cancelled?`. Devuelve `{:ok, term}` o `{:error, reason}`; el error se pasa al modelo como `{error: reason}` (D-32).
- **Tamaño de resultado y truncado \[CE-11\]**. El límite es `tools.max_result_bytes` (65 536) sobre el JSON serializado. El truncado se hace **sobre el término, antes de serializar**, de modo que el JSON resultante es siempre válido:

| Forma del resultado       | Algoritmo                                                                                                                                                                                          |
| ------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Cabe en el límite         | Pasa sin cambios                                                                                                                                                                                   |
| `binary()`                | Si es UTF-8 válido, se corta en el mayor límite de carácter que quepa; si no, en el byte. Se devuelve `%{"truncated" => true, "original_bytes" => n, "content" => corte}`                          |
| Lista                     | Se eliminan elementos del final hasta que `%{"truncated" => true, "omitted" => k, "items" => resto}` quepa                                                                                         |
| Mapa                      | Se acorta, a la mitad de su longitud y respetando UTF-8, el valor `binary()` más largo; se repite hasta `tools.truncate_passes` (32) veces; se devuelve `%{"truncated" => true, "result" => mapa}` |
| No cabe tras el algoritmo | `{:error, :result_too_large}`; al modelo le llega `{error: "result_too_large", original_bytes: n}`                                                                                                 |

- El ejemplo de r4 devolvía una tupla dentro del resultado. Forma correcta:

```elixir
Gunther.Tools.register("buscar_documentos",
  description: "Busca en los documentos indexados",
  schema: %{"type" => "object", "properties" => %{"query" => %{"type" => "string"}}, "required" => ["query"]},
  handler: fn %{"query" => q}, _ctx ->
    with {:ok, hits} <- Gunther.Rag.query(q, top_k: 5) do
      {:ok, %{hits: Enum.map(hits, &Map.from_struct/1)}}
    end
  end)
```

### 9.2 Servidor MCP: revisión 2026-07-28 \[D-54\]

El changelog oficial de la revisión **2026-07-28** \[V\] establece, entre otros cambios:

| Cambio verificado \[V\]                                                                                                                                      | Efecto en Gunther                                                                                                                                                                          |
| ------------------------------------------------------------------------------------------------------------------------------------------------------------ | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| Se eliminan las sesiones de protocolo y la cabecera `Mcp-Session-Id` del transporte Streamable HTTP                                                          | El servidor en modo 2026-07-28 **no mantiene estado de sesión de protocolo**                                                                                                               |
| MCP pasa a ser sin estado: se elimina el handshake `initialize` / `notifications/initialized`                                                                | El cliente **no envía** `initialize` en modo 2026-07-28; cada petición lleva versión de protocolo y capacidades del cliente en `_meta` (clave `io.modelcontextprotocol/protocolVersion`)   |
| Las peticiones POST de Streamable HTTP deben llevar las cabeceras `Mcp-Method` y `Mcp-Name`                                                                  | El cliente las envía; el servidor las exige                                                                                                                                                |
| Todos los resultados llevan el campo `resultType`: `"complete"` o `"input_required"`                                                                         | El servidor siempre emite `"complete"`. El cliente que recibe `"input_required"` devuelve al modelo `{error: "input_required_unsupported"}` (v1 no implementa «Multi Round-Trip Requests») |
| Convenciones de propagación de contexto de trazas en `_meta`: `traceparent`, `tracestate`, `baggage`                                                         | El puente de OpenTelemetry (§13.2) las lee y escribe                                                                                                                                       |
| Política de asignación de códigos de error JSON-RPC: `-32000` a `-32019` definidos por la implementación, `-32020` a `-32099` reservados a la especificación | Los códigos propios de Gunther usan solo `-32000` a `-32019`                                                                                                                               |
| Política de ciclo de vida: estados Activo, Obsoleto, Eliminado, con ventana mínima de 12 meses                                                               | La constante de versión soportada vive en un único módulo (abajo)                                                                                                                          |
| Reclasificación del transporte HTTP+SSE como obsoleto                                                                                                        | No se implementa                                                                                                                                                                           |
| Eliminada la reanudación de streams (informes de terceros)                                                                                                   | Un stream interrumpido exige una petición nueva; coincide con §2.9                                                                                                                         |

**Compatibilidad con 2025-11-25 \[CE-H15\]**. r5 afirmaba que el servidor `/mcp` no necesitaba estado de sesión; eso solo es cierto en modo 2026-07-28. Con `mcp.compat_2025_11_25 = true` (defecto `false`) el servidor atiende a clientes de la revisión anterior, lo que **sí exige estado**: handshake `initialize` y `Mcp-Session-Id` por cliente, en ETS con tope `mcp.max_sessions` (256) y caducidad `mcp.session_ttl_seconds` (900), asociados a la clave de API que los creó. Con `false`, un cliente de revisión anterior recibe el error de versión no soportada. El cliente negocia hacia 2026-07-28 y cae a 2025-11-25 solo si el servidor remoto no soporta la nueva.

**Pendiente de verificar \[G-15\]**: el nombre del método de descubrimiento de versión (`server/discover`, citado por una nota de terceros y no por la especificación), el método de liveness en 2026-07-28 y la regla de framing de stdio. Las dos ramas están en el Anexo C. La versión soportada vive en una constante (`Gunther.MCP.Versions`), con un test periódico en CI que consulta el changelog oficial y **avisa** (no rompe la build) si aparece una revisión posterior.

Métodos mínimos: `tools/list`, `tools/call`, `resources/list`, `resources/read`, `prompts/list`, `prompts/get`. **No se implementan** `sampling`, `logging` ni `roots` (r5 los listó como obsoletos \[V5\]; el aviso de obsolescencia de `logging` y de `sampling` consta en el material consultado por r6 \[V\]).

Transportes: **stdio** y **Streamable HTTP** (`POST /mcp`). Servido fuera de loopback exige la autenticación del gateway (§12.2).

### 9.3 Cliente MCP, permisos y confirmación

- **stdio**: se lanza con `Gunther.Command.spawn/3` (§3.4), ejecutable en la lista de permitidos, `stderr: :inherit`, framing por líneas con reensamblado de `:noeol` hasta `mcp.max_message_bytes`.
- **HTTP**: `Finch` con streaming. **Protección frente a SSRF \[CE-28\]**, todas con test con resolver falso:

| Regla                                        | Detalle                                                                                                                                                                                                                                                                                                                           |
| -------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| La URL sale de la config del operador        | Nunca de un prompt ni de un resultado de tool                                                                                                                                                                                                                                                                                     |
| **No se siguen redirecciones**               | `max_redirects: 0`. Una respuesta 3xx es `:mcp_connection_failed` con `details.redirect_to` (sin seguirla). Un servidor comprometido no puede reenviar a `http://169.254.169.254/`                                                                                                                                                |
| Resolución DNS única por intento de conexión | Se conecta a **la IP validada** (la validación y la conexión usan el mismo resultado; se conserva el nombre para SNI y `Host`). Si el nombre resuelve a varias IP, **todas** deben pasar la validación                                                                                                                            |
| Rangos rechazados                            | Loopback (`127.0.0.0/8`, `::1`), privados (`10.0.0.0/8`, `172.16.0.0/12`, `192.168.0.0/16`, `fc00::/7`), enlace local (`169.254.0.0/16`, incluida la dirección de metadatos de nube, y `fe80::/10`), CGNAT (`100.64.0.0/10`), no especificada (`0.0.0.0`, `::`), multicast, y IPv6 mapeada a IPv4 se evalúa por la IPv4 contenida |
| Excepción                                    | `mcp.clients[].allow_private = true`, explícita por cliente                                                                                                                                                                                                                                                                       |
| Reconexión                                   | Repite toda la validación                                                                                                                                                                                                                                                                                                         |

- **Espacio de nombres**: `import_tools` registra cada tool como `<conn_id>__<nombre>`. `:global` en `connect` expone el nombre sin prefijo y falla si choca.
- **Descripciones no confiables \[CE-22\]**: las descripciones y esquemas que publica un servidor MCP son texto no confiable; se truncan a `tools.max_description_bytes` (2048) y `tools.max_schema_bytes`, y se delimitan al entrar al prompt.
- **Permisos**: `tools.permissions` es una lista ordenada de `{pattern, permission}` con `pattern` glob sobre el nombre registrado; gana la primera coincidencia. Valores: `:auto`, `:confirm`, `:deny`. **Defecto sin coincidencia**: `tools.default_permission_local` (`:auto`) para `source: :local` y `tools.default_permission_mcp` (`:confirm`) para tools importadas.

**Protocolo de confirmación \[CE-02, D-32\]**:

| Contexto                             | `:deny`                                                                              | `:confirm`                                                                                                                                                                                                                                                                                                                                                                                                             |
| ------------------------------------ | ------------------------------------------------------------------------------------ | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `chat/2` o `stream/3` **sin agente** | La tool no se ejecuta; el modelo recibe `{error: "tool_denied"}` y el bucle continúa | Si la tool está en `tools.auto_approve` o su `tool_call_id` en `opts.approve_tools`, se ejecuta. Si no: se detiene el bucle y se devuelve `{:error, %Error{code: :tool_confirmation_required, details: %{tool_call_id:, tool:, arguments:, messages:}}}`. El caller puede reenviar `details.messages` con `approve_tools: [tool_call_id]`                                                                              |
| **Agente**                           | Igual que arriba                                                                     | Se emite `[:gunther, :tool, :confirm_required]` (agente, tool, hash de argumentos, `tool_call_id`) y el agente recibe el evento `{:tool_confirm, call}` en `handle/2`. **Debe devolver `{:wait_human, prompt, state}`**; cualquier otro retorno se trata como denegación con warning. `Agent.resume(pid, %{approve: [ids], deny: [ids]})` reanuda. Sin respuesta en `agents.confirm_timeout_ms` (3 600 000) se deniega |

### 9.4 La invocación desde el chat

Cuando el modelo devuelve `tool_calls` y `run_tools: true`:

1.  Validar `arguments` contra el JSON Schema. Si falla, mensaje `role=tool` con `{error: invalid_arguments, schema: ...}` y se vuelve al modelo.
2.  Comprobar permisos (§9.3).
3.  Invocar los `handler` de varias tools **en paralelo** (`Task.async_stream`, `tools.max_parallel`), cada una con su `timeout_ms` y `ctx.cancelled?`.
4.  Cada resultado vuelve como mensaje `role=tool` con `tool_call_id`, en el orden de los ids, tras el truncado de §9.1.
5.  Volver al modelo, hasta `:max_tool_iterations` (5). Al agotarlas: `{:error, :tool_error}` con `details.reason = :max_iterations`.

El presupuesto (§11.6) se acumula entre iteraciones. **Tools definidas por el cliente** (gateway, semántica OpenAI): Gunther **no las ejecuta**: devuelve los `tool_calls` al cliente. Si el nombre choca con una del registro, gana la del cliente y se avisa en la traza.

### 9.5 Ciclo de vida de las conexiones

Estados `:connecting → :connected → :reconnecting → :disconnected`. Reconexión con `Apero.Retry` hasta `reconnect_attempts` (5). Timeout de RPC `rpc_timeout_ms` (30 000). Liveness cada `ping_interval_ms` (60 000) con el método que fije G-15; tres fallos seguidos marcan `:disconnected` y emiten `[:gunther, :mcp, :client_disconnected]`. En modo 2026-07-28 no hay sesión que reinicializar al reconectar.

---

## 10 · Agentes y coral

### 10.1 Agentes

`Gunther.Agent` es un behaviour con `init/1`, `handle(event, state)` y `terminate/2`; **no se registra** en el registry (§5).

| Retorno de `handle`             | Efecto                                                                        |
| ------------------------------- | ----------------------------------------------------------------------------- |
| `{:continue, state}`            | Siguiente turno                                                               |
| `{:wait_human, prompt, state}`  | Suspendido hasta `resume/2`; no consume turnos ni tiempo de `max_duration_ms` |
| `{:spawn, [child_spec], state}` | Arranca hijos supervisados                                                    |
| `{:halt, state}`                | Termina                                                                       |

**Eventos de `handle/2` (gancho G3)**: `{:turn, input}`, `{:tool_confirm, call}` (§9.3) y, bajo una coral (§22), `{:task, task, inputs}`, `{:message, msg}` y `{:board, :changed, key, version}`. Un agente puede arrancarse bajo un supervisor externo (`opts.parent`).

`terminate/2` se llama siempre. **El bucle cierra** (criterio de aceptación): termina por `:halt`, `max_turns` (25), `max_duration_ms`, `budget` agotado (§11.6), `:no_candidates`, `:refused_capacity` o cancelación. **Nunca por excepción**: un error del modelo es un turno más con el error dentro. `%Gunther.Agent{budget:, max_duration_ms:}` acotan el gasto.

**Contrato del `AgentStore` \[CE-07\]**. Un agente no guarda lo mismo que una sesión. El snapshot, opaco para el store, es:

```elixir
%Gunther.Agent.Snapshot{
  schema_version: 1,
  agent_id: binary(), module: atom(), consumer: atom(), session: binary() | nil,
  state: binary(),                         # :erlang.term_to_binary(state, [:compressed])
  status: :running | :waiting | :halted,
  wait_human: %{prompt: binary(), pending_tool_calls: [map()] | nil, since: DateTime.t()} | nil,
  budget_remaining: %{cost_micros: n | nil, tokens: n | nil},
  duration_remaining_ms: n | nil,          # tiempo restante, no un instante: el reloj monotónico no persiste
  turns: n, max_turns: n, depth: n, parent_id: binary() | nil,
  saved_at: DateTime.t()
}
```

Reglas: la lectura usa `:erlang.binary_to_term(binary, [:safe])`; una `schema_version` desconocida es `:store_error`; el store `Disk` firma con HMAC (§15) y rechaza un snapshot cuya firma no valida. Al reanudar, el plazo nuevo es `now + duration_remaining_ms`.

**HITL**: la suspensión se persiste en `AgentStore`. Sobrevive al reinicio del **agente**; sobrevive al reinicio de **Gunther** solo con el store `Disk`.

**Sub-agentes**: `{:spawn, ...}` arranca hijos bajo el padre, con profundidad máxima `agents.max_depth` (3). El presupuesto del hijo sale del del padre.

**Identidad y reinicio**: agentes sin nombre derivan su identidad de `{módulo, sha256(opts)}` (D-25). Restart `:transient`. **Se retira** la regla de r4 «un agente caído no reinicia si su breaker está abierto»: el breaker es por provider y el agente por tarea. Con el provider caído, el turno devuelve `:provider_unavailable` como evento y el agente decide.

### 10.2 La coral: v1.1 experimental \[D-56, D-74\]

> **Reformulada por §22 (D-74, M-03, Q-13)**: «mesa camilla» y «mente colmena» son el mismo concepto, y pasa a ser la modalidad `:hive` de la coral. La votación de enrutado de las voces (D-46) pasa a la modalidad `:routing_vote`. El texto de abajo se conserva como historia; ver §22 para la especificación completa.

Un miembro con `maybe_rank/3` opina por la capa `:llm`, que es lo mismo que registrar un `Classifier`. `handle_message/2` añade coordinación asíncrona entre miembros, que es un problema distinto, y es el único módulo cuyo valor no se mide con el corpus de §16.3 sin un criterio adicional.

**Propuesta**: v1 se entrega con `Classifier` múltiple (§6.4). La coral se publica en **v1.1 como experimental**; criterio de promoción: un conjunto de miembros supera, **medido con el corpus del router** (§6.11, incluido el adversario), al mejor clasificador individual verificado.

Contrato: `init(opts)`, `handle_message(message, state) :: {:reply, binary()} | {:noreply, state}`, `maybe_rank(prompt, candidates, state, ctx) :: {:ok, [atom()]} | :skip`. **`ctx` ofrece `decide/2` (§6.11) y no ofrece `chat`.** `Coral.tell/2` envía a un miembro y devuelve `{:error, :not_found}` si no existe; `broadcast/1` a todos. **No hay `GenServer.call` bloqueante entre miembros**. La memoria común es `Memory` con `consumer: :global` (§7.4) o la pizarra de la ejecución (§22.6). Un miembro no es un agente (D-14).

---

## 11 · Engine y recursos

### 11.1 El engine

Reserva → carga → infiere → suelta (D-27, D-28). Estados: `:reserved → :starting → :running → :stopping → :stopped`, con `:failed` (no arrancó), `:crashed` (murió en `:running`) y `:unreachable` (solo remotos, §18).

**`Gunther.Engine.Backend`** es la interfaz interna que separa **dónde** corre el engine de **cómo** lo usa el resto del sistema: `reserve/3`, `start/2`, `health/1`, `stop/2`, `measure/1`, `endpoint/1`. Tiene dos implementaciones: `Backend.Local` (esta sección) y `Backend.Remote` (§18.6). El router, el ledger y el pipeline de resiliencia no distinguen entre ellas.

**Arranque de `llama-server` (modo local)**:

- Se lanza con `Gunther.Command.spawn/3` (§3.4): sin shell, con marca de instancia (§2.8). **No** lo arranca `Trebejo.Proc`, que solo lista y señala.
- Los argumentos los construye `ArgsBuilder` (§3.4, CE-19). Incluye siempre: `--host 127.0.0.1` (**un engine local nunca escucha fuera de loopback**), `--port <puerto>`, `--alias gunther-<instancia>-<alias>`, `--parallel <max_concurrency>`, `--ctx-size`, la selección de device con `-dev`/`--device` (el flag existe y acepta los nombres de `--list-devices` \[V\]) y `--no-webui` (existe \[V\]).
- **Clave de API por engine**: se genera una clave aleatoria de 32 bytes por arranque y se pasa **por variable de entorno** `LLAMA_API_KEY` (variable documentada de `--api-key` \[V\]), no por argv, que es visible en la lista de procesos. `GET /health` es público \[V\] y no la necesita.
- **Puerto**: se elige dentro de `engine.port_range` y se comprueba con `lsof` antes de lanzar.
- **Arranque**: `:starting` espera `GET /health` hasta `engine.start_timeout_ms` (120 000), **independiente** del timeout de la petición. Si vence, `:failed` y se libera la reserva.
- **Estados de la reserva (D-27, D-89)**: `reservada` (antes de arrancar, con el peso de §11.5 más el margen), `arrancada` (tras cargar se mide la memoria real del engine; si supera `reserved_mib` se corrige con `release` + `acquire` y se emite el warning `:reserve_exceeded`; si es menor, la reserva se conserva) y `liberada`. Un fallo de arranque (la falta de memoria mata el proceso) libera la reserva.
- **Reintento en otro device (D-27, D-89)**: si la carga falla en un device y hay otros `usable` donde cabe, se reintenta en cada uno como máximo una vez, liberando la reserva entre intentos; agotados, `:failed`. Con un solo device, un fallo es `:failed` sin reintento.
- **Capas y device del motor (D-27, D-89)**: el número de capas que recibe el motor es un **entero** (el que produce `llama-fit-params` con el método `fit`, o el de la fórmula; nunca `-1`); `--fit on` queda como red de seguridad. Para un device único se pasa `--device <nombre del motor>` (`CUDA0`, no un índice), `--split-mode none` y `--main-gpu <índice>`: el índice es **otra coordenada** que el nombre y se toma de la posición del device en la lista del motor (G-10).
- **Carga en frío**: N peticiones simultáneas a un modelo descargado provocan **una** carga (single-flight por alias, un proceso `Engine.Loader` por alias); las demás esperan o reciben `:no_model_available` con `retry_after_ms`, según la política de refusal.
- **Descarga por inactividad**: `engine.idle_unload_seconds` (600) libera la VRAM salvo modelos `resident`.
- **Caída**: `:exit_status` libera el ledger y emite `[:gunther, :engine, :crashed]`. Reintentos con backoff hasta `engine.max_restarts` (3); al agotarlos, el modelo queda `unavailable` hasta recarga manual.
- **Concurrencia**: `max_concurrency` del modelo lo impone el bulkhead (§2.6) y es el valor de `--parallel`: **una sola fuente**, derivada del catálogo; no se configuran por separado.

### 11.2 Devices \[D-28, D-65\]

Un **device** es un slot con identidad física, un presupuesto y una fuente de medida. Su clave es `{node, physical_id}` (`node = :local` para la máquina del controlador). `Device.t()` está en §5.12. **Sin medición no hay cifra**: `usable: false` con `reason` y no se devuelve `available`. Un modelo de CPU no pide device (`{:ok, nil}`, no reserva VRAM). En v1, **un modelo ocupa un solo device**: el reparto de tensores entre GPUs queda fuera.

### 11.3 El ledger \[D-48, CE-23\]

`Gunther.Resource.Ledger`, un `GenServer` con ETS. Contrato:

```elixir
acquire(device_key, holder, mib) :: :ok | {:error, :no_room}
release(device_key, holder) :: :ok                       # idempotente
available(device_key) / capacity(device_key) / holders(device_key)
resync(device_key) :: :ok                                 # re-mide bajo el Placement (abajo)
subscribe(device_key | :all) :: :ok                       # para la política wait (§6.9)
```

El `holder` es `{alias, port, make_ref()}`. `quota` es `0`, nunca `:infinity`. **No hay titular `:system`.**

**Una sola fuente de medida por device (D-28, D-89).** La fórmula miente si `capacity` y `free` salen de fuentes distintas, así que cada device usa **una** de dos convenciones y nunca las mezcla:

| Convención                    | `capacity` y `free`                                                                            | `foreign`                                                               | Condición                                                                                                                                                                                                                                                                   |
| ----------------------------- | ---------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **A (defecto)**: la del motor | `total` y `free` de `--list-devices`                                                           | Regla de quiescencia (abajo); sin atribución por proceso                | Siempre disponible. El overhead del contexto del backend ya queda fuera de `capacity`: no se resta ni se registra un titular `:system`                                                                                                                                      |
| **B**: la del sistema         | `total_sistema − devices.overhead_mib[backend]` y `libre_sistema`, **de la misma herramienta** | Con `attribution: :per_process`, la suma por proceso de esa herramienta | Solo si el emparejamiento entre el identificador del sistema y el nombre del motor es inequívoco (G-11). `overhead_mib` es **obligatorio** y se obtiene con `Doctor.calibrate_overhead/2`, con su procedencia registrada; sin él, `device_unusable` con `:overhead_unknown` |

**Memoria ajena (`foreign`) — corrección de r5.** r5 definía `available = capacity − foreign − candil_used` sin decir cómo se mide `foreign` cuando hay engines propios cargando, lo que mezcla memoria ajena con memoria propia aún no asignada. Definición:

| Caso                                                                                                                                | `foreign`                                                                           |
| ----------------------------------------------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------- |
| Convención B y `attribution: :per_process`                                                                                          | Suma de `mib` de los procesos cuyo `pid` **no** es un engine de Gunther en ese nodo |
| Convención A, o B sin atribución, y **ningún engine del device** está en `:reserved`, `:starting` o `:stopping` (estado quiescente) | `max(0, capacity − free_medido − Σ reserved_mib de los engines en :running)`        |
| Igual que arriba y hay un engine en transición                                                                                      | Se **congela** el último valor medido en estado quiescente                          |
| Nunca medido en quiescencia                                                                                                         | `device_unusable` con `reason: :foreign_unknown` hasta la primera medida quiescente |

La medida se hace bajo el semáforo de `Placement` (§11.4). Se reajusta solo si la diferencia con el valor guardado es mayor que `devices.foreign_resync_threshold_mib` (64), para no provocar `release` + `acquire` inútiles.

**Disponible** (discretos): `available = max(0, min(capacity − foreign − gunther_used, free_medido_ahora))`. El `min` es **seguro en ambos sentidos**: con una reserva pendiente (aún no asignada en el device) gana el primer término, que ya la descuenta; con memoria ajena que crece tras la última medida gana el segundo.

**Unificada** (`kind: :unified`, §11.8): `available = max(0, min(max_mib − reserve_mib − gunther_used, free_medido_ahora))` con `max_mib` y `reserve_mib` **obligatorios** en la config del device.

**Tamaño de una reserva**: `reserved_mib = ceil(peso_calculado_mib) + engine.vram_margin_mib`, con `engine.vram_margin_mib` por defecto **1024**, que es el margen por defecto de `--fit-target` en `llama-server` \[V\]. El `peso_calculado_mib` sale de §11.5.

**Invariantes** (tests de propiedades con `StreamData`): `used ≤ capacity` siempre; `release` repetido no cambia nada; tras `init` con engines vivos, la suma de holders coincide con los registros adoptados (§2.8); `available` nunca supera `free_medido_ahora`.

**Por qué propio**: es un modelo de dominio (device, foreign, holders) que un ledger de capacidad fija obliga a distorsionar. `Arrea.Resource` existe en `main` según la medición del dueño (D-13); su publicación en Hex está pendiente de G-28 (Q-14), pero su API pública actual no modela `foreign` por proceso ni `available` con quiescencia; si G-28 demuestra que puede hacerlo sin duplicar medidas, este módulo pasa a ser una fachada.

**Ledger remoto**: la autoridad de los devices de un nodo es el **ledger del nodo** (§18.3). El ledger del controlador guarda un **espejo** de solo lectura sincronizado por eventos; toda adquisición en un nodo pasa primero por `POST /leases` en el nodo.

### 11.4 El Placer \[D-53\]

`Gunther.Engine.Placer.place(model, devices, opts)`:

1.  Reúne los devices candidatos: el `device` fijado en el modelo, o todos los `usable` compatibles con el backend del binario del engine, **locales y de nodos** (§18.7).
2.  Para cada uno, bajo `Placement` del nodo: `resync`, calcula `reserved_mib` (§11.5) y comprueba si cabe.
3.  Si cabe **y** no se supera `placement.max_loaded_models` (§14.1), `{:ok, device_key}`. Si no cabe, o se superaría el tope por conteo, y se permite expulsar, elige víctimas y reintenta; si no, `{:error, :no_room}`.
4.  Sin devices, `:no_gpu`; si no se pudo medir, `:memory_unknown`; si el device existe pero no es usable, `:device_unusable`.

**Orden de preferencia entre devices candidatos**: el de `placement.prefer` (lista de ids de nodo, `"local"` para la máquina del controlador) en el orden dado; dentro del mismo nodo, el de mayor `available`; desempate por `physical_id` (orden alfabético). Sin `placement.prefer`, el orden es: local primero.

**Tope por conteo (D-71)**: además de la memoria, `placement.max_loaded_models` limita cuántos modelos pueden estar cargados a la vez en cada nodo (el local incluido). Los `resident` cuentan. Cuando se alcanza, cargar otro exige expulsar uno (misma regla de expulsión) o aplicar refusal (§6.9). Gunther **solo arranca y apaga** modelos ya instalados: no los descarga (§3.4).

**Expulsión**: orden por último uso más antiguo; nunca se expulsa un modelo `resident`, uno con peticiones en vuelo ni, si el candidato es `exclusive`, se mezcla con otros (D-02b). El tamaño liberado de una víctima es su `reserved_mib` registrado (o la medida por proceso si hay `:per_process`).

**Semáforo `Gunther.Engine.Placement`**: un proceso **por nodo** que serializa `resync` + `reserve`, de modo que dos arranques concurrentes en el mismo nodo no midan la misma memoria libre. Un nodo ocupado no bloquea a los demás. Monitoriza al titular del turno y lo libera en `:DOWN`. **No usa `:global.trans/3`**: Gunther es un solo controlador por instancia y un `GenServer` por nodo basta; la lógica entre varios controladores sobre un nodo la resuelve la autoridad del ledger del nodo (§18.5).

### 11.5 El peso \[CE-24\]

- `vram_mb` del catálogo es **cota inferior**, no verdad (D-27).
- **Método `fit`** (preferido): `llama-fit-params` vía `Gunther.Command.run/3`, si existe en el binario instalado (G-09), se mide **antes** de arrancar. El README de `llama-server` documenta `--fit` y `--fit-target` (margen por device; defecto 1024) \[V\]. Si el usuario fijó `--n-gpu-layers N`, el ajuste aborta y el Placer devuelve `:gpu_layers_fixed`. Si `llama-fit-params` no existe (rama B de G-09), el engine se arranca con `--fit on` y `--fit-target` del margen y el Placer reserva con el método de fórmula o con `vram_mb` declarado.
- **Método `formula`** (alternativa): para el modelo y el contexto fijados, el parser de GGUF (propio, con test de fuzz) lee de la cabecera los parámetros y calcula

```
kv_bytes = Σ sobre capas con atención  n_ctx · n_head_kv[l] · ( key_length[l]·bytes(type_k) + value_length[l]·bytes(type_v) )
peso_calculado_mib = ceil( (bytes_de_pesos_offloaded + kv_bytes + compute_buffer_mib·2^20) / 2^20 )
```

con `n_ctx` el contexto total (`--ctx-size`), `n_head_kv`, `key_length` y `value_length` por capa tal como figuran en la cabecera (G-14), y `compute_buffer_mib` **obligatorio en la config del modelo** (la fórmula no lo puede calcular). Corrección de r5: r5 daba `2 · n_layers · n_kv_heads · head_dim · ctx · bytes` y fijaba `q8_0 = 1` byte por elemento. **`q8_0` no ocupa 1 byte por elemento**: los tipos cuantizados de ggml se almacenan en bloques; los bytes por elemento son `tamaño_de_bloque_en_bytes / elementos_por_bloque`, que Gunther **lee de la tabla de tipos de ggml** en F0 (G-14) en lugar de fijarlos a mano. Los valores esperados que el test de F0 confirma o corrige son: `f32` 4, `f16` 2, `bf16` 2, `q8_0` 34/32, `q5_1` 24/32, `q5_0` 22/32, `q4_1` 20/32, `q4_0` 18/32.

**Aplicabilidad de la fórmula por tipo de atención** (se detecta con las claves de la cabecera GGUF, G-14):

| Tipo detectado                                          | Resultado de la fórmula                                                                                                                            | Qué hace Gunther                                                        |
| ------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------- |
| Atención estándar (MHA o GQA)                           | **Exacta** para la KV cache                                                                                                                        | Usa la fórmula                                                          |
| Ventana deslizante (clave de `sliding_window` presente) | **Cota superior** con el defecto de `llama-server` (la caché SWA es menor salvo con `--swa-full`, flag documentado \[V\]); exacta con `--swa-full` | Usa la fórmula y marca `upper_bound: true` en la traza                  |
| MLA (clave de `kv_lora_rank` presente)                  | **No válida**                                                                                                                                      | `fit` obligatorio; si no, `vram_mb` declarado; si no, `:memory_unknown` |
| Recurrente o SSM (estado en lugar de KV por capa)       | **No válida**                                                                                                                                      | Igual que MLA                                                           |
| Tipo no reconocido                                      | **No válida**                                                                                                                                      | Igual que MLA                                                           |

Si el parser falla, se usa `vram_mb` declarado; si tampoco existe, `:memory_unknown`.

### 11.6 Presupuesto, retry y coste \[CE-25\]

- **Presupuesto**: `budget.max_cost_per_request` y `opts.budget`. Se comprueba **antes de cada llamada**:

```
estimacion_micros = ceil(tokens_entrada · precio_entrada_mtok / 1_000_000) + ceil(max_tokens_efectivo · precio_salida_mtok / 1_000_000)
```

con `tokens_entrada` del contador de §7.6 y `max_tokens_efectivo = opts.max_tokens` o, si es `nil`, `max_output_tokens` del modelo. Corrección de r5: r5 solo contaba la salida. Un modelo sin precio (`pricing` nulo) tiene coste 0 y no necesita contador. Si `estimacion_micros` supera lo que queda del presupuesto, `:budget_exceeded` antes de llamar.

- Los reintentos, los saltos de failover, los reintentos de structured output y las iteraciones del tool loop **se acumulan**; tras cada llamada se descuenta el coste **real** (`usage`).
- **Retry**: `retry.max_attempts` (3), backoff base 200 ms, tope 5000 ms, con jitter, solo si `retryable?`.
- **Rate limit**: `Arrea.RateLimiter` por provider con `rpm` y `tpm`. El `tpm` consume `tokens_entrada + max_tokens_efectivo` como peso si la primitiva admite peso (G-04); si no, solo `rpm` y `Doctor` emite `:warn`. Si el backend devuelve 429, se respeta su `retry-after`.

- **Presupuesto jerárquico (gancho G5)**: el `Context` (§22.3) lleva el presupuesto restante; un agente hijo o un miembro de la coral recibe un subpresupuesto que **se descuenta del padre** (`Gunther.Budget.split(parent, partes)`), de modo que la suma de lo gastado nunca supera lo asignado arriba.

### 11.7 Backends GPU \[D-69\]

Backends soportados en v1: **CUDA, Vulkan, ROCm y Metal**, más CPU. El dueño citó «cuda, vulkan, rock y metal»; «rock» se interpreta como **ROCm** (ver Q-05 en §21).

**Detector por defecto (`Detector.LlamaCpp`)**: ejecuta `<binario_del_engine> --list-devices` con `Gunther.Command.run/3`. Se usa el **mismo binario que lanzará el engine**, así que lo que se mide es lo que se usará, para cualquier backend compilado en él. Formato verificado de las líneas de salida \[V\]: `<NombreBackend><n>: <descripción> (<total> MiB, <libre> MiB free)`, por ejemplo `CUDA0: NVIDIA GeForce RTX 5090 (32106 MiB, 55372 MiB free)` y `Vulkan0: NVIDIA GeForce RTX 2060 (6144 MiB, 5136 MiB free)`. Expresión de análisis:

```
^\s*([A-Za-z]+)([0-9]+): (.+) \((\d+) MiB, (\d+) MiB free\)\s*$
```

Reglas sobre lo que se ha observado \[V\]:

| Hecho observado                                                                                                        | Regla de Gunther                                                                                                               |
| ---------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------ |
| Un dispositivo de CPU puede no aparecer en la lista                                                                    | La CPU la sintetiza `Detector.Cpu` con `Trebejo.OS`; nunca se exige que aparezca                                               |
| Se vio `CUDA0` con `free` (55372 MiB) **mayor** que `total` (32106 MiB) por una detección errónea de memoria unificada | **Comprobación de coherencia obligatoria**: si `free > total`, el device queda `usable: false`, `reason: :inconsistent_report` |
| Las líneas `RPC0`, `RPC[host:puerto]` aparecen cuando se usa `--rpc`                                                   | **Se ignoran**: Gunther no pasa nunca `--rpc` (D-66) y descarta cualquier device cuyo backend sea `RPC` con warning            |
| Un mismo binario puede cargar varios backends a la vez (CUDA, ROCm, Vulkan, RPC)                                       | Un mismo GPU físico puede aparecer **dos veces** con nombres distintos (§11.8)                                                 |

**Matriz de capacidades por backend** (lo que no está verificado figura como puerta):

| Backend | Nombre en `--list-devices`                                    | Identidad física (`physical_id`)                                                                               | Atribución por proceso                                   | Notas                                                                                 |
| ------- | ------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------- | -------------------------------------------------------- | ------------------------------------------------------------------------------------- |
| CUDA    | `CUDA<n>` \[V\]                                               | UUID de `nvidia-smi --query-gpu=uuid` (G-11)                                                                   | `nvidia-smi --query-compute-apps=pid,used_memory` (G-11) | Riesgo de falsa memoria unificada \[V\]                                               |
| ROCm    | `ROCm<n>` (G-10; el log de carga indica backend «ROCm» \[V\]) | Id único de `rocm-smi` o `amd-smi` (G-11)                                                                      | `rocm-smi` o `amd-smi` (G-11)                            | Binario compilado con ROCm \[V: existe distribución para Linux x64\]                  |
| Vulkan  | `Vulkan<n>` \[V\]                                             | No hay un id neutral en la salida: **mapeo obligatorio** en `[[devices]]` salvo un único device físico (§11.8) | No (`attribution: :none`)                                | En iGPU/APU el total es memoria compartida \[V\]: `kind: :unified`                    |
| Metal   | `MTL<n>` (G-10; consta en una distribución de terceros \[V\]) | Un único GPU: `metal:0` sintético                                                                              | No                                                       | Siempre `kind: :unified`                                                              |
| CPU     | Sintético                                                     | `cpu`                                                                                                          | No                                                       | Capacidad = memoria de sistema (`Trebejo.OS`), **no se reserva en el ledger de VRAM** |

**Cómo se añade otro backend** (por ejemplo SYCL u OpenCL): implementar `Gunther.Detector` y un perfil de `ArgsBuilder`, sin tocar el núcleo. Fuera de v1.

### 11.8 Identidad física, memoria unificada y coherencia \[D-65, CE-26\]

El nombre de backend (`CUDA0`, `Vulkan0`) **no identifica un GPU físico**: dos backends pueden ver el mismo GPU y un índice puede cambiar entre arranques. Indexar el ledger por nombre contaría la misma VRAM dos veces. Regla:

1.  **Un solo device físico visible en total** (un único GPU entre todos los binarios configurados): el `physical_id` se asigna automáticamente.
2.  **Más de uno** (varios GPUs, o el mismo GPU por varios backends): **`[[devices]]` es obligatorio**: cada entrada fija `physical_id` y los nombres de backend que le corresponden. Sin mapeo, esos devices quedan `usable: false`, `reason: :unmapped`, y `Doctor` imprime la tabla candidata (nombre, descripción, total) para que el operador la complete.
3.  **Capacidad de un device con varios backends**: el **mínimo** de los totales informados. Si difieren en más de `devices.total_tolerance_mib` (256), `Doctor` emite `:warn`.
4.  **Selección en el engine**: el Placer convierte `physical_id` al nombre de backend del binario del engine; si ese binario no expone ese device, `:device_unusable`.

**Memoria unificada** (`kind: :unified`: Metal, APU, iGPU, y cualquier device con `kind` declarado): la memoria es compartida con el sistema y el valor «total» que informa el backend no es un presupuesto utilizable. `[[devices]]` **exige** `max_mib` (presupuesto máximo para Gunther) y `reserve_mib` (reserva para el sistema); sin ellos, `:device_unusable` con `reason: :unified_needs_limit`. No existe un valor por defecto, porque no existe un hecho que lo fundamente.

**Aislamiento por variables de entorno**: la visibilidad de dispositivos para el engine se fija por `[[engines]].env` (por ejemplo variables de visibilidad de CUDA o HIP) y por `-dev`. Gunther **no hereda** el entorno de la VM (R2, §3.4).

---

## 12 · Gateway

`Gunther.Gateway` es un `Plug` sobre `Bandit`, opcional, arrancado por la aplicación anfitriona (D-31).

### 12.1 Endpoints

| Método y ruta               | Qué hace                                                                                                                 |
| --------------------------- | ------------------------------------------------------------------------------------------------------------------------ |
| `POST /v1/chat/completions` | Subconjunto de la API de chat de OpenAI sobre `Gunther.chat/2` y `stream/3`. `model` es un alias del catálogo o `"auto"` |
| `POST /v1/embeddings`       | `Gunther.embed/2`                                                                                                        |
| `GET /v1/models`            | Catálogo visible para la clave                                                                                           |
| `POST /v1/gunther/route`    | Solo la decisión (`Router.route/2`), sin ejecutar                                                                        |
| `POST /mcp`                 | Servidor MCP Streamable HTTP (§9.2)                                                                                      |
| `GET /healthz`              | Vida del proceso. Sin autenticación, sin datos internos                                                                  |
| `GET /readyz`               | `Gunther.health/1`; 200 si `status != :down`. Sin autenticación, sin datos internos                                      |

Streaming: `text/event-stream`, `data: {...}\n\n` y `data: [DONE]`. Los errores usan el sobre de errores de OpenAI con el código de §4.13 en `error.code`. Las **tools del cliente** se devuelven sin ejecutar (§9.4).

Cabeceras de respuesta: `X-Gunther-Trace-Id`; con `trace: true` en la petición, `X-Gunther-Model` y `X-Gunther-Degraded` (`true`/`false`, el campo `degraded` de §4.2).

### 12.2 Autenticación y exposición \[CE-27\]

| Regla                    | Detalle                                                                                                                                                                                                                                                                                                                                                                                       |
| ------------------------ | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Enlace por defecto       | `bind: {127, 0, 0, 1}`                                                                                                                                                                                                                                                                                                                                                                        |
| Enlace fuera de loopback | **Exige** `auth: :api_key` **y** TLS (`tls: [certfile:, keyfile:]`). Sin ambos, el arranque falla con `config_error`. Excepción explícita `gateway.allow_plaintext_remote = true` (defecto `false`)                                                                                                                                                                                           |
| Claves                   | `[[gateway.api_keys]] id, sha256, consumer`. En la config solo vive el `sha256` de la clave (**hex en minúsculas, sin separadores, del SHA-256 de la clave en UTF-8**); la comparación es de tiempo constante (`Plug.Crypto.secure_compare/2`). La clave no se registra nunca                                                                                                                 |
| Cabecera                 | `Authorization: Bearer <clave>`                                                                                                                                                                                                                                                                                                                                                               |
| Consumer                 | La clave fija el `consumer` de la petición; el cliente no puede elegirlo                                                                                                                                                                                                                                                                                                                      |
| Límites                  | `gateway.max_body_bytes` (1 MiB; en `/v1/chat/completions` el tope es `gateway.max_attachment_body_bytes`, derivado: `ceil(max_attachment_bytes máximo de los modelos × 4 / 3) + gateway.max_body_bytes`, porque base64 ocupa 4/3 del original, D-92), `gateway.max_headers_bytes`, `gateway.request_timeout_ms`, `gateway.max_connections`; límite de peticiones por clave (`rpm` por clave) |
| CORS                     | Desactivado por defecto                                                                                                                                                                                                                                                                                                                                                                       |
| Observabilidad           | Una traza por petición; sin contenido de prompt en logs                                                                                                                                                                                                                                                                                                                                       |

### 12.3 Subconjunto de la API de chat \[CE-32\]

El gateway implementa el **formato de chat de OpenAI según su documentación pública**; la compatibilidad se verifica en F9 con clientes reales. Regla: **un campo no soportado es `:invalid_request` con `details.unsupported_field`; no se ignora en silencio.**

| Petición                                             | Soporte                                                                                               |
| ---------------------------------------------------- | ----------------------------------------------------------------------------------------------------- |
| `model`                                              | Alias del catálogo o `"auto"`                                                                         |
| `messages`                                           | Roles `system`, `user`, `assistant`, `tool`; `content` texto o partes de texto, imagen y audio (D-34) |
| `stream`, `stream_options.include_usage`             | Sí                                                                                                    |
| `temperature`, `top_p`, `max_tokens`, `stop`, `seed` | Sí (§4.2)                                                                                             |
| `tools`, `tool_choice`                               | Sí; las tools del cliente se devuelven sin ejecutar (§9.4)                                            |
| `response_format`                                    | `text`, `json_object`, `json_schema` (§4.2.1)                                                         |
| `n`                                                  | Solo `1`                                                                                              |
| Otros campos                                         | `:invalid_request`                                                                                    |

| Respuesta       | Contenido                                                                                                                                                                                                 |
| --------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Cuerpo          | `id`, `object`, `created`, `model` (el alias ganador), `choices[0].message` (`role`, `content`, `tool_calls`), `choices[0].finish_reason`, `usage` (`prompt_tokens`, `completion_tokens`, `total_tokens`) |
| `finish_reason` | `:stop` → `stop`; `:length` → `length`; `:tool_calls` → `tool_calls`; `:content_filter` → `content_filter`; `:error` → error HTTP                                                                         |
| Error           | `{"error": {"message", "type", "code"}}` con el código de §4.13                                                                                                                                           |

---

## 13 · Telemetría

### 13.1 Eventos

Prefijo `[:gunther, ...]`. **Regla de contenido**: los metadatos llevan identificadores, hashes y contadores; **nunca** prompts, respuestas, argumentos de tools, claves ni secretos. **Regla de cardinalidad**: las etiquetas permitidas son `alias`, `provider`, `node`, `device`, `layer`, `code`; ninguna etiqueta toma valores ilimitados por petición.

| Evento                                                                  | Medidas                         | Metadatos                                                                                                                                            |
| ----------------------------------------------------------------------- | ------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------- |
| `[:request, :start \| :stop \| :exception]`                             | duración, tokens, `cost_micros` | `trace_id`, `consumer`, `alias`, `degraded`                                                                                                          |
| `[:router, :decision]`                                                  | duración                        | `layers_ran`, `chosen`, `reason`, `decision_model`                                                                                                   |
| `[:router, :cache_hit \| :cache_miss]`                                  |                                 | hash de clave                                                                                                                                        |
| `[:classifier, :call]`                                                  | duración, tokens                | `spec_id`, `kind`, `outcome` (`ok \| abstain \| error \| timeout \| invalid_label`)                                                                  |
| `[:classifier, :verified \| :failed]`                                   |                                 | `spec_id`, `report_id`                                                                                                                               |
| `[:provider, :call, :start \| :stop]`                                   | duración, tokens                | `provider`, `alias`, `node`, `attempt`                                                                                                               |
| `[:provider, :quality]`                                                 |                                 | `alias`, `provider`, `finish_reason`, `retries`: salud del destino por `finish_reason` anómalo y reintentos (D-12, D-90); **no se usa para enrutar** |
| `[:breaker, :opened \| :half_open \| :closed]`                          |                                 | `provider`                                                                                                                                           |
| `[:engine, :state]`                                                     |                                 | `alias`, `from`, `to`, `node`                                                                                                                        |
| `[:engine, :crashed]`                                                   |                                 | `alias`, `exit_status`, `node`                                                                                                                       |
| `[:ledger, :acquire \| :release \| :no_room]`                           | `mib`                           | `device`, `node`                                                                                                                                     |
| `[:node, :connected \| :unreachable \| :lease_expired \| :auth_failed]` |                                 | `node`                                                                                                                                               |
| `[:tool, :call \| :confirm_required \| :denied]`                        | duración                        | `tool`, `source`, hash de argumentos                                                                                                                 |
| `[:command, :blocked]`                                                  |                                 | `reason`                                                                                                                                             |
| `[:mcp, :client_disconnected]`                                          |                                 | `conn_id`                                                                                                                                            |
| `[:guardrail, :veto \| :modify]`                                        |                                 | `kind`, `name`                                                                                                                                       |
| `[:session, :compacted]`                                                | tokens antes y después          | `session` (hash)                                                                                                                                     |
| `[:cache, :hit \| :miss \| :evict]`                                     |                                 | `kind`, hash de clave                                                                                                                                |
| `[:coral, ...]`                                                         |                                 | Ver §22.11                                                                                                                                           |

### 13.2 Puente de OpenTelemetry

Opcional (`opentelemetry`). Un span por petición con hijos por capa de decisión, llamada a provider y tool. Lee y escribe `traceparent`, `tracestate` y `baggage` en `_meta` de MCP (§9.2) y en cabeceras HTTP salientes hacia nodos (§18.3).

### 13.3 Puente de Arrea y Apero

Ver §3.5. El mapeo de nombres es explícito.

### 13.4 Logs

Logger con metadatos estructurados. **Redacción**: los structs de config con secretos implementan `Inspect` con `except:` para esos campos; las cabeceras `Authorization` no se registran; las salidas de `llama-server` (anillo de §3.4) se registran solo al diagnosticar un arranque fallido.

---

## 14 · Configuración

### 14.1 Esquema de `gunther.toml`

Esquema completo por secciones. Defecto = el valor que se usa si falta la clave; «**obligatorio**» significa que no existe defecto y su ausencia es `config_error`.

```toml
[gunther]
instance_id = "main"                  # obligatorio; [a-z0-9_-]{1,32}
state_dir = "/var/lib/gunther"        # obligatorio si hay engines locales, nodos o sesiones en disco
dotenv = false

[router]
llm = "fallback"                      # never | fallback | always
llm_timeout_ms = 1500
llm_warm_cache = false
max_failovers = 2
max_in_flight = 256
fallback_strategy = "least_used"      # last | first | round_robin | least_used
regex_match_limit = 100000
allow_general = false
allow_unverified = false
affinity = "off"                     # off | prefer (§22.12)
# affinity_weight = 0.0               # obligatorio con prefer
classifiers = ["router_pref"]         # ids de [[decision_models]] u otros Classifier registrados
[router.capture]                      # §16.4
enabled = false
max_entries = 10000
[router.cache]
enabled = true
ttl_seconds = 300
max_entries = 10000
[router.embedding]
min_similarity = 0.0                  # defecto 0.0 (D-92); lo calibra Doctor.calibrate_router/2

[refusal]
policy = "wait"                       # fail | wait | degrade
wait_ms = 10000

[retry]
max_attempts = 3
base_ms = 200
cap_ms = 5000
attempt_timeout_ms = 60000

[circuit_breaker]                     # los nombres internos de Arrea los traduce Gunther.Resilience (G-02)
failure_rate_threshold = 0.5
min_calls = 10
open_duration_ms = 30000
half_open_probes = 1

[engine]
start_timeout_ms = 120000
idle_unload_seconds = 600
vram_margin_mib = 1024
port_range = [39000, 39999]
log_lines = 2000
max_restarts = 3
shutdown_timeout_ms = 30000

[devices]
foreign_resync_threshold_mib = 64
total_tolerance_mib = 256

[[devices.map]]                       # obligatorio si hay más de un device físico visible (§11.8)
physical_id = "gpu0"
kind = "discrete"                     # discrete | unified
# max_mib = 12000                     # obligatorio y mayor que 0 si kind = "unified"
# reserve_mib = 2048                  # obligatorio y mayor que 0 si kind = "unified"
backend_names = { cuda = "CUDA0", vulkan = "Vulkan1" }

[commands]                            # sección de seguridad: clave desconocida = error
allow = [ { name = "llama-server", path = "/opt/llama.cpp/bin/llama-server", sha256 = "..." } ]
env_allow = ["PATH"]

[[engines]]
id = "llama_cuda"
command = "llama-server"              # nombre de [commands].allow
backend = "cuda"                      # cuda | vulkan | rocm | metal | cpu
env = { CUDA_VISIBLE_DEVICES = "0" }
allowed_extra_args = []
min_build = 0                         # Doctor falla si `--version` informa una compilación menor (T-14)

[[models]]
alias = "qwen_27b"
provider = "llamacpp"
model_id = "..."
locality = "local"                    # local | lan | cloud
node = ""                             # id de [[nodes]] si va a un nodo; vacío = local
engine = "llama_cuda"                 # id de [[engines]] (local) o perfil del nodo (con node)
path = "/models/qwen.gguf"            # solo local; en nodos lo fija el perfil del nodo
capabilities = ["code", "reasoning"]
modalities = ["text"]
context_window = 32768
ctx_size = 16384
max_output_tokens = 4096
max_concurrency = 4
vram_mb = 0                           # cota inferior declarada; 0 = no declarada
compute_buffer_mib = 0                # obligatorio si se usa el método formula
fit = "auto"                          # auto | formula | declared
kv_type_k = "f16"
kv_type_v = "f16"
resident = false
exclusive = false
tags = []
pricing = { input_per_mtok_micros = 0, output_per_mtok_micros = 0 }
max_attachment_bytes = { image = 20971520, audio = 52428800 }   # D-34: 20 MiB y 50 MiB

[[nodes]]                             # sección de seguridad: clave desconocida = error
id = "pc2"
url = "https://192.168.1.20:7443"     # solo https
pinned_server_cert_sha256 = ["..."]   # obligatorio; lista para poder rotar (dos huellas a la vez)
client_cert_file = "/etc/gunther/pc1.crt"
client_key_file = "/etc/gunther/pc1.key"
heartbeat_ms = 5000
heartbeat_miss_limit = 3
lease_ttl_ms = 30000
max_inflight_control = 16
control_timeout_ms = 10000

[placement]
prefer = ["local", "pc2"]
max_loaded_models = 0                 # tope de modelos cargados a la vez POR NODO (0 = sin tope por conteo; solo memoria). Aplica además del ledger

[[decision_models]]                   # ver DecisionSpec en §6.11
id = "router_pref"
kind = "preference_router"
model = "arch_router"                 # alias en [[models]]
max_input_tokens = 2048
max_output_tokens = 32
resident = true
require_eval = true
[decision_models.eval]
corpus = "eval/router.jsonl"
adversarial_corpus = "eval/router_adv.jsonl"
required_languages = ["es", "en"]     # OBLIGATORIO si require_eval; ejemplo
confidence = 0.95
# min_top1_accuracy = 0.0             # opcional: suelo absoluto adicional
# max_p99_ms = 1500                   # opcional; defecto router.llm_timeout_ms
[decision_models.routes.code]
description = "..."
models = ["qwen_27b"]

[[rules]]
name = "privado"
when = { contains = "privado" }
action = "veto"
target = { locality = "cloud" }

[providers.llamacpp]
module = "Gunther.Provider.LlamaCpp"
mode = "managed_local"                 # managed_local | managed_node | external
# base_url = "http://127.0.0.1:8080"  # solo external

[providers.openai]
module = "Gunther.Provider.OpenAI"
base_url = "https://api.openai.com/v1"
api_key_env = "OPENAI_API_KEY"
rpm = 0
tpm = 0

[structured]
mode = "auto"                         # auto | native | prompt
max_retries = 2
feedback_bytes = 2048

[stream]
pre_commit_buffer_chunks = 16
max_buffered_chunks = 64
cancel_grace_ms = 1000

[context]
max_prompt_tokens = 0                 # 0 = el context_window del modelo
compaction = "truncate"
summary_model = ""

[sessions]
max_sessions = 1024
idle_ttl_seconds = 3600
max_turns_in_memory = 200
store = "memory"                      # memory | disk

[memory]
max_entries = 10000

[selector]
max_states = 10000
aging_step_ms = 1000                  # envejecimiento: peso efectivo = priority + espera_ms / aging_step_ms (división entera, D-87)

[consumers.default]                   # D-87
default_model = "qwen_27b"            # OBLIGATORIO; alias del catálogo
priority = 0                          # opcional; peso del Selector
# Reglas por consumer (M-01, Q-15). Solo se aplican a este consumer.
# Precedencia: los vetos se acumulan; despues force de consumer > force global > prefer de consumer > prefer global > default_model (§6.8.1).
# Sin `when`, la regla aplica siempre. `when` es opcional.
# [[consumers.default.rules]]
# name = "privado_solo_local"        # único en el espacio combinado con [[rules]] globales
# when = { contains = "privado" }
# action = "veto"                    # veto | force | prefer
# target = { locality = "cloud" }
# weight = 0.0                        # solo con action = "prefer"

[cache]
sweep_interval_ms = 30000

[tools]                               # sección de seguridad: clave desconocida = error
max_result_bytes = 65536
truncate_passes = 32
max_parallel = 4
max_schema_bytes = 16384
max_description_bytes = 2048
default_permission_local = "auto"
default_permission_mcp = "confirm"
auto_approve = []
permissions = [ { pattern = "*__delete_*", permission = "deny" } ]

[mcp]                                 # sección de seguridad: clave desconocida = error
compat_2025_11_25 = false
max_sessions = 256
session_ttl_seconds = 900
max_message_bytes = 4194304
rpc_timeout_ms = 30000
ping_interval_ms = 60000
reconnect_attempts = 5

[[mcp.clients]]
id = "docs"
transport = "stdio"                   # stdio | http
command = "docs-server"               # nombre de [commands].allow (solo stdio)
args = []
# url = "https://mcp.example.org/mcp" # solo http
allow_private = false                 # §9.3

[agents]
max_agents = 64
max_depth = 3
confirm_timeout_ms = 3600000

[rag]
max_document_bytes = 10485760
max_chunks_per_document = 5000
rrf_k = 60
strategy = "hybrid"                   # :vector | :lexical | :hybrid | :multi_query (D-36)
tool_enabled = true                   # registra rag_query (§8.8)
store = "sqlite"                      # memory | sqlite | postgres; defecto de uso real: sqlite
store_backend = "separate"            # v1: solo separate (§8.9)
[rag.sqlite]
# path = "/var/lib/gunther/rag.db"    # obligatorio si store = "sqlite"

[embedders.local]
module = "MyApp.Embedder"
min_score = 0.0                       # defecto 0.0 (sin umbral); calibrar con Doctor.calibrate_rag/2

[guardrails]
timeout_ms = 2000
on_error = "closed"                   # closed | open
pre_send = false
stream_mode = "buffered"              # buffered | post_hoc; OBLIGATORIO si hay guardrails de output

[budget]
max_cost_per_request = 0              # micro-dólares; 0 = sin tope

[gateway]                             # sección de seguridad: clave desconocida = error
max_body_bytes = 1048576
max_headers_bytes = 16384
max_connections = 1024
# max_attachment_body_bytes          # derivado por la fórmula de §12.2; solo se declara para sustituirlo
request_timeout_ms = 120000
allow_plaintext_remote = false

[security]                            # sección de seguridad: clave desconocida = error
persist_hmac_key_env = ""             # variable con la clave de HMAC de lo persistido
persist_encrypt = false

[telemetry]
prefix = ["gunther"]
```

### 14.2 Validación

- **Claves desconocidas (D-26 con excepción, CE-H11)**: aviso, salvo en las secciones `[commands]`, `[nodes]`, `[tools]`, `[mcp]`, `[gateway]`, `[security]`, `[coral]` y `[[consumers.<id>.rules]]`, donde es **error**: una errata en `allow_private`, en un permiso o en una regla de consumer no puede degradarse a un aviso.
- **Validaciones cruzadas** (cada una es `config_error`):

| Regla                                                                                                                           |                                        |
| ------------------------------------------------------------------------------------------------------------------------------- | -------------------------------------- |
| `decision_models.*.eval.max_p99_ms ≤ router.llm_timeout_ms`                                                                     | Coherencia de §6.11                    |
| `eval.required_languages` presente y no vacío si `require_eval`                                                                 | Sin defecto                            |
| `consumers.*.default_model` presente y alias existente del catálogo                                                             | D-87                                   |
| **`[[consumers.<id>.rules]]` con `name` único en el espacio combinado con `[[rules]]`**                                         | M-01, CE-34                            |
| **`[[consumers.<id>.rules]]` con `action = "veto"` y sin `when`, cuyo `target` casa con el `default_model` del mismo consumer** | M-01, §6.8.1                           |
| `rag.store = "sqlite"` exige `rag.sqlite.path`; `rag.store_backend = "shared"` es `config_error` en v1                          | §8.9                                   |
| `max_attachment_bytes.image` y `.audio` mayores que 0                                                                           | D-34                                   |
| `devices.map` presente si hay más de un device físico visible o más de un backend                                               | §11.8                                  |
| `max_mib` y `reserve_mib` presentes **y mayores que 0** en todo device `unified`                                                | §11.8                                  |
| `devices.overhead_mib.<backend>` presente en todo device que use la convención B                                                | §11.3                                  |
| `nodes[].url` empieza por `https://` y existe `pinned_server_cert_sha256`                                                       | §18.4                                  |
| Un `[[models]]` con `node` no lleva `path`                                                                                      | El perfil del nodo fija la ruta (D-67) |
| `gateway` fuera de loopback sin `auth` y TLS                                                                                    | §12.2                                  |
| Cada `command` de `[[engines]]` figura en `commands.allow`                                                                      | §3.4                                   |
| `guardrails.stream_mode` presente si hay guardrails de output                                                                   | §16.2                                  |
| `max_concurrency` de un modelo ≥ 1                                                                                              | Es el valor de `--parallel` (§11.1)    |

### 14.3 Secretos

Las claves salen del entorno (`api_key_env`, `Apero.Env.fetch!/1`). Ninguna clave vive en el TOML. `.env` solo con `gunther.dotenv = true` (CE-17). Los certificados y claves de mTLS se leen de ficheros con permisos que `Doctor` comprueba (la clave privada no debe ser legible por otros usuarios).

### 14.4 Recarga en caliente

`Trebejo.File` vigila `gunther.toml` (opcional). `Config.Server` valida el fichero nuevo entero; si falla, **se conserva el snapshot anterior**. Si pasa, intercambia de forma atómica.

| Recargable sin reinicio                                                                                                                                                                                                                                                                                                                                                                                                                     | Requiere reinicio                                                                                                                                                                                                     |
| ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `[router]`, `[[rules]]`, `[[consumers.*.rules]]`, `[[models]]` (alta, baja, cambios), `[[decision_models]]`, `[providers.*]`, `[retry]`, `[circuit_breaker]`, `[refusal]`, `[budget]`, `[tools]`, `[placement]`, `[structured]`, `[stream]`, `[sessions]` (límites), `[memory]`, `[selector]`, `[consumers.*]` (sin reglas), `[context]`, `[guardrails]`, `[rag]` (salvo `store` y `store_backend`), `[embedders.*]`, `[agents]`, `[cache]` | `[gunther]`, `[commands]`, `[[engines]]`, `[devices]`, `[security]`, `[gateway]` (bind, TLS), `[[nodes]]` (certificados), `[telemetry]`, `[mcp]`, `[coral]`, `[sessions].store`, `[rag].store`, `[rag].store_backend` |

Un modelo eliminado en la config nueva se **drena** (sin peticiones nuevas) y se detiene. Los cambios en un `DecisionSpec` devuelven su estado a `:unverified` (§6.11). Los cambios en `[[consumers.*.rules]]` invalidan la caché de decisiones (§6.5).

### 14.5 Configuración de la coral

Ver §22.17 (`[coral]`, `[coral.dispatch]`, `[context]`, `[context.switch]`, `[eval]`) y §14.1 (`router.affinity`).

---

## 15 · Modelo de amenazas \[D-60\]

### 15.1 Activos, actores y fronteras

**Activos**: claves de API de providers; claves y certificados del gateway y de nodos; contenido de prompts, sesiones y memoria; el catálogo y las reglas (incluidas las de privacidad, tanto globales como de consumer); la GPU y su memoria (recurso escaso); la integridad de lo persistido; el host del controlador y el de cada nodo.

**Actores**: cliente legítimo del gateway; cliente sin credenciales; autor de un documento indexado (RAG); servidor MCP remoto comprometido; autor de un prompt malicioso; proceso local no privilegiado del mismo host; atacante en la red local con acceso TCP a un nodo.

**Fronteras de confianza**: (1) red ↔ gateway; (2) prompt del usuario ↔ modelo; (3) contenido recuperado, resultados de tools y MCP ↔ prompt; (4) controlador ↔ nodo; (5) VM ↔ procesos hijos; (6) disco ↔ VM.

### 15.2 Amenazas y controles

| #    | Amenaza                                                                                         | Controles                                                                                                                                                                                                                                                                                                                                                                                                                   | Test                                                                                                             |
| ---- | ----------------------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------- |
| T-01 | **Inyección indirecta** por contenido de RAG, resultados de tools o MCP                         | Delimitado y marca `untrusted` (§7.3). **El delimitado reduce el riesgo y no es una frontera de seguridad**: la frontera real son los permisos de tools (§9.3: lo importado de MCP es `:confirm` por defecto), la confirmación humana, los guardrails de output, y que el modelo de decisión no ve ese contenido (§6.12 M2)                                                                                                 | Corpus de inyección en F10; tool `:confirm` no se ejecuta sin aprobación                                         |
| T-02 | **Redirección del router** por secuencias añadidas al prompt \[V\]                              | §6.12 M1 a M7                                                                                                                                                                                                                                                                                                                                                                                                               | Corpus adversario obligatorio (§6.11)                                                                            |
| T-03 | **SSRF** desde el cliente MCP o el RAG                                                          | §9.3: sin redirecciones, IP validada y fijada, rangos rechazados, reconexión revalidada                                                                                                                                                                                                                                                                                                                                     | Tests con resolver falso (incluidos 302 a metadatos y DNS con varias IP)                                         |
| T-04 | **Inyección de comandos** o argumentos hostiles al engine                                       | Ningún dato del usuario ni del modelo llega a un comando (§3.4); `ArgsBuilder` sin líneas libres; lista de permitidos con `realpath` e inodo fijados; flags prohibidos en código                                                                                                                                                                                                                                            | Grep en CI; tests de `ArgsBuilder` con entradas hostiles                                                         |
| T-05 | **Fuga de secretos** (logs, telemetría, `inspect`, trazas)                                      | §13.1 reglas de contenido; `Inspect` con `except:`; claves por entorno; `.env` desactivado por defecto; claves del engine por variable de entorno, no argv (§11.1)                                                                                                                                                                                                                                                          | Test que busca la clave en logs y eventos de una petición completa                                               |
| T-06 | **Acceso no autorizado al gateway**                                                             | §12.2: loopback por defecto; fuera de loopback exige clave y TLS; solo `sha256` de claves en config; comparación de tiempo constante; límites por clave                                                                                                                                                                                                                                                                     | Tests de arranque inválido; fuzz de cabeceras                                                                    |
| T-07 | **Plano de control de nodo comprometido o suplantado**                                          | §18.4: mTLS con huella fijada en ambos sentidos, TLS 1.3, perfiles definidos en el nodo (el controlador no envía comandos ni rutas), límites en el nodo, registro de auditoría en el nodo                                                                                                                                                                                                                                   | Tests con certificado distinto, huella incorrecta, parámetros fuera de límites                                   |
| T-08 | **Servidor RPC de llama.cpp expuesto**                                                          | **Excluido** (D-66): el RPC de llama.cpp no tiene autenticación incorporada y se han publicado ejecuciones remotas de código contra él (CVE-2026-34159, CVE-2026-39909) \[V\]. Gunther no pasa `--rpc` y descarta devices `RPC` (§11.7)                                                                                                                                                                                     | Test que falla si el `ArgsBuilder` emite `--rpc`                                                                 |
| T-09 | **`llama-server` accesible desde la red**                                                       | Engines locales: `--host 127.0.0.1` y clave por engine. Engines de nodo: loopback del nodo; el único acceso es el proxy mTLS (§18.3)                                                                                                                                                                                                                                                                                        | Test de bind y de acceso sin clave                                                                               |
| T-10 | **Servidor MCP malicioso** (mensajes enormes, descripciones con instrucciones, tools homónimas) | `mcp.max_message_bytes`; descripciones truncadas y marcadas no confiables (CE-22); prefijo de espacio de nombres; permisos `:confirm`                                                                                                                                                                                                                                                                                       | Fuzz de framing JSON-RPC                                                                                         |
| T-11 | **Denegación de servicio**                                                                      | Límites de cuerpo, conexiones y en vuelo (§2.6, §12.2); `match_limit` en regex (§6.8); `max_output_tokens` del decisor; topes en toda ETS y cola (§17)                                                                                                                                                                                                                                                                      | Pruebas de carga                                                                                                 |
| T-12 | **Manipulación de lo persistido** (sesiones, agentes, `engines.json`)                           | `binary_to_term(_, [:safe])`; HMAC con clave de entorno (`security.persist_hmac_key_env`); cifrado opcional (`Apero.Crypto`, AES-256-GCM \[V5\]); escritura atómica                                                                                                                                                                                                                                                         | Test que altera un byte y exige rechazo                                                                          |
| T-13 | **Cadena de suministro**                                                                        | Dependencias fijadas por `mix.lock`; `mix hex.audit` en CI; herramienta de auditoría de vulnerabilidades de dependencias a evaluar en G-23; las hermanas con versión mínima                                                                                                                                                                                                                                                 | CI                                                                                                               |
| T-14 | **Fichero de modelo malicioso o binario de engine vulnerable**                                  | Se han publicado vulnerabilidades de ejecución de código en `llama.cpp` por GGUF manipulado \[V\]. Controles: los modelos solo se cargan desde rutas de la config del operador (o del perfil del nodo), con `sha256` opcional verificado antes de cargar; el parser de GGUF propio acota toda lectura y se somete a fuzz; **`[[engines]].min_build`**: `Doctor` falla si `llama-server --version` informa una versión menor | Fuzz del parser; test de `min_build`                                                                             |
| T-15 | **Cruce entre consumers**                                                                       | Memoria y **sesiones** con espacio de nombres por consumer (CE-30); la clave de API fija el consumer (§12.2); la clave de caché incluye el consumer (§6.5); **las reglas de un consumer no pueden vetar candidatos de otro consumer** (M-01, §6.8.1)                                                                                                                                                                        | Test de aislamiento: dos consumers con reglas propias que comparten `default_model` no se ven afectados entre sí |
| T-16 | **Inyección en logs**                                                                           | Logs estructurados; los valores de usuario van como metadatos, no concatenados al mensaje                                                                                                                                                                                                                                                                                                                                   | Test                                                                                                             |
| T-25 | **Plantilla de prompt de origen no confiable** (EEx evalúa código de Elixir)                    | Solo el operador escribe plantillas (`Prompt.register/3` es API del operador y ningún endpoint la expone); el contenido de usuario entra siempre como valor de un `assign`, nunca concatenado en el texto de una plantilla antes de compilarla (D-38)                                                                                                                                                                       | Prueba: ningún endpoint registra plantillas                                                                      |

Las amenazas de la coral (T-17 a T-24) están en §22.16.

### 15.3 Fuera de alcance

Defensa frente a un atacante con ejecución de código en el host del controlador o de un nodo; defensa frente a un proveedor cloud malicioso; garantías de que un modelo no obedezca instrucciones inyectadas (T-01 reduce el riesgo y no lo elimina).

---

## 16 · Guardrails y evaluación

### 16.1 Guardrails de input

Se aplican a los mensajes de autoría del caller **antes** de añadir contexto (§7.3). `{:veto, reason}` devuelve `:guardrail_input_veto`; `{:modify, new}` sustituye el contenido y añade el warning `:guardrail_modified`.

### 16.2 Guardrails de output \[CE-31\]

| Situación                                        | Comportamiento                                                                                                                                                                                                       |
| ------------------------------------------------ | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Sin streaming                                    | Se aplican al contenido final antes de devolverlo                                                                                                                                                                    |
| Con streaming y guardrails de output registrados | `guardrails.stream_mode` es **obligatorio** (sin defecto)                                                                                                                                                            |
| `stream_mode = "buffered"`                       | Los chunks se retienen hasta completar la respuesta, se comprueba y se liberan o se vetan. No hay beneficio de latencia de streaming; está documentado                                                               |
| `stream_mode = "post_hoc"`                       | Los chunks pasan; la comprobación es al terminar. Un veto no puede retirar lo ya entregado: devuelve `{:error, :guardrail_output_veto}` y emite `[:gunther, :guardrail, :veto]`; el gateway envía un evento de error |

Límites de ejecución: `guardrails.timeout_ms` (2000) por guardrail; fallo o vencimiento según `guardrails.on_error` (defecto `"closed"`: se trata como veto con `:guardrail_error`; `"open"` deja pasar con warning).

### 16.3 Evaluación como contrato (D-39)

`Gunther.Eval.run(spec, opts)` ejecuta un corpus y devuelve un informe reproducible.

**Formato del corpus** (JSONL, una línea por caso):

| Corpus | Campos                                                                                                              |
| ------ | ------------------------------------------------------------------------------------------------------------------- |
| Router | `id`, `messages`, `lang` (código de idioma), `expected_route` o `expected_models`, `tags`, `adversarial` (booleano) |
| RAG    | `id`, `query`, `relevant_ids`                                                                                       |

**Métricas** (definiciones exactas):

| Métrica                     | Definición                                                                                                      |
| --------------------------- | --------------------------------------------------------------------------------------------------------------- |
| `top1_accuracy`             | Fracción de casos cuyo primer elemento del ranking pertenece a `expected_*`; se informa **global y por `lang`** |
| `top3_accuracy`             | Ídem con los tres primeros                                                                                      |
| `abstain_rate`              | Fracción de casos en que el decisor se abstiene                                                                 |
| `adversarial_drop`          | `top1_accuracy(no adversarios) − top1_accuracy(adversarios)`                                                    |
| Percentil `q` de latencia   | **Rango más próximo**: el valor en la posición `ceil(q · n)` de la lista ordenada de `n` muestras               |
| `recall@k`, `MRR`, `nDCG@k` | Definiciones estándar de recuperación sobre `relevant_ids`                                                      |

**Reproducibilidad**: `temperature = 0`, `seed` fijo, hash del fichero del modelo y de la configuración en el informe. El informe se escribe de forma atómica en `<state_dir>/eval/<report_id>.json`. `tolerance` es la diferencia máxima admitida entre un informe y su referencia.

### 16.4 Construcción del corpus \[D-72\]

El corpus lo construye el operador con herramientas de Gunther; no hace falta tenerlo hecho de antemano. Cada caso lleva `source` (`real | synthetic`) y `label_source` (`human | llm_judge`), y los informes los separan.

| Fuente       | Herramienta                                                                                                                                                                                 | Reglas                                                                              |
| ------------ | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------- |
| Tráfico real | `router.capture` (**desactivado por defecto**): guarda localmente, en `<state_dir>/capture/` y con cifrado opcional, la `DecisionView` y la decisión tomada, con tope `capture.max_entries` | Es contenido de usuarios: nunca sale del host; sin etiqueta no sirve para verificar |
| Etiquetado   | `Gunther.Eval.Corpus.label/2` sobre los casos capturados o escritos a mano (JSONL)                                                                                                          | Solo `label_source: :human` cuenta para verificar                                   |
| Sintético    | `Gunther.Eval.Corpus.synthesize(spec, provider, languages, per_route)`: genera casos con **cualquier** provider registrado                                                                  | `source: :synthetic`; no basta por sí solo                                          |
| Adversario   | `Gunther.Eval.Corpus.adversarial(corpus, kinds)`: transformaciones deterministas (prefijos y sufijos añadidos, mezcla de idiomas, ruido, instrucciones incrustadas) con semilla             | Se marcan `adversarial: true`                                                       |

**Verificación solo con datos sintéticos**: el estado resultante es `:verified_synthetic` y **solo activa** el decisor si `router.allow_synthetic_verification = true` (defecto `false`); `Doctor` emite `:warn`. Con casos reales etiquetados por una persona, el estado es `:verified`.

---

## 17 · Requisitos no funcionales

Cada requisito tiene un método de verificación. Los **umbrales** son parámetros del dueño (§21, ya ratificados en DP0); los valores de la tabla son la **propuesta inicial** aprobada, no una predicción del comportamiento.

| #    | Requisito                                                                                                            | Verificación                                                                                                                                                | Umbral                                           |
| ---- | -------------------------------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------ |
| N-01 | Sobrecoste de Gunther en el camino no LLM (caché, pin, reglas, ranking), sin contar al provider                      | Benchmark de `route/2` con el corpus de §16.3, 100 llamadas concurrentes, p99 por rango más próximo                                                         | 5 ms                                             |
| N-02 | **Toda tabla ETS, caché, cola y buffer tiene un tope declarado** y un comportamiento al llenarse                     | Revisión de código con lista en CI (`max_*` por estructura) y test de saturación                                                                            | 100 % de las estructuras                         |
| N-03 | **Todo proceso está supervisado**                                                                                    | Test que recorre el árbol y falla ante procesos huérfanos tras una petición y su cancelación                                                                | 0 procesos huérfanos                             |
| N-04 | **Toda espera tiene timeout**                                                                                        | Grep de `receive`, `GenServer.call` y `Task.await` sin plazo; test de plazo total (§2.5)                                                                    | 0 esperas sin plazo                              |
| N-05 | Degradación controlada: caída de un provider, engine o nodo no tumba el resto                                        | Pruebas de caos: matar engine, cortar nodo, provider lento                                                                                                  | Las peticiones a otros destinos siguen con éxito |
| N-06 | Fallo seguro: ante duda de medición, el device no se usa                                                             | Tests de §11.3 y §11.8                                                                                                                                      | 0 colocaciones en devices `usable: false`        |
| N-07 | Sobrecoste del proxy de nodo hasta el primer chunk, comparado con acceso directo al engine en la misma red           | Benchmark en F15 con la misma carga por ambos caminos, p95                                                                                                  | 25 ms                                            |
| N-08 | Fuga de secretos nula                                                                                                | Test de T-05                                                                                                                                                | 0 ocurrencias                                    |
| N-09 | Documento sin afirmaciones no verificadas                                                                            | Lint de §0.6                                                                                                                                                | 0 coincidencias                                  |
| N-10 | Cobertura de pruebas                                                                                                 | Tests de propiedades (ledger, caché, reparto), de contrato (todos los behaviours), de fuzz (parser GGUF, framing JSON-RPC, TOML, regex), de caos y de carga | Todos presentes y verdes en F16                  |
| N-11 | Compatibilidad                                                                                                       | CI en el toolchain del proyecto: OTP 28.5.0.7 sobre Elixir 1.19.5-otp-28                                                                                    | Verde                                           |
| N-12 | Observabilidad completa                                                                                              | Un test comprueba que cada evento de §13.1 se emite en su escenario                                                                                         | 100 %                                            |
| N-13 | Arranque limpio tras `kill -9` de la VM                                                                              | Test de F6: reconciliación (§2.8) sin VRAM fantasma                                                                                                         | 0 MiB retenidos                                  |
| N-14 | Limpieza tras abandonar un `stream!`                                                                                 | Invariante de §2.9                                                                                                                                          | 0 procesos tras `stream.cancel_grace_ms`         |
| N-15 | Sobrecoste de `Coral.Run` por paso (despacho, pizarra, mensajería), sin contar modelos ni tools                      | Benchmark de F18 con 100 ejecuciones concurrentes, p99 por rango más próximo                                                                                | **50 ms p99** (M-02, Q-09)                       |
| N-16 | Toda estructura de la coral tiene tope y comportamiento al llenarse (pizarra, buzones, mensajes, pasos, ejecuciones) | Test de saturación por estructura                                                                                                                           | 100 %                                            |
| N-17 | Gunther no crea átomos a partir de entrada externa                                                                   | Grep de `String.to_atom`/`:erlang.binary_to_atom` sobre datos externos y prueba con identificadores aleatorios                                              | 0 ocurrencias                                    |
| N-18 | Reanudación correcta: ningún efecto `:unsafe` se repite                                                              | Pruebas de caída entre intención y resultado                                                                                                                | 0 repeticiones                                   |

---

## 18 · Nodos remotos: el provider «mixto» \[D-66, D-67\]

**Requisito del dueño**: con dos PC, uno con un engine local, gestionar ese engine desde el otro como si fuera interno, aunque técnicamente sea un provider externo. Es un provider **mixto**: ubicación externa, gestión interna (reserva, arranque, parada, descarga por inactividad, ledger, refusal).

### 18.1 Estudio de alternativas

| Criterio                             | A. Distribución de Erlang                                                                      | B. Backend RPC de llama.cpp                                                         | C. SSH + comandos                                     | **D. Agente de nodo propio (HTTPS + mTLS)**                        | E. Externo sin gestión |
| ------------------------------------ | ---------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------- | ----------------------------------------------------- | ------------------------------------------------------------------ | ---------------------- |
| Qué resuelve                         | Llamar funciones en otro nodo BEAM                                                             | Repartir **tensores de un modelo** entre máquinas                                   | Ejecutar comandos en otro host                        | Gestionar engines completos en otro host                           | Solo llamar a una URL  |
| Autenticación                        | Cookie compartida; TLS opcional                                                                | **Sin autenticación incorporada** \[V\]                                             | SSH                                                   | **mTLS con huella fijada**                                         | Clave de API           |
| Qué puede hacer quien se conecta     | Ejecutar código arbitrario en el otro nodo (propiedad de la distribución; se confirma en G-19) | Leer y escribir memoria del proceso: **ejecución remota de código publicada** \[V\] | Ejecutar **lo que el controlador envíe** (viola D-67) | **Solo** operaciones del contrato de §18.3 sobre perfiles del nodo | Llamar al engine       |
| Acoplamiento de versiones            | OTP y Elixir iguales                                                                           | Compilación igual de llama.cpp                                                      | Ninguno                                               | `node_api` versionada (§18.3)                                      | Ninguno                |
| Ledger autoritativo en el nodo       | Posible                                                                                        | No                                                                                  | No                                                    | **Sí**                                                             | No                     |
| Gestión (arrancar, parar, descargar) | Sí                                                                                             | No                                                                                  | Sí, con comandos libres                               | **Sí, con perfiles**                                               | **No**                 |
| Streaming de datos                   | Mensajes de Erlang                                                                             | Propio                                                                              | Túnel                                                 | HTTP/SSE mediado por el agente                                     | Directo                |
| Portabilidad                         | Solo BEAM                                                                                      | Backends de llama.cpp                                                               | Cualquier SO con SSH                                  | Linux, macOS, WSL2 (§0.3)                                          | Cualquiera             |
| Dependencias de Gunther              | Ninguna extra                                                                                  | Ninguna                                                                             | `Trebejo.SSH` (fuera de alcance, §3.4)                | `plug`, `bandit` en el nodo                                        | Ninguna                |

**Decisión**: **D**. A concede demasiado a un nodo comprometido, B queda excluida por seguridad \[V\] y resuelve otro problema, C obliga a que el controlador envíe comandos, y E es el modo mínimo y ya está soportado como `external` (§5.1) para quien no quiera gestión. **El reparto de tensores entre máquinas queda fuera de v1.**

### 18.2 Roles y topología

| Rol             | Qué es                                   | Qué corre                                                                                                                                                                    |
| --------------- | ---------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **Controlador** | La aplicación con Gunther completo (PC1) | Router, catálogo, ledger espejo, `Node.Connection` por nodo, `Backend.Remote`                                                                                                |
| **Nodo**        | El PC con la GPU (PC2)                   | `Gunther.Node.Agent`: `Detector`, **ledger autoritativo**, `Engine.Supervisor` local, API de control, proxy de datos, reaper. **No tiene router, catálogo, sesiones ni RAG** |

Un controlador puede gestionar **varios nodos**; un nodo puede ser gestionado por **varios controladores** (el ledger del nodo arbitra, §18.5). El agente de nodo se arranca como una aplicación mínima (`Gunther.Node.start_link/1`, release aparte); es el mismo paquete (D-49), opcional.

### 18.3 API de control (`/gunther/node/v1`)

HTTPS con **TLS 1.3 y mTLS**. Cabecera `X-Gunther-Node-Api: 1` en toda petición; un desajuste de versión mayor devuelve `:node_protocol_error`. Cuerpos JSON.

| Método y ruta                       | Qué hace                                                                                                                                                                                                   |
| ----------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `GET /hello`                        | `node_id`, `node_api`, versión de Gunther, SO, arquitectura, backends disponibles, ids de perfiles. Informativo: `clock_unix_ms` (no se usa para decidir nada, §18.8)                                      |
| `GET /devices`                      | Devices del nodo con `physical_id`, `kind`, capacidad, `free`, atribución, `usable` y `reason` (la medida la hace el `Detector` del nodo, §11.7)                                                           |
| `POST /fit`                         | `{profile, overrides}` → `{reserved_mib, method, per_device}`; método de §11.5                                                                                                                             |
| `POST /leases`                      | `{holder, device, mib, ttl_ms}` → `{lease_id, expires_in_ms}` o 409 `no_room`. **Reserva de capacidad en el ledger del nodo**                                                                              |
| `POST /leases/{id}/renew`           | Renueva el TTL                                                                                                                                                                                             |
| `DELETE /leases/{id}`               | Libera (detiene el engine asociado, §18.5)                                                                                                                                                                 |
| `POST /engines`                     | `{profile, alias, lease_id, overrides}` → `{engine_id, state}`                                                                                                                                             |
| `GET /engines`, `GET /engines/{id}` | Estado                                                                                                                                                                                                     |
| `DELETE /engines/{id}?grace_ms=`    | Parada con SIGTERM y escalada                                                                                                                                                                              |
| `GET /engines/{id}/logs?tail=n`     | Anillo de logs (§3.4)                                                                                                                                                                                      |
| `GET /events`                       | SSE: cambios de device, engine y lease; latido                                                                                                                                                             |
| `ANY /engines/{id}/proxy/*`         | **Plano de datos**: proxy al `llama-server` del engine, solo hacia una lista de rutas permitidas (G-12: `/v1/chat/completions`, `/v1/completions`, `/v1/embeddings`, `/tokenize`, `/v1/models`, `/health`) |

**18.3.1 Cuerpos** \[CE-33\]. JSON; todas las duraciones en ms; los identificadores de `holder` tienen la forma `gunther:<instancia>:<alias>` (instancia `[a-z0-9_-]{1,32}`, validada por el nodo).

| Operación                 | Petición                                        | Respuesta                                                                                                                        |
| ------------------------- | ----------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------- |
| `GET /hello`              | —                                               | `{"node_id","node_api","gunther_version","os","arch","backends":[...],"profiles":[...],"clock_unix_ms"}`                         |
| `GET /devices`            | —                                               | `{"devices":[{"physical_id","name","backend","backend_name","kind","capacity_mib","free_mib","attribution","usable","reason"}]}` |
| `POST /fit`               | `{"profile","overrides":{}}`                    | `{"reserved_mib","method":"fit\|formula\|declared","per_device":[{"physical_id","mib"}]}`                                        |
| `POST /leases`            | `{"holder","device","mib","ttl_ms"}`            | 201 `{"lease_id","expires_in_ms"}`                                                                                               |
| `POST /leases/{id}/renew` | `{"ttl_ms"}`                                    | `{"expires_in_ms"}`                                                                                                              |
| `POST /engines`           | `{"profile","alias","lease_id","overrides":{}}` | 202 `{"engine_id","state"}`                                                                                                      |
| `GET /engines/{id}`       | —                                               | `{"engine_id","alias","state","device","reserved_mib","lease_id"}`                                                               |
| `GET /events`             | —                                               | SSE: `event: device\|engine\|lease\|heartbeat`, `data:` JSON con el mismo esquema que arriba                                     |

**Errores**: `{"error":{"code","message","details":{}}}` con 400 `invalid_request`, 403 `forbidden` (override o perfil no permitido), 404 `not_found`, 409 `no_room` (con `details: {requested_mib, available_mib, capacity_mib}`, §6.9), 429 `rate_limited`, 503 `overloaded`. Un fallo de autenticación mutua se corta en TLS y no produce respuesta HTTP.

**Plano de datos mediado (D-66)**: el engine del nodo escucha **solo en loopback del nodo** (§11.1); el agente de nodo es el único proceso que acepta conexiones de red, con mTLS, y reenvía a `127.0.0.1:<puerto>` añadiendo la clave de API del engine, que el controlador **nunca ve**. Se elige esto frente a exponer `llama-server` con sus propias opciones de TLS porque (a) hay una sola superficie de red y una sola pila TLS que auditar, (b) los endpoints de administración del engine no son alcanzables, y (c) no depende de que el binario esté compilado con soporte TLS. El coste es un salto adicional dentro del nodo, acotado por N-07. Que el proxy no almacena en búfer el streaming SSE de extremo a extremo se comprueba en G-20.

### 18.4 Seguridad y perfiles \[D-67\]

**Autenticación mutua**: el nodo presenta un certificado de servidor y el controlador un certificado de cliente. Cada lado **fija la huella SHA-256** del certificado del otro: el controlador la lleva en `[[nodes]].pinned_server_cert_sha256` y el nodo la lista en `allowed_clients`. **Formato de toda huella: hex en minúsculas, sin separadores, del SHA-256 del certificado en DER** (`openssl x509 -fingerprint -sha256` imprime en mayúsculas y con `:`; hay que normalizarla). No hay autenticación por token como alternativa. **Rotación**: ambos lados admiten **una lista** de huellas, de modo que se añade la huella del certificado nuevo, se cambia el certificado y se retira la antigua sin cortar el servicio. Se usa **huella fijada sobre certificados propios, sin autoridad certificadora (D-66)**: no hay una CA cuya clave pueda comprometerse ni infraestructura de revocación que mantener; la revocación es quitar la huella de la lista. `Doctor` avisa de certificados que caducan (`nodes.cert_expiry_warn_days`, 30). Una CA propia queda como modo opcional posterior. La verificación por huella con `:ssl` y su uso desde `Finch` y `Bandit` es G-19.

**Perfiles de engine, definidos en el nodo**. El controlador **no envía** líneas de comando, rutas de modelo ni variables de entorno: referencia un `profile` por id y puede pasar solo los `overrides` que el perfil permita. Configuración del nodo (`gunther_node.toml`):

```toml
[node]
id = "pc2"                              # obligatorio
bind = "192.168.1.20"                   # obligatorio; sin defecto
port = 7443
server_cert_file = "/etc/gunther/pc2.crt"   # TLS se activa si ambos ficheros están presentes y son legibles;
server_key_file = "/etc/gunther/pc2.key"    # sin ellos el nodo solo acepta loopback
allowed_clients = ["<sha256 del certificado del controlador>"]
state_dir = "/var/lib/gunther-node"
max_engines = 2
max_leases = 8
rate_limit_rpm = 600
lease_grace_ms = 5000

[commands]                              # igual que §3.4
allow = [ { name = "llama-server", path = "/opt/llama.cpp/bin/llama-server", sha256 = "..." } ]

[[profiles]]
id = "qwen-27b-q4"
command = "llama-server"
backend = "cuda"
model_path = "/models/qwen.gguf"
model_sha256 = "..."                    # opcional; verificado antes de cargar
device = "gpu0"                         # physical_id del nodo
ctx_size_max = 32768
parallel_max = 4
env = { CUDA_VISIBLE_DEVICES = "0" }
allowed_overrides = ["ctx_size", "parallel", "kv_type_k", "kv_type_v"]
```

El nodo valida cada override (tipo, rango, `≤` el máximo del perfil) y rechaza todo lo demás. **Reglas del nodo**: no arranca si `bind` es distinto de loopback y no hay TLS configurado (**TLS configurado = `server_cert_file` y `server_key_file` presentes y legibles**); no descarga ni instala modelos ni binarios (§3.4); aplica `max_engines`, `max_leases` y límite de peticiones por cliente; registra una entrada de auditoría por operación (huella del cliente, operación, perfil, resultado) sin contenido de prompts; el `ArgsBuilder` y la lista de permitidos son los de §3.4, **ejecutados en el nodo**.

### 18.5 Leases, fallos y reconciliación

**Lease** = reserva de capacidad en el ledger del nodo con **TTL relativo** (`nodes.lease_ttl_ms`, 30 000). El controlador renueva cada `lease_ttl_ms / 3`. Un engine vive mientras viva su lease; un lease que expira detiene su engine tras `lease_grace_ms` (con SIGTERM y escalada).

| Situación                                                                                       | Comportamiento                                                                                                                                                                                                                              |
| ----------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Latidos perdidos: `nodes.heartbeat_miss_limit` (3) seguidos con intervalo `heartbeat_ms` (5000) | La conexión pasa a `:unreachable`; los devices del nodo en el controlador quedan `usable: false`; sus modelos salen del conjunto elegible con motivo `:node_unreachable` (§6.10)                                                            |
| Petición en vuelo al caer el nodo                                                               | Antes del commit: failover (§2.5). Después: `:stream_interrupted`                                                                                                                                                                           |
| Partición más larga que el TTL                                                                  | El nodo detiene sus engines; al volver, el controlador marca esos engines como `:stopped`                                                                                                                                                   |
| Reconexión                                                                                      | Reintentos con `Apero.Retry`; al conectar: `GET /hello` (identidad y versión), `GET /devices`, `GET /leases`, `GET /engines`; **adopta** solo los registros cuyo `holder` lleve el id de instancia de este controlador; el resto no se toca |
| Reinicio del controlador                                                                        | Vuelve a adoptar si ocurre antes de que venzan los leases; si no, el nodo ya detuvo los engines y se arranca limpio                                                                                                                         |
| Reinicio del agente de nodo                                                                     | Reconcilia con su `engines.json` aplicando exactamente el procedimiento de §2.8 (marca, identidad HTTP)                                                                                                                                     |
| Dos controladores sobre un nodo                                                                 | El ledger del nodo es la autoridad: `POST /leases` falla con `no_room` si el otro controlador ocupa la memoria; ninguno lleva una cuenta propia que pueda divergir                                                                          |
| `Gunther.stop/1`                                                                                | Libera los leases (`DELETE /leases/{id}`). Con `keep_engines: true` **no** los libera: los engines viven hasta que venza el TTL                                                                                                             |

### 18.6 Módulos del controlador

| Módulo                                  | Responsabilidad                                                                                                                                   |
| --------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------- |
| `Gunther.Node.Client`                   | Cliente HTTPS con mTLS y huella fijada (pool `Finch` por nodo, tamaño derivado de la suma de `max_concurrency` de sus modelos), contrato de §18.3 |
| `Gunther.Node.Connection`               | Un proceso por nodo: latidos, suscripción a `/events`, espejo del ledger, estado `:connecting \| :connected \| :unreachable`                      |
| `Gunther.Engine.Backend.Remote`         | `reserve` = `POST /leases`; `start` = `POST /engines`; `health`, `stop`, `measure` hacia el nodo; `endpoint` = URL del proxy de datos             |
| `Provider.LlamaCpp` modo `managed_node` | El mismo provider que el local; solo cambia el `Backend`                                                                                          |

El router, el ledger, el refusal, la descarga por inactividad y el pipeline de resiliencia **no distinguen** entre un engine local y uno de nodo: ésa es la propiedad de «mixto». Los errores propios de nodos son `:node_unreachable`, `:node_auth_failed` y `:node_protocol_error` (§4.13); el breaker del provider cuenta `:node_unreachable` (§2.5).

### 18.7 Colocación entre nodos

El Placer (§11.4) considera los devices de todos los nodos conectados. Orden: `placement.prefer`, después mayor `available`, después `physical_id`. La `locality` de un modelo de nodo es `lan` (§6.8): una regla `veto` sobre `cloud` no lo excluye; una regla sobre `lan` sí.

### 18.8 Tiempo

Los TTL se miden con relojes monotónicos **de cada lado** y viajan como duraciones relativas (`expires_in_ms`). El controlador **nunca compara** su reloj de pared con el del nodo. `clock_unix_ms` de `GET /hello` es solo informativo.

### 18.9 Pruebas

`FakeNode` (en proceso) para pruebas unitarias; integración con **dos nodos BEAM en el mismo host** con mTLS real; pruebas de caos: matar el agente, matar el engine, cortar la red con un proxy que descarta tráfico, certificado equivocado (`:node_auth_failed`), huella incorrecta, overrides fuera de rango, lease caducado con un engine ocupado, dos controladores compitiendo por la misma memoria. AC en F15 (§19).

---

## 19 · Fases y criterios de aceptación

Regla D-10: **una fase se cierra por ejecución real**, no por revisión. Una fase no empieza si no están verdes los AC de la anterior. Los cierres **CE-01, CE-02, CE-05, CE-15, CE-19, CE-20 y CE-34** están **escritos** en el SPEC; cada uno se **verifica por test** en la fase que lo implementa: CE-01 en F3; CE-02 en F7; CE-05 en F6; CE-15 (commit de stream) en F3 y F5 (failover); CE-19 y CE-20 en F1; CE-34 en F4.

| Fase                            | Contenido                                                                                                                                                                                               | AC (todos binarios)                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                   |
| ------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **F0** Verificación             | Las 32 puertas del Anexo C (G-01 a G-31, con G-06b); lint de documento; esqueleto, CI (`mix xref`, grep de fronteras, `mix hex.audit`)                                                                                           | Cada puerta tiene resultado registrado (`PASA`/`FALLA`/`BLOQUEADA con rama B aplicada`) y rama elegida en el ADR; el lint de §0.6 pasa; `mix deps.tree` limpio                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                        |
| **F1** Núcleo                   | Config y validación (§14, incluidas las reglas de consumer), catálogo, registry, errores, `Command` (corto y largo), `Spawner`, `Cache`, `Cancel`, puente de telemetría, `Gunther.Context` (estructura) | Config inválida rechazada, incluida clave desconocida en secciones de seguridad y reglas de consumer; `Command` bloquea comandos fuera de la lista y de `realpath` cambiado; reensamblado de `:noeol` probado con mensajes mayores que el búfer de línea; `Cache` cumple tope y LRU exacto por propiedades                                                                                                                                                                                                                                                                                                                                                                                            |
| **F2** Recursos                 | `Detector` (`LlamaCpp`, `Cpu`, fabricantes), parser GGUF, fórmula de KV, ledger, Placer, `Placement`, `calibrate_overhead/2`                                                                            | Salidas grabadas de `--list-devices` de CUDA, Vulkan, ROCm y Metal analizadas; `free > total` ⇒ `usable: false`; mapeo obligatorio con más de un device; `unified` sin límite ⇒ `device_unusable`; invariantes del ledger por propiedades; para cada modelo de referencia con atención estándar, `kv_mib` de la fórmula = `kv_mib` informado por `llama-server` al cargar; tipos no válidos (MLA, SSM) ⇒ `fit` o `:memory_unknown`; B sin `overhead_mib` ⇒ `:overhead_unknown`                                                                                                                                                                                                                        |
| **F3** Provider                 | Behaviours, `Mock`, `ContractTest`, providers de referencia, salida estructurada (§4.2.1), commit de stream (§2.9), `stream!/2`, `opts.require`, `opts.context`                                         | Un provider sin soporte estructurado nunca devuelve `structured: nil` en `{:ok, _}`; failover antes del commit y `:stream_interrupted` después; `stream!` sin procesos tras `cancel_grace_ms`; matriz G-22 resuelta; adjunto mayor que el límite ⇒ `:invalid_request` con `details.attachment_too_large`                                                                                                                                                                                                                                                                                                                                                                                              |
| **F4** Enrutado                 | Router, reglas (globales y de consumer), caché, ranking, `Classifier` y `DecisionSpec`, `calibrate_router`, harness de evaluación, Borda, `Session.last_call` y `Decision.affinity`                     | Capa `:llm` saltada con `:classifier_unverified` hasta tener informe; informe invalidado por cualquier cambio de modelo, spec o rutas; corpus adversario ejecutado; abstención ante salida inválida; Borda determinista; `DecisionView` nunca contiene contenido de RAG, tools, memoria ni `assistant`. **M-01:** (a) consumer con veto que aplica y sin otro candidato devuelve `:no_candidates` con `:consumer_veto`; (b) veto del consumer gana a `force` global del mismo `target`; (c) `Decision.consumer_rules_applied` y `Decision.global_rules_applied` reflejan qué reglas actuaron; (d) caché invalidada al cambiar `[[consumers.*.rules]]`; (e) nombre de regla duplicado ⇒ `config_error` |
| **F5** Resiliencia y refusal    | Pipeline de §2.5, tabla de errores, refusal, presupuesto, presupuesto jerárquico                                                                                                                        | Cada fila de la tabla de §2.5 tiene un test; plazo total respetado con retries y failovers; presupuesto con coste de entrada y acumulación; suma gastada no supera lo asignado arriba; defecto `wait`; `:refused_capacity` nunca lleva un número que signifique «no se sabe»                                                                                                                                                                                                                                                                                                                                                                                                                          |
| **F6** Ciclo de vida del engine | `Backend.Local`, arranque, salud, descarga por inactividad, reaper, reconciliación, `stop`, estados de la reserva, reintento en otro device                                                             | Tras `kill -9` de la VM no queda VRAM retenida ni se mata un proceso ajeno; un PID reutilizado no recibe señales; cierre manual del engine entre `stop` y `start` detectado; una sola carga con N peticiones simultáneas; un engine que usa más de lo reservado corrige la reserva y emite `:reserve_exceeded`                                                                                                                                                                                                                                                                                                                                                                                        |
| **F7** Tools y servidor MCP     | Registro, bucle de tools, permisos, confirmación, truncado, `side_effects`, servidor MCP 2026-07-28 y modo compatible                                                                                   | `:confirm` en `chat/2` devuelve `:tool_confirmation_required`; en agente, `[:tool, :confirm_required]` y `:wait_human`; el truncado siempre produce JSON válido; modo 2026-07-28 sin estado de sesión; modo compatible con tope de sesiones                                                                                                                                                                                                                                                                                                                                                                                                                                                           |
| **F8** Contexto                 | Sesiones, memoria, compactación, contadores de tokens, `Session.last_call`, `Memory` con autor y versión                                                                                                | `Session.open/2` reabre desde el store; sin calibración, `approximate` no disponible; nunca se parte un par `tool_call`/`tool_result`; `put/3` con `if_version:` desactualizada ⇒ `:version_conflict`                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                 |
| **F9** Gateway                  | Endpoints de §12, subconjunto de la API de chat                                                                                                                                                         | Arranque inválido fuera de loopback sin clave y TLS; comparación de tiempo constante; límites; ningún secreto en logs; campo no soportado ⇒ `:invalid_request`; `n` distinto de 1 ⇒ `:invalid_request`                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                |
| **F10** Guardrails y evaluación | §16                                                                                                                                                                                                     | `stream_mode` obligatorio; veto post-hoc devuelve error; métricas con definiciones de §16.3; corpus de inyección                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                      |
| **F11** RAG núcleo              | Chunker, embedder, stores `Memory` y `SQLite`, retriever `Vector`, citas, `rag_query` (§8.8) y `calibrate_rag/2`                                                                                        | IDs estables sin colisión; reindexado incremental por `content_hash`                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                  |
| **F12** RAG avanzado            | `Lexical`, `Hybrid` (RRF 1-based), `MultiQuery`, reranker, store Postgres                                                                                                                               | `min_score` por retriever antes de la fusión; cosine 0.0 excluido; `min_score` con defecto `0.0` y `calibrate_rag/2` funcional (F1@5, precisión sobre devueltos)                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                      |
| **F13** Cliente MCP             | stdio y HTTP, SSRF, permisos                                                                                                                                                                            | Todas las reglas de §9.3 con resolver falso; mensaje mayor que `max_message_bytes` cierra la conexión                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                 |
| **F14** Agentes                 | Bucle, HITL, `AgentStore`, sub-agentes, eventos de coral en `handle/2`                                                                                                                                  | Cierre por todas las causas de §10.1; snapshot con `[:safe]` y HMAC; reanudación con plazo restante; un agente con `parent:` muere con su padre                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                       |
| **F15** Nodos remotos           | `Gunther.Node.Agent`, `Node.Client`, `Backend.Remote`, perfiles, leases                                                                                                                                 | Todas las pruebas de §18.9; N-07 medido y publicado; ningún camino acepta comando, ruta o entorno del controlador; engine inaccesible por red salvo mediante el proxy mTLS; cuerpos de la API de nodo validados contra §18.3.1                                                                                                                                                                                                                                                                                                                                                                                                                                                                        |
| **F16** Endurecimiento y 1.0    | Carga, caos, fuzz, seguridad, documentación, publicación                                                                                                                                                | Todos los N-01 a N-14 verdes; ADR completos; `1.0.0`                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                  |
| **F18** Base de la coral        | `Context`, `Board`, `Coral.Run`, `Member`, `Monitor`, mensajería, `RunStore`                                                                                                                            | Ver §22.18                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                            |
| **F19** Motor del plan          | Pasos, validación, condiciones, consenso, reanudación                                                                                                                                                   | Ver §22.18                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                            |
| **F20** Modalidades y DSL       | `Mode`, `:hive`, `:teamwork`, `:routing_vote`, TOML y DSL                                                                                                                                               | Ver §22.18                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                            |
| **F21** Contexto portable       | `Context.Portable`, `on_switch`, afinidad, corpus de continuidad                                                                                                                                        | Ver §22.18                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                            |
| **F22** Integración con Arrea   | Condicionada a G-28                                                                                                                                                                                     | Ver §22.18                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                            |

**Nota sobre F17.** La colmena, que era F17 en r5/r6, se sustituye por F18 a F22 (la coral) en r7 y r8. No hay una F17 activa.

### 19.1 Añadidos de r7 a los AC, por fase

| Fase | Añadido                                                                                                                                               | AC                                                                                                                                                                   |
| ---- | ----------------------------------------------------------------------------------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| F1   | Estructura `Gunther.Context` y prefijo `[:gunther, :coral]` reservado (G2, G6); sección `[consumers.*]` y `[[consumers.<id>.rules]]`                  | `chat/2` sin contexto se comporta igual que antes; un consumer sin `default_model` es `config_error`; un nombre de regla duplicado es `config_error`                 |
| F2   | Convenciones A y B de medida; `Doctor.calibrate_overhead/2`; capas enteras                                                                            | Un device nunca mezcla fuentes; B sin `overhead_mib` ⇒ `:overhead_unknown`                                                                                           |
| F3   | `opts.require`, `opts.context` (G1, G2); límite de adjuntos por tipo                                                                                  | Adjunto mayor que el límite ⇒ `:invalid_request` con `details.attachment_too_large`; `require` no salta un veto                                                      |
| F4   | `Decision.affinity` (G4); `[consumers.*]` y envejecimiento del `Selector`; `min_similarity` con defecto y calibración; **reglas por consumer (M-01)** | La afinidad nunca sobrescribe veto, force ni pin; un consumer con prioridad mayor no deja sin servicio a otro (envejecimiento); **reglas por consumer según §6.8.1** |
| F5   | Presupuesto jerárquico (G5); defecto `wait` y detalles del refusal                                                                                    | La suma gastada no supera lo asignado arriba; `:refused_capacity` nunca lleva un número que signifique «no se sabe»                                                  |
| F6   | Estados de la reserva; reintento en otro device                                                                                                       | Un engine que usa más de lo reservado corrige la reserva y emite `:reserve_exceeded`; con dos devices, un fallo en uno reintenta en el otro                          |
| F7   | `side_effects` en tools (G7); permisos por rol                                                                                                        | Una tool `:unsafe` sin resultado registrado no se repite al reanudar                                                                                                 |
| F8   | `Session.last_call`; `Memory` con autor y versión (G4, G8)                                                                                            | `put/3` con `if_version:` desactualizada ⇒ `:version_conflict`                                                                                                       |
| F9   | Subconjunto de la API de chat (§12.3)                                                                                                                 | Un campo no soportado ⇒ `:invalid_request`; `n` distinto de 1 ⇒ `:invalid_request`                                                                                   |
| F14  | Eventos de coral en `handle/2` y arranque bajo supervisor externo (G3)                                                                                | Un agente arrancado con `parent:` muere con su padre                                                                                                                 |
| F15  | Cuerpos de la API de nodo (§18.3.1)                                                                                                                   | Cada operación valida su cuerpo contra la tabla                                                                                                                      |

### 19.2 Añadidos de r8 a los AC

- **F1-01**: validación de `[[consumers.<id>.rules]]` y de su `name` único en el espacio combinado con `[[rules]]`.
- **F4-03**: prueba de precedencia completa de §6.8.1 (veto consumer > veto global > force consumer > force global > prefer consumer > prefer global > default_model), con los tres casos borde de §6.10.
- **F4-04**: caché de decisiones incluye el hash de `[[consumers.*.rules]]`; invalidación al cambiarlas.
- **F18**: N-15 = 50 ms p99.
- **F22**: `Gunther.Coral` sustituye a `Gunther.Hive`; `Gunther.Voice` no existe como behaviour.

---

## 20 · Riesgos y deuda

| #    | Riesgo o deuda                                                                       | Tratamiento                                                                                                                                                    |
| ---- | ------------------------------------------------------------------------------------ | -------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| R-01 | Las puertas G de las hermanas fallan                                                 | Ramas B del Anexo C; contribución upstream (§3.7)                                                                                                              |
| R-02 | Los flags y salidas de `llama-server` cambian entre versiones                        | `[[engines]].min_build`, fixtures de salida por versión, test semanal de CI contra la versión fijada                                                           |
| R-03 | `Port` no separa `stderr` ni mata al hijo con la VM                                  | Consecuencias documentadas en §3.4; reaper; candidatos del `Spawner` en G-08                                                                                   |
| R-04 | Licencia del modelo de decisión de referencia                                        | Q-02                                                                                                                                                           |
| R-05 | La calidad del router depende de un corpus etiquetado que el operador debe construir | §16.4 provee las herramientas (`capture`, `label`, `synthesize`, `adversarial`); sin corpus, la capa `:llm` no se activa (§6.11). El dueño ratificó Q-03 en r8 |
| R-06 | Nombres y atribución de ROCm y Metal sin verificar en hardware                       | G-10 y G-11 con rama B                                                                                                                                         |
| R-07 | Complejidad operativa de mTLS                                                        | `Doctor` comprueba certificados, huellas y permisos; documentación con el procedimiento de emisión                                                             |
| R-08 | Valor de la coral no demostrado                                                      | D-56; criterio de promoción medible                                                                                                                            |
| R-09 | RAG sin ADR escrito completo (deuda documental, no de diseño)                        | Escribirlo antes de F11; D-36 y sus cierres están en `ADR-036-rag.md`                                                                                          |
| R-10 | Cambio de la especificación MCP cada pocos meses                                     | Constante de versión única; test periódico                                                                                                                     |
| R-11 | `llama-fit-params` puede no existir                                                  | Rama B de G-09                                                                                                                                                 |
| R-12 | El dueño debe aportar umbrales (NFR, calidad del router)                             | **Cerrado en r8**: §17 con umbrales aprobados; Q-01, Q-02 y Q-03 ratificadas                                                                                   |
| R-13 | La coral amplía mucho el alcance                                                     | Posterior a 1.0; solo los ganchos G1 a G9 entran en v1 (§22.14). **Aprobado en r8 (Q-09, Q-13)**                                                               |
| R-14 | El consenso entre modelos no garantiza corrección                                    | Estrategias explícitas; texto libre solo con juez o síntesis; no hay medida objetiva de acuerdo sin estructura (§22.8)                                         |
| R-15 | Un grupo de agentes multiplica coste y superficie de ataque                          | Límites obligatorios, presupuesto jerárquico, permisos por rol, T-17 a T-24                                                                                    |
| R-16 | Arrea cambia (4.0.0 existe, su README no dice qué cambió)                            | G-17, G-28; implementación propia por defecto (D-78)                                                                                                           |
| R-17 | Reglas por consumer mal declaradas pueden dejar a un consumer sin candidatos         | Validación de carga: veto incondicional que casa con el `default_model` es `config_error` (§6.8.1, §14.2); `:no_candidates` con `:consumer_veto` en `filtered` |

---

## 21 · Preguntas abiertas

**Todas cerradas en r8.** La tabla sustituye a la de r7.

| #    | Pregunta                               | Respuesta                                                                                                                                                                | Afecta a                 | Origen                        |
| ---- | -------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------ | ------------------------ | ----------------------------- |
| Q-01 | Umbrales de §17                        | **Aprobados por el dueño**: 5 ms (N-01) y 25 ms (N-07). Ratificado en r8                                                                                                 | §17                      | `CIERRE-DP0.md` §2.Q-01       |
| Q-02 | Licencia del modelo decisor            | **Cerrada (D-71, D-72)**: Gunther no incluye modelos ni fija uno; cada operador elige el suyo. Ratificado en r8                                                          | §6.11                    | `CIERRE-DP0.md` §2.Q-02       |
| Q-03 | Corpus y umbrales de calidad           | **Resuelta por diseño (D-72, §16.4)**: el corpus se construye con herramientas de Gunther; verificación relativa a línea base con intervalo de Wilson. Ratificado en r8  | §16.4                    | `CIERRE-DP0.md` §2.Q-03       |
| Q-04 | Certificados de nodos                  | **Cerrada**: huella fijada con rotación, sin CA (§18.4). Ratificado en r8                                                                                                | §18.4                    | `CIERRE-DP0.md` §2.Q-04       |
| Q-05 | Backends                               | **Cerrada**: v1 = CUDA, Vulkan, ROCm, Metal y CPU; otros backends fuera de v1 mediante `Detector`. Ratificado en r8                                                      | §11.7                    | `CIERRE-DP0.md` §2.Q-05       |
| Q-06 | Windows nativo como nodo               | **Cerrada**: Windows queda fuera. Ratificado en r8                                                                                                                       | §0.3                     | `CIERRE-DP0.md` §2.Q-06       |
| Q-07 | Publicación                            | **Cerrada (D-73)**: paquete `gunther`; licencia Apache-2.0; G-16 verifica disponibilidad del nombre. Ratificado en r8                                                    | §0.5, G-16               | `CIERRE-DP0.md` §2.Q-07       |
| Q-08 | Descarga de modelos en nodos           | **Cerrada**: Gunther no descarga modelos; solo gestiona arranque, parada y límites. Ratificado en r8                                                                     | §3.4, §18.4              | `CIERRE-DP0.md` §2.Q-08       |
| Q-09 | Coral y ganchos G1-G9                  | **Cerrada**: G1-G9 entran en v1 (fases §22.14); coral (F18-F22) después de 1.0. **N-15 = 50 ms p99**.                                                                    | §17, §19, §22.14, §22.18 | `CIERRE-DP0.md` §2.Q-09, M-02 |
| Q-10 | Votación de enrutado (`:routing_vote`) | **Cerrada**: se mantiene como modalidad `:routing_vote` (D-46 vigente como contrato de miembro)                                                                          | §22.9                    | `CIERRE-DP0.md` §2.Q-10       |
| Q-11 | DSL, datos y TOML                      | **Cerrada**: los tres a la vez, condicionado a G-31. Si G-31 falla, el DSL no entra en F20; datos y TOML sí                                                              | §22.10, F20              | `CIERRE-DP0.md` §2.Q-11       |
| Q-12 | `expand` y coral por gateway           | **Cerrada**: `expand` desactivado por defecto; la coral no se expone por el gateway en v1                                                                                | §22.5.3, §22.19          | `CIERRE-DP0.md` §2.Q-12       |
| Q-13 | `Coral` sustituye a `Hive` y `Voice`   | **Cerrada**: sí. Tabla de renombrado en §0.2 (M-03)                                                                                                                      | §0.2, §4.9, §10.2, §22   | `CIERRE-DP0.md` §2.Q-13       |
| Q-14 | ¿Existe `Arrea.Resource`?              | **Cerrada**: sí, existe en `main` según la medición del dueño (D-13); su publicación en Hex está pendiente de G-28. El ledger se queda propio en v1 (M-04). G-28 puede proponer una fachada en una fase posterior, con la condición de §1.4 | §1.4, §3.2, D-48, D-91   | `CIERRE-DP0.md` §2.Q-14       |
| Q-15 | Los tres niveles de D-09               | **Cerrada**: `[[consumers.<id>.rules]]` (nivel 1) + `[[rules]]` (nivel 2) + `default_model` (nivel 3). Precedencia en §6.8.1 (M-05)                                      | §6.8.1, §14.1, §14.2     | `CIERRE-DP0.md` §2.Q-15       |
| Q-16 | Taxonomía cerrada de skills            | **Cerrada**: se mantiene cerrada (M-06). Razones: previsibilidad del catálogo, filtros rápidos del router, ampliación como cambio de contrato                            | §1.3                     | `CIERRE-DP0.md` §2.Q-16       |

**Efecto:** `docs/08-decisiones/README.md` actualiza el estado de D-48 a D-92 a `aceptada`; `docs/12-roadmap.md` y `docs/13-registro-de-fases.md` se actualizan (M-09, M-10, M-11).

---

## 22 · La coral

> **Estado**: **aprobada** (r8). Se entrega en F18-F22 (v1.1+), con los ganchos G1-G9 en v1 (§22.14). Sustituye al módulo de colmena y voces de §10.2 (D-30, D-46, D-56 quedan revisadas en §1.4 y §1.5). Origen: petición del dueño del 2026-10-26; ratificada en DP0 (Q-09 a Q-13).

### 22.1 Qué es y qué no es

**La coral es la infraestructura ya integrada de Gunther** (providers y modelos con smart router, agentes, MCP y tools, RAG, memoria, sesiones, guardrails, presupuesto y telemetría) **más una base para organizar grupos de agentes** que persiguen un objetivo. La colmena (antes «mesa camilla»: son el mismo concepto, solo cambió el nombre) y el equipo de trabajo (teamwork) son **dos modalidades de esa base**: ambas son «un puñado de agentes organizados, cada uno con sus especificaciones, para lograr un objetivo», y se diferencian en objetivo, metodología, organización y enrutado. Un desarrollador puede usar una modalidad incorporada, parametrizarla, o definir una nueva con el DSL de §22.10.

**Principios (comprobables)**

| #   | Principio                                                                                                                                    | Cómo se comprueba                                                                                                                                |
| --- | -------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------ |
| C1  | **Cada pieza se usa por separado**: un `Agent` sin coral, `Memory` sin `Board`, `RAG` sin agentes                                            | Pruebas que arrancan cada módulo sin los demás (§0.4)                                                                                            |
| C2  | **Integración perfecta cuando se usan juntas**: todas las piezas comparten un único sobre de contexto, `Gunther.Context` (§22.3)             | El mismo `trace_id`, presupuesto, token de cancelación y consumer atraviesan router, agentes, tools, RAG y memoria (prueba de extremo a extremo) |
| C3  | **Una sola estructura interna, el `Plan`**: código, TOML y DSL producen el mismo `Plan`                                                      | Prueba de propiedades: la misma definición por las tres vías da un `Plan` idéntico                                                               |
| C4  | **Generalidad**: Gunther no trae roles, flujos ni vocabulario de ningún negocio. Las modalidades incorporadas son estructuras parametrizadas | Revisión: ningún nombre de rol ni de paso de negocio en el código                                                                                |
| C5  | **Terminación garantizada y todo acotado**: toda ejecución termina por finalización o por un límite declarado                                | Pruebas de saturación y de bucles                                                                                                                |
| C6  | **Seguro por defecto**: permisos por rol, TOML sin ejecución de código, contenido entre agentes tratado como no confiable                    | §22.16                                                                                                                                           |

### 22.2 Vocabulario

| Término                | Significado                                                                                                 |
| ---------------------- | ----------------------------------------------------------------------------------------------------------- |
| **Coral**              | La infraestructura integrada y su fachada `Gunther.Coral`                                                   |
| **Modalidad** (`Mode`) | Una plantilla parametrizada que produce un `Plan` (`:hive`, `:teamwork`, `:routing_vote`, o una propia)     |
| **Plan**               | Estructura de datos: roles, pizarra, pasos y aristas. Es lo que se ejecuta                                  |
| **Rol** (`Role`)       | Qué es un participante: prompt, herramientas permitidas, acceso a la pizarra y política de modelo por tarea |
| **Tarea** (`Task`)     | Una unidad de trabajo de un rol, con su propia política de modelo, entradas y salida                        |
| **Miembro** (`Member`) | Un proceso en ejecución que desempeña un rol (un agente, §10.1)                                             |
| **Paso** (`Step`)      | Un nodo del plan: tarea, paralelo, consenso, bifurcación, bucle, puerta humana, llamada, subplan, expansión |
| **Pizarra** (`Board`)  | Memoria compartida de **una ejecución** (§22.6)                                                             |
| **Ejecución** (`Run`)  | Una instancia en marcha de un plan                                                                          |

### 22.3 La base: qué se reutiliza y qué es nuevo

| Pieza de la coral                   | Existente en r6                                                 | Nuevo                                                                                                        |
| ----------------------------------- | --------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------ |
| Elegir modelo por tarea             | Router, reglas, `DecisionSpec` (§6)                             | Política de modelo por rol y tarea; `opts.require` por llamada (§22.4)                                       |
| Miembro                             | `Gunther.Agent` (§10.1): bucle, HITL, presupuesto, `AgentStore` | Eventos de coral en `handle/2`; agente genérico `Coral.Agent.Generic` que ejecuta un rol sin escribir módulo |
| Herramientas                        | `Gunther.Tools`, permisos, MCP, `rag_query` (§9, D-36)          | Permisos por rol (intersección con los globales)                                                             |
| Memoria                             | `Memory` KV (§7.2)                                              | `Board` con versión, autor, CAS y suscripción; promoción explícita a `Memory`                                |
| Sesiones                            | `Session` (§7.1)                                                | Contexto portable (§22.12)                                                                                   |
| Guardrails, presupuesto, telemetría | §16, §11.6, §13                                                 | Presupuesto jerárquico; eventos `[:gunther, :coral, ...]`                                                    |
| Comunicación                        | —                                                               | Mensajería entre miembros (§22.7)                                                                            |
| Orquestación                        | —                                                               | `Run`, motor del plan, consenso, modalidades, DSL                                                            |

**`Gunther.Context`** (D-80): sobre único que viaja por toda la coral.

```elixir
%Gunther.Context{
  consumer: atom(), trace_id: binary(), run_id: binary() | nil, member_id: binary() | nil,
  budget: %{cost_micros: n | nil, tokens: n | nil},        # lo que queda
  deadline_ms: n | nil, cancel: Gunther.Cancel.t(),
  session: binary() | nil, memory_scope: :consumer | :global | {:board, run_id},
  tags: [atom()]
}
```

`Gunther.chat/2` acepta `context: ctx` (§4.2). Un `chat/2` sin contexto crea uno por defecto con los valores de `opts`, de modo que **nada cambia para quien no usa la coral**. Si `opts` y `context` discrepan, ganan las `opts` explícitas.

### 22.4 Roles, tareas y política de modelo

```elixir
%Gunther.Coral.Role{
  id: atom(), description: binary(),
  agent: module() | :generic,                       # módulo que implementa Gunther.Agent, o el genérico
  prompt: {name :: binary(), version :: pos_integer()},   # prompts versionados (D-38)
  tools: [binary() | glob],                         # permitidas; se intersecan con tools.permissions
  tool_permissions: [%{pattern: binary(), permission: :auto | :confirm | :deny}],
  board: %{reads: [glob], writes: [glob]},
  model: model_policy(),                            # defecto del rol
  limits: %{max_turns: pos_integer(), budget: %{cost_micros: n | nil, tokens: n | nil}},
  instances: pos_integer()                          # defecto 1
}

%Gunther.Coral.Task{
  id: atom(), role: atom(), input: [board_path()], output: board_path() | nil,
  prompt: {binary(), pos_integer()} | nil,          # fragmento propio de la tarea
  model: model_policy() | nil,                      # si falta, el del rol
  response_format: :text | :json | {:json_schema, map()},
  tools: [binary() | glob] | nil
}
```

**`model_policy`** (cada tarea puede usar un provider y modelo distinto):

| Valor                                     | Efecto                                                                            |
| ----------------------------------------- | --------------------------------------------------------------------------------- |
| `:router`                                 | Smart router completo (§6) con el consumer de la ejecución                        |
| `{:alias, a}`                             | Fija el modelo (`opts.model`)                                                     |
| `{:ranked, [a, ...]}`                     | Candidatos en ese orden, con failover (§2.5)                                      |
| `{:require, [skill]}`                     | Restringe el conjunto elegible a modelos con esas skills y deja decidir al router |
| `{:locality, [:local \| :lan \| :cloud]}` | Restringe por localidad                                                           |
| `{:tags, [atom]}`                         | Restringe por etiquetas del catálogo                                              |

Las restricciones se traducen a opciones de `chat/2`. **Gancho G1 (§22.14)**: `opts.require` (`%{skills:, locality:, tags:}`). Un `veto` o `force` de §6.8 siempre prevalece sobre la política de un rol.

**Miembro**: un `Role` con `instances: n` arranca `n` miembros. En la modalidad colmena, las «voces» son miembros del mismo rol con política de modelo distinta (`members: [{role, model}, ...]`).

### 22.5 El plan

**Estructura (IR)**: `%Plan{id, version, roles, board, steps, limits}`. `steps` es una lista de pasos con `id` único y `after: [id]` (aristas explícitas). **El grafo de aristas es acíclico**: la repetición solo existe mediante el paso `loop`, que es acotado.

**Tipos de paso** (conjunto cerrado en v1.1; ampliable con el behaviour `Coral.Step`, §22.14):

| Tipo        | Qué hace                                                                                  | Parámetros principales                                            |
| ----------- | ----------------------------------------------------------------------------------------- | ----------------------------------------------------------------- |
| `task`      | Un rol ejecuta una tarea                                                                  | `role`, `reads`, `writes`, `model`, `response_format`, `on_error` |
| `parallel`  | Ejecuta varios pasos a la vez y los une                                                   | `steps`, `join` (`:all`, `{:quorum, k}`, `:first`), `timeout_ms`  |
| `consensus` | Aplica una estrategia de consenso a propuestas de la pizarra                              | `strategy`, `reads`, `writes`, `on_no_consensus`                  |
| `branch`    | Elige el siguiente paso según una condición                                               | `on` (ruta de pizarra), `cases`, `default`                        |
| `loop`      | Repite un subconjunto de pasos                                                            | `body`, `until` (condición), **`max` obligatorio**                |
| `gate`      | Puerta humana (suspende hasta `resume/2`)                                                 | `prompt`, `required`, `timeout_ms`                                |
| `call`      | Llama a una tool registrada **sin modelo** (determinista)                                 | `tool`, `args`, `writes`                                          |
| `subplan`   | Ejecuta otro plan completo                                                                | `plan`, `inputs`, `outputs`                                       |
| `expand`    | Un miembro devuelve un fragmento de plan como **datos** que se valida y ejecuta (§22.5.3) | `role`, `limits`                                                  |

**22.5.1 Semántica de ejecución.** Un paso pasa por `pending → ready → running → (done | failed | skipped)`. Está `ready` cuando todos los de `after` están `done` o `skipped` y su condición de entrada (si la tiene) se cumple. Los pasos `ready` se lanzan hasta `coral.run.max_parallel`. Cada paso tiene `timeout_ms` (defecto `coral.step.timeout_ms`). `on_error`: `:fail` (la ejecución falla), `:skip`, `{:retry, n}` (con la resiliencia de §2.5) o `{:goto, id}`. **La ejecución termina** cuando no quedan pasos `ready` ni `running`, o cuando se alcanza un límite: `max_steps`, `max_duration_ms`, presupuesto, o cancelación. Estados finales: `:completed`, `:failed`, `:cancelled`, `:timed_out`, `:budget_exhausted`.

**22.5.2 Condiciones.** Lenguaje **cerrado**: `{:eq, path, v}`, `{:ne, path, v}`, `{:gt, path, v}`, `{:gte, path, v}`, `{:lt, path, v}`, `{:lte, path, v}`, `{:in, path, [v]}`, `{:exists, path}`, `{:and, [c]}`, `{:or, [c]}`, `{:not, c}`. `path` es una clave de la pizarra con subruta separada por puntos. Una ruta inexistente evalúa a falso, sin excepción. Una función propia (`{:fn, Mod, :fun}`) existe **solo en definiciones por código** y se rechaza en TOML (§22.16).

**22.5.3 Planes dinámicos (`expand`), desactivado por defecto** (`coral.allow_dynamic_plans = false`). Permite que un rol planifique el trabajo en tiempo de ejecución, como un responsable que reparte tareas. Reglas: el fragmento es **solo datos** y pasa el mismo validador que un plan escrito a mano; solo puede usar roles, tools y modelos ya declarados en el plan padre; sus pasos cuentan contra `max_steps` y presupuesto del padre; no puede ampliar permisos ni límites; un fragmento inválido es un error del paso `expand` (`:invalid_plan_fragment`).

**22.5.4 Validación (al definir, no al ejecutar)**: identificadores únicos; referencias a roles, pasos y rutas de pizarra existentes; aristas sin ciclos; todo `loop` con `max` y dentro de `coral.loop.max_cap`; todo `parallel` con `join`; todo `consensus` con estrategia registrada; rutas de lectura y escritura de cada paso permitidas por el `board` de su rol; presupuesto y límites presentes. Un plan inválido no se ejecuta.

### 22.6 La pizarra (`Board`)

Memoria compartida **de una ejecución**; no es la memoria KV de §7.2, pero se conecta con ella.

```elixir
%Gunther.Coral.Board.Entry{key: binary(), value: term(), kind: :value | :log,
  version: pos_integer(), author: member_id, step: step_id, at: DateTime.t(), bytes: non_neg_integer()}
```

| Operación                                        | Semántica                                                                                                                                                           |
| ------------------------------------------------ | ------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `put(key, value, if_version: n \| :any \| :new)` | Escritura con **comparación y cambio**: falla con `{:error, :version_conflict}` si la versión no coincide. Cada escritura incrementa la versión y fija autor y paso |
| `append(key, item)`                              | Añade a un registro (`kind: :log`)                                                                                                                                  |
| `get(key)`, `list(prefix)`, `snapshot()`         | Lectura                                                                                                                                                             |
| `subscribe(pattern)`                             | El proceso recibe `{:gunther_board, run_id, :changed, key, version}`. **La suscripción está acotada a la ejecución**: no se ven eventos de otras                    |
| `promote(key, to: {:memory, scope})`             | Copia explícita a la memoria KV (`:consumer` o `:global`); es la única vía                                                                                          |

**Acceso por rol**: cada rol declara `reads` y `writes` (patrones). Un acceso fuera de ellos es `{:error, :board_forbidden}` y emite `[:gunther, :coral, :board, :denied]`.

**Límites** (parámetros): `coral.board.max_entries` (1024), `max_value_bytes` (1 MiB), `max_total_bytes` (64 MiB); al superarlos, `{:error, :board_full}`. Sin descarte silencioso.

**Contenido**: todo valor escrito desde la salida de un modelo se marca `untrusted` al entrar en un prompt (§7.3, T-01). La pizarra se incluye en el snapshot de la ejecución (§22.11).

### 22.7 Mensajería entre miembros

Los miembros son procesos de OTP y se comunican con el paso de mensajes nativo.

```elixir
%Gunther.Coral.Message{id: binary(), run_id: binary(), from: member_id | :leader,
  to: member_id | {:role, atom()} | :all | :leader,
  kind: :request | :reply | :event | :signal, ref: reference() | nil, reply_to: binary() | nil,
  payload: term(), deadline_ms: n | nil}
```

| Regla                        | Detalle                                                                                                                            |
| ---------------------------- | ---------------------------------------------------------------------------------------------------------------------------------- |
| Topología por defecto        | **Estrella**: los mensajes pasan por el proceso de la ejecución (`Coral.Run`), que los registra, aplica límites y emite telemetría |
| Topología `:mesh` (opcional) | Mensajes directos entre miembros solo si el rol emisor declara `can_message: [roles]`                                              |
| Petición y respuesta         | `Coral.request(to, payload, timeout_ms)` devuelve la respuesta o `{:error, :timeout}`; la correlación se hace por `ref`            |
| **Buzón acotado**            | `coral.member.max_mailbox` (256). Si está lleno, el emisor recibe `{:error, :mailbox_full}`. **Nunca se descarta en silencio**     |
| Tamaño y número              | `coral.message.max_bytes` (256 KiB) y `coral.message.max_per_run` (10 000 por ejecución)                                           |
| Identidad                    | Los identificadores de miembro son binarios generados por Gunther. **Gunther no crea átomos a partir de entrada externa** (N-17)   |
| Contenido                    | Los payloads entre miembros son entrada no confiable para el receptor (§22.16)                                                     |

### 22.8 Consenso

`Gunther.Coral.Consensus` es un behaviour registrable (`:consensus`):

```elixir
@callback decide(proposals :: [%{member: id, value: term(), meta: map()}], ctx :: Gunther.Context.t(), opts :: map()) ::
            {:ok, %{value: term(), support: map()}} | {:no_consensus, map()} | {:error, term()}
```

| Estrategia integrada | Qué hace                                                                                                                               | Requisito                                              |
| -------------------- | -------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------ |
| `:majority`          | Compara un campo estructurado (`key`) entre propuestas tras normalizarlo; gana el valor con apoyo ≥ quórum (defecto: mayoría estricta) | Las propuestas son estructuradas (`{:json_schema, _}`) |
| `:weighted`          | Como `:majority` con pesos por miembro                                                                                                 | Ídem                                                   |
| `:judge`             | Un rol evalúa las propuestas y devuelve `{choice, rationale}` estructurado                                                             | Un rol juez                                            |
| `:synthesis`         | Un rol fusiona las propuestas en una respuesta                                                                                         | Un rol sintetizador                                    |
| `:rounds`            | Itera: los miembros ven las propuestas ajenas y revisan, hasta que `:majority` alcanza quórum o `max_rounds`                           | `max_rounds` obligatorio                               |
| `:borda`             | Agrega rankings (la agregación de §6.4)                                                                                                | Propuestas = rankings                                  |

**Límite objetivo**: el consenso sobre **texto libre sin estructura** no tiene una medida objetiva de acuerdo en este documento; solo se obtiene mediante `:judge` o `:synthesis`. Una estrategia por similitud (por ejemplo con embeddings y un umbral calibrado) puede añadirse como `Consensus` de terceros.

**`on_no_consensus`**: `:fail`, `{:fallback, step_id}`, `:gate` (decide una persona) o `{:judge, role}`.

### 22.9 Modalidades

`Gunther.Coral.Mode` es un behaviour registrable (`:coral_mode`): `plan(params) :: {:ok, Plan.t()} | {:error, term()}`, `params_schema() :: map()` (JSON Schema) y `describe() :: binary()`.

| Modalidad            | Qué produce                                                                                                                                                              | Parámetros                                                                                                                       |
| -------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------ | -------------------------------------------------------------------------------------------------------------------------------- |
| `:hive` (colmena)    | Un `loop` de `rounds` rondas: `parallel` de tareas (un miembro por entrada de `members`, cada uno con su política de modelo) seguido de un paso `consensus`              | `members`, `rounds` (defecto 1), `consensus`, `share_between_rounds` (los miembros ven las propuestas ajenas), `on_no_consensus` |
| `:teamwork` (equipo) | El plan de grafo general: **los roles y el flujo los aporta el desarrollador**; la modalidad añade validación, un rol coordinador opcional y los pasos `gate` y `expand` | `roles`, `steps`, `coordinator` (opcional)                                                                                       |
| `:routing_vote`      | La votación de enrutado de D-46: miembros que solo pueden llamar a `ctx.decide/2` y un `consensus` `:borda`                                                              | `members`, `candidates`                                                                                                          |

Gunther **no entrega roles ni flujos de negocio**. Los ejemplos de la documentación son ilustrativos.

### 22.10 El DSL

**Tres vías, un `Plan`**: (1) **datos** (`Gunther.Coral.Plan.new/1`, estructuras puras); (2) **TOML** (declarativo, validable sin compilar); (3) **DSL de Elixir** (macros que expanden a datos). El DSL es azúcar: todo lo que expresa se puede escribir en datos (D-75).

**DSL de Elixir** (ejemplos ilustrativos con nombres neutros; no definen ningún flujo):

```elixir
defmodule MyApp.Panel do
  use Gunther.Coral.DSL

  coral :panel do
    role :analyst_a, prompt: {"analyst", 1}, model: {:alias, :model_a}, board: [writes: ["proposals/*"]]
    role :analyst_b, prompt: {"analyst", 1}, model: {:alias, :model_b}, board: [writes: ["proposals/*"]]
    role :arbiter,   prompt: {"arbiter", 1}, model: :router, board: [reads: ["proposals/*"], writes: ["answer"]]

    plan limits: [max_duration_ms: 120_000, budget: [cost_micros: 500_000]] do
      parallel :fan, join: :all, timeout_ms: 60_000 do
        task :a, role: :analyst_a, reads: ["request"], writes: "proposals/a"
        task :b, role: :analyst_b, reads: ["request"], writes: "proposals/b"
      end
      consensus :decide, strategy: {:judge, role: :arbiter}, reads: ["proposals/*"], writes: "answer", on_no_consensus: :fail
      output "answer"
    end
  end
end
```

```elixir
coral :review_loop do
  role :author,   prompt: {"author", 1},   model: {:require, [:code]}
  role :reviewer, prompt: {"reviewer", 1}, model: {:alias, :model_b}

  plan do
    task :draft, role: :author, reads: ["request"], writes: "draft"
    loop :refine, max: 3, until: {:eq, "verdict.status", "approved"} do
      task :review, role: :reviewer, reads: ["draft"], writes: "verdict", response_format: {:json_schema, @verdict}
      branch :route, on: "verdict.status", cases: %{"revise" => :revise}, default: :skip
      task :revise, role: :author, reads: ["draft", "verdict"], writes: "draft", when: {:eq, "verdict.status", "revise"}
    end
    gate :approve, prompt: "Revisar el resultado", required: true
    output "draft"
  end
end
```

Atajo de modalidad: `mode :hive, members: [...], consensus: {:majority, key: "choice"}, rounds: 2`.

**TOML declarativo**: pasos en una lista plana con aristas explícitas.

```toml
[[coral.plans.panel.roles]]
id = "analyst_a"
prompt = { name = "analyst", version = 1 }
model = { alias = "model_a" }
board = { writes = ["proposals/*"] }

[[coral.plans.panel.steps]]
id = "a"
type = "task"
role = "analyst_a"
reads = ["request"]
writes = "proposals/a"

[[coral.plans.panel.steps]]
id = "decide"
type = "consensus"
after = ["a", "b"]
strategy = { name = "majority", key = "choice" }
reads = ["proposals/*"]
writes = "answer"
```

**Comprobaciones al compilar o cargar** (§22.5.4): el DSL señala errores con fichero y línea; el TOML, con la ruta de la clave. **Seguridad**: el TOML no puede referenciar funciones ni módulos arbitrarios (solo los registrados por `module = "..."` en las secciones de registro de §5.14, que ya son confianza del operador); las condiciones del TOML usan solo el lenguaje cerrado.

### 22.11 Ejecución: ciclo de vida, límites y reanudación

```elixir
Gunther.Coral.run(mode_or_plan, input, opts) :: {:ok, run_ref} | {:error, Error.t()}
Gunther.Coral.await(run_ref, timeout_ms) / status(run_ref) / events(run_ref) :: Enumerable.t()
Gunther.Coral.resume(run_ref, %{approve: [...], deny: [...], input: _}) / cancel(run_ref)
```

`opts`: `:consumer`, `:budget`, `:max_duration_ms`, `:trace`, `:store`, `:context`.

**Procesos**: `Coral.Supervisor` (árbol de §2.3) → por ejecución, `Coral.Run` (coordinador, estado del plan y estrella de mensajes) y los `Member` (agentes) bajo un supervisor propio de la ejecución, más `Coral.Monitor` (estadísticas y vigilancia). Es el mismo reparto que `Leader`, `Worker` y `Monitor` de Arrea (§22.15), con comportamiento de agente de larga vida.

**Límites** (parámetros, defecto = decisión; se miden en F18/F19): `coral.max_concurrent_runs` (16), `coral.max_members_per_run` (32), `coral.run.max_steps` (200), `coral.run.max_parallel` (8), `coral.run.max_duration_ms` (3 600 000), `coral.step.timeout_ms` (120 000), `coral.loop.max_cap` (20).

**Presupuesto**: jerárquico (ejecución → rol → llamada). Cada llamada recibe lo que queda; los reintentos y failovers se acumulan (§11.6). Al agotarse: `:budget_exhausted`.

**Persistencia y reanudación** (`Coral.RunStore`, behaviour `:run_store`, con referencias `Memory` y `Disk` firmadas como `SessionStore`):

| Qué se guarda                        | Detalle                                       |
| ------------------------------------ | --------------------------------------------- |
| Posición del plan                    | Estado de cada paso                           |
| Pizarra                              | Snapshot                                      |
| Miembros                             | `AgentStore` de cada uno (§10.1)              |
| Presupuesto y plazo restantes        | Valores restantes (no instantes)              |
| **Registro de llamadas con efectos** | Intención antes de llamar y resultado después |

**Semántica al reanudar: al menos una vez por paso.** Un paso `done` no se repite. Un paso `running` al caer se repite desde su inicio. Una tool registrada con `side_effects: :unsafe` (defecto) cuya intención figura en el registro **sin resultado** queda `uncertain`: según `on_uncertain` (`:gate` por defecto, o `:fail`) se pide decisión humana en lugar de repetirla. Con `side_effects: :idempotent` se repite. **Gancho G7 (§22.14)**: `Tools.register/2` gana `side_effects: :none | :idempotent | :unsafe`.

**Despacho por modelo** (D-76): con más miembros que modelos que se pueden tener cargados a la vez (`placement.max_loaded_models`, §11.4), lanzar las tareas listas en orden de llegada provoca cargas y descargas continuas. `coral.dispatch.mode` admite `"fifo"` (defecto: orden de llegada) y `"group_by_model"`: entre las tareas listas, se adelantan las que su política resuelve **de forma estática** (`{:alias, _}`, `{:ranked, _}`) a un modelo ya cargado. Una tarea con política `:router` no se puede agrupar antes de decidir y sigue el orden de llegada. **Anti-inanición**: ninguna tarea espera más de `coral.dispatch.max_wait_ms` (parámetro, defecto 30 000) por culpa del agrupamiento. Se comprueba en F19: con más miembros que modelos cargables, `group_by_model` realiza como máximo las cargas de `fifo` en una carga de prueba medida.

**Eventos** (§13.1): `[:gunther, :coral, :run, :start | :stop | :exception]`, `[:coral, :step, :start | :stop]`, `[:coral, :message]`, `[:coral, :board, :write | :denied]`, `[:coral, :consensus]`, `[:coral, :gate]`, `[:coral, :budget]`. Metadatos: `run_id`, `step_id`, `role`, `member` (identificadores), nunca contenido.

### 22.12 Contexto portable y cambio de modelo

**Problema** (petición del dueño): cuando el router cambia de modelo, se debe retomar el trabajo sin perder contexto y sin reprocesar todo, sabiendo que la caché del modelo anterior puede no aplicar.

**`Gunther.Context.Portable`** (por sesión y por miembro):

```elixir
%{version: pos_integer(),
  pins: [%{key: binary(), value: term(), source: binary()}],         # hechos fijados (promovibles a Memory)
  summary: %{text: binary(), upto_turn: n, made_by: model_alias},    # resumen de trabajo, incremental
  recent: [turn],                                                    # últimos k turnos literales
  refs: [board_path | memory_key | rag_id]}                          # punteros, no copias
```

- **Generación**: tras cada turno, de forma asíncrona, `context.summary_model` actualiza el resumen **incrementalmente** (solo los turnos posteriores a `upto_turn`). Es de coste marginal acotado y no bloquea la respuesta.
- **Política de cambio** `context.on_switch`: `"resend"` (**defecto**; comportamiento actual: se reenvía el historial completo dentro de `max_prompt_tokens`), `"portable"` (el prompt se compone con resumen, pins, los `portable_keep_turns` últimos turnos y refs) o `"auto"` (elige `portable` cuando `tokens_historial − tokens_portable ≥ context.switch.min_saving_tokens`). `portable_keep_turns` y `min_saving_tokens` son **obligatorios** si la política los usa; no hay defecto.
- **Cuándo hay cambio**: cuando `Decision.chosen` difiere del `model` de la última llamada de esa sesión o miembro (`Session.last_call`, nuevo: `%{model, provider, input, cached_input}` tomado de `Response.usage`).
- **Afinidad de caché en el router** (D-82): `router.affinity = "off"` (defecto) o `"prefer"`. Con `"prefer"`, el ranking suma `router.affinity_weight` (obligatorio, sin defecto) al modelo de la última llamada si esa llamada reportó `cached_input > 0`. Es una **preferencia blanda entre candidatos elegibles**: nunca sobrescribe veto, force ni pin. La traza incluye `affinity`. Que la caché del provider se conserve entre llamadas, y bajo qué condiciones se invalida, **depende de cada provider y no está verificado** (G-29); para `llama-server`, existe `--cache-prompt` \[V\], pero se desconoce qué ocurre con la caché al descargar y recargar el engine (G-29).
- **Verificación (D-72)**: `Gunther.Eval` gana el corpus de **continuidad**: escenarios multiturno con sondas sobre hechos pinados, con un cambio de modelo en medio. Métrica `fact_retention` (fracción de sondas respondidas correctamente tras el cambio) y `tokens_saved`. `portable` o `auto` solo se activan si el límite inferior de Wilson de `fact_retention` con `portable` no es menor que la de `resend` menos `eval.continuity_tolerance` (obligatorio, sin defecto). Sin informe válido, `on_switch` permanece en `resend`.
- **En la coral**: los miembros no se copian el historial; comparten datos por la pizarra y por las referencias de `refs`. Un miembro cuyo modelo cambia entre tareas aplica `on_switch` a su propia sesión.

### 22.13 Integración con el resto

| Pieza       | Integración                                                                                                          |
| ----------- | -------------------------------------------------------------------------------------------------------------------- |
| Router      | Cada llamada de un miembro lleva su `model_policy`; los vetos globales prevalecen                                    |
| Tools y MCP | Permisos por rol, intersecados con los globales; las tools importadas de MCP siguen en `:confirm` por defecto (§9.3) |
| RAG         | `rag_query` es una tool más; un rol puede o no tenerla. Un paso `call` puede invocarla sin modelo                    |
| Memoria     | `Board.promote/3`; los pins del contexto portable pueden promoverse                                                  |
| Sesiones    | Una sesión por miembro; `Session.last_call` para el cambio de modelo                                                 |
| Guardrails  | Se aplican a cada llamada de modelo; un veto en un paso aplica `on_error`                                            |
| Gateway     | **No expone la coral en v1.1** (Q-12)                                                                                |
| Telemetría  | §22.11                                                                                                               |

### 22.14 Ganchos que deben decidirse antes de 1.0

La coral puede publicarse después de 1.0, pero necesita que ciertos puntos de la API estén previstos. Añadirlos después exigiría versión mayor. **Aprobados en DP0 (D-85, Q-09).**

| #   | Gancho                                                                                                                            | Sección afectada  | Fase donde se implementa  |
| --- | --------------------------------------------------------------------------------------------------------------------------------- | ----------------- | ------------------------- |
| G1  | `opts.require` (skills, localidad, etiquetas) por llamada                                                                         | §4.2, §6          | F4                        |
| G2  | `Gunther.Context` y `opts.context` en `chat/2`, agentes, tools y RAG                                                              | §4.2, §9.1, §10.1 | F1 (estructura), F3 y F14 |
| G3  | `Agent.handle/2` admite eventos `{:task, _}`, `{:message, _}`, `{:board, _}`; un agente puede arrancar bajo un supervisor externo | §10.1             | F14                       |
| G4  | `Session.last_call` y `Decision` con `affinity`                                                                                   | §4.2, §7.1        | F8, F4                    |
| G5  | Presupuesto jerárquico (ejecución → miembro → llamada)                                                                            | §11.6, §10.1      | F5                        |
| G6  | Prefijo de telemetría `[:gunther, :coral, ...]` reservado                                                                         | §13.1             | F1                        |
| G7  | `Tools.register/2` con `side_effects` y permisos por rol                                                                          | §4.8, §9.3        | F7                        |
| G8  | `Memory.put/3` con autor y versión opcionales                                                                                     | §7.2              | F8                        |
| G9  | Behaviours registrables nuevos: `:coral_mode`, `:consensus`, `:step`, `:run_store`                                                | §5                | F18                       |

### 22.15 Arrea: qué se reutiliza y qué se propone

**Hechos verificados** \[V\] (README de `arrea` 3.1.0 y 4.0.0 en Hex, 2026-10-26): `Arrea.Leader` (GenServer) coordina la ejecución y difunde `{:leader_event, event}` a los suscriptores; `Arrea.WorkerSupervisor` (DynamicSupervisor) crea workers efímeros; `Arrea.Worker` (GenServer) ejecuta tareas (comando o función de aridad cero), aplica políticas y reporta progreso al Leader; `Arrea.Monitor` guarda estadísticas del ciclo de vida; `Arrea.subscribe/0` suscribe **al proceso que llama a todos los eventos del Leader**, sin filtro (tipos: `:worker_started`, `:progress`, `:finished`, `:error`, `:result`); mensajería entre workers con `Arrea.Worker.send_message(:worker_1, %{...})` y `{:send_to_worker, :worker_2, %{...}}`; eventos de telemetría `[:arrea, :communication, :message_sent | :message_received | :error | :retry]` (la tabla del README no lista metadatos); políticas `on_error`, `on_warning`, `on_timeout`, `max_retries`, `retry_delay`, `timeout`; pool de workers con check out/check in; `Arrea.Config` y los Registries son globales de la VM; todos los procesos bajo `Arrea.Supervisor` con `:rest_for_one`. El README de 4.0.0 es **idéntico** al de 3.1.0 (incluidos `~> 3.0` y la insignia 3.0.0), de modo que lo que cambió en 4.0.0 no se puede conocer por el README (G-28). Hex lista las versiones 4.0.0, 3.1.0, 3.0.0, 2.2.0, 2.1.0, 2.0.0 y 1.0.0 (retirada); `~> 3.0` excluye 4.0.0 (G-17). **`Arrea.Resource` no aparece en el README de ninguna de esas versiones** (G-28), pero **existe en `main` según la medición del dueño (D-13); su publicación en Hex está pendiente de G-28**, y Q-14 queda confirmada en cuanto a la existencia.

**Decisión de uso (D-78)**: en v1.1 la coral implementa **su propio** `Run`, `Member` y `Monitor` con el paso de mensajes de OTP, con un modelo de eventos y de mensajes **con la misma forma** que el de Arrea (difusión de eventos del coordinador, mensajes con destino y correlación). Motivo: los requisitos de la coral (agentes de larga vida con estado, buzones acotados, correlación petición-respuesta, eventos acotados a una ejecución) no están todos documentados en Arrea \[V\] y el código fuente no se ha podido inspeccionar. **Arrea queda como anfitrión opcional de los miembros** si G-28 demuestra que cumple R-A1 a R-A5 (abajo), o tras las evoluciones propuestas.

| Req. | Requisito de la coral sobre un anfitrión de procesos                      |
| ---- | ------------------------------------------------------------------------- |
| R-A1 | Worker de larga vida con estado y callback propio (no solo tarea efímera) |
| R-A2 | Identificadores de worker que no sean átomos (o conversión segura)        |
| R-A3 | Eventos y suscripción acotados a una ejecución                            |
| R-A4 | Buzón acotado con error explícito al llenarse                             |
| R-A5 | Petición y respuesta con correlación y plazo                              |

**Evoluciones propuestas para Arrea** (sin cambiar su dominio, que es orquestación de procesos asíncronos; todo lo específico de LLM sigue en Gunther). Cada una se contrasta con el código en G-28 antes de proponerse:

| #   | Propuesta                                                                                       | Por qué la necesita Gunther                                                                              | Efecto sobre el dominio de Arrea              |
| --- | ----------------------------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------- | --------------------------------------------- |
| A-1 | `Arrea.subscribe/1` con filtro (por lote o por identificador de ejecución)                      | `subscribe/0` entrega todos los eventos; varias ejecuciones concurrentes verían los eventos de las demás | Ninguno: es filtrado de eventos               |
| A-2 | Identificadores de worker de cualquier término (`{:via, Registry, ...}`)                        | `send_message(:worker_1, ...)` usa átomos; crear átomos desde entrada externa no es aceptable (N-17)     | Ninguno                                       |
| A-3 | Módulo de worker propio (`worker: MiModulo`) con `handle_message/2`, de larga vida              | Un miembro es un agente con estado, no una tarea efímera                                                 | Amplía qué ejecuta un worker, no qué es Arrea |
| A-4 | `Arrea.Worker.call(worker, msg, timeout)` con correlación                                       | Petición y respuesta entre miembros                                                                      | Ninguno                                       |
| A-5 | Buzón máximo por worker con política (`:reject`)                                                | Toda cola de Gunther tiene tope (N-02)                                                                   | Ninguno                                       |
| A-6 | Grupo (`Arrea.Group`): alcance con plazo común, cancelación del conjunto y estadísticas propias | Una ejecución es un grupo de workers con cancelación y plazo compartidos                                 | Generaliza lotes (`batch`), que ya existen    |
| A-7 | Instancia nombrada: Registry y config por instancia                                             | §2.7 (D-45): aislamiento de pruebas `async: true`                                                        | Ninguno                                       |
| A-8 | Metadatos tipados en `[:arrea, :communication, ...]` (origen, destino, tamaño, correlación)     | Mapear a `[:gunther, :coral, :message]`                                                                  | Ninguno                                       |

### 22.16 Seguridad

| #    | Amenaza                                                                     | Control                                                                                                                                                                             | Prueba                                               |
| ---- | --------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ---------------------------------------------------- |
| T-17 | **Inyección propagada entre agentes** (la salida de uno es entrada de otro) | Todo valor de pizarra y todo payload entre miembros es no confiable al entrar a un prompt (§7.3); permisos de tools por rol; `:confirm` y puertas humanas para acciones con efectos | Corpus de inyección entre miembros (F10-04 ampliado) |
| T-18 | **Escalada por planes dinámicos**                                           | `expand` desactivado por defecto; solo datos; mismos roles, tools y límites que el padre                                                                                            | Fragmentos que piden más permisos son rechazados     |
| T-19 | **Bucles y gasto desbocados**                                               | Grafo acíclico, `loop.max` obligatorio y acotado, `max_steps`, `max_duration_ms`, presupuesto                                                                                       | Pruebas de límites                                   |
| T-20 | **Envenenamiento de la pizarra**                                            | CAS, autor y paso en cada entrada, acceso por rol                                                                                                                                   | Escritura fuera de rol rechazada                     |
| T-21 | **Inundación de mensajes**                                                  | Buzones, tamaño y total acotados con error explícito                                                                                                                                | Prueba de saturación                                 |
| T-22 | **Ejecución de código desde configuración**                                 | TOML solo con condiciones del lenguaje cerrado; `{:fn, _, _}` rechazado en TOML                                                                                                     | Prueba                                               |
| T-23 | **Repetición de efectos al reanudar**                                       | Registro de intención y resultado; `uncertain` ⇒ puerta humana                                                                                                                      | Caída entre intención y resultado                    |
| T-24 | **Fuga entre ejecuciones**                                                  | Suscripciones y mensajes acotados a `run_id`; sin suscripción global (A-1 si se usa Arrea)                                                                                          | Dos ejecuciones simultáneas no se ven                |

### 22.17 Configuración (`[coral]`)

```toml
[coral]
enabled = false                       # la coral no arranca salvo que se active
allow_dynamic_plans = false
max_concurrent_runs = 16
max_members_per_run = 32

[coral.run]
max_steps = 200
max_parallel = 8
max_duration_ms = 3600000

[coral.step]
timeout_ms = 120000

[coral.loop]
max_cap = 20

[coral.member]
max_mailbox = 256

[coral.message]
max_bytes = 262144
max_per_run = 10000

[coral.board]
max_entries = 1024
max_value_bytes = 1048576
max_total_bytes = 67108864

[coral.store]
backend = "memory"                    # memory | disk (RunStore)

[context]                             # §22.12
on_switch = "resend"                  # resend | portable | auto
[context.switch]
# portable_keep_turns = 4             # obligatorio con portable o auto
# min_saving_tokens = 0               # obligatorio con auto
# (router.affinity y router.affinity_weight: ver [router], §14.1)
[eval]
# continuity_tolerance = 0.0          # obligatorio para activar portable o auto

[coral.dispatch]
mode = "fifo"                         # fifo | group_by_model (§22.11)
max_wait_ms = 30000
```

La sección `[coral]` es de seguridad (clave desconocida = error, §14.2). Los valores son **parámetros con defecto declarado**; se calibran con las pruebas de carga de F18 y F19 y no son predicciones.

### 22.18 Fases y criterios de aceptación

Sustituyen a F17 (colmena). Todas posteriores a 1.0, salvo los ganchos de §22.14, que se implementan en las fases indicadas de v1.

| Fase                          | Contenido                                                                        | AC                                                                                                                                                               |
| ----------------------------- | -------------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **F18** Base                  | `Context`, `Board`, `Coral.Run`, `Member`, `Monitor`, mensajería, `RunStore`     | Dos ejecuciones simultáneas no se ven (T-24); buzón lleno devuelve error; CAS de la pizarra por propiedades; N-15 = 50 ms p99; N-16 y N-17                       |
| **F19** Motor del plan        | Pasos, validación, condiciones, consenso, reanudación con registro de efectos    | Cada tipo de paso con prueba; plan con ciclo rechazado; reanudación tras caída sin repetir efectos `:unsafe`; todas las estrategias de consenso                  |
| **F20** Modalidades y DSL     | `Mode`, `:hive`, `:teamwork`, `:routing_vote`, `Plan.new/1`, TOML, DSL de Elixir | El mismo plan por las tres vías es idéntico (propiedad); TOML con `{:fn}` rechazado; errores del DSL con línea; si G-31 falla, el DSL no entra (datos y TOML sí) |
| **F21** Contexto portable     | `Context.Portable`, `on_switch`, afinidad, corpus de continuidad                 | `resend` sin cambios de comportamiento; `portable` solo con informe válido; afinidad nunca sobrescribe veto, force ni pin                                        |
| **F22** Integración con Arrea | Solo si G-28 pasa o tras las evoluciones A-1 a A-8                               | R-A1 a R-A5 demostrados con pruebas                                                                                                                              |

### 22.19 Decisiones, puertas y pendientes

**Decisiones propuestas**: D-74 a D-86 (§1.6), aceptadas en DP0.

**Puertas nuevas**: G-28 a G-31 (Anexo C).

**Pendientes del dueño**: **ninguna**. Q-09 a Q-13 cerradas en r8 (ver §21). Q-14, Q-15 y Q-16 cerradas también (§21).

---

## Anexo A · Cambios de r5 a r6

| Área                               | Cambio                                                                                                                                                                                              |
| ---------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Nombre                             | Candil → **Gunther** (§0.2, D-63)                                                                                                                                                                   |
| Método                             | Regla de no-suposición, etiquetas \[V\]/\[V5\]/\[G\]/\[P\]/\[CE\] y lint (§0.6, D-64)                                                                                                               |
| §2                                 | Plazo total y tabla error→acción (§2.5); marca `--alias` y reconciliación (§2.8); cancelación y commit de stream (§2.9); árbol con nodos y `TaskSupervisor`                                         |
| §3                                 | `Gunther.Cache` propia; contrato `Spawner`; lista de permitidos con `realpath` e inodo; `ArgsBuilder` sin líneas libres                                                                             |
| §4                                 | Salida estructurada con fallback (§4.2.1); `degraded`; `node` en `Response` y `Decision`; `Session.open/2` definido; nuevos errores; §4.15                                                          |
| §5                                 | `Classifier` con `DecisionSpec`; `Selector` por consumer; `Detector` con identidad física y atribución                                                                                              |
| §6                                 | Modelos de decisión especializados (§6.11) y seguridad del router (§6.12); `locality: lan`; Borda explícito                                                                                         |
| §7                                 | Contadores de tokens con calibración obligatoria                                                                                                                                                    |
| §8                                 | RRF 1-based; `min_score` obligatorio sin defecto                                                                                                                                                    |
| §9                                 | MCP 2026-07-28 verificado; modo compatible con sesiones; SSRF sin redirecciones; permisos y confirmación; truncado de JSON válido                                                                   |
| §10                                | `AgentStore` con snapshot definido; colmena a través de modelos de decisión                                                                                                                         |
| §11                                | Backends GPU y matriz (§11.7); identidad física, memoria unificada y coherencia (§11.8); `foreign` corregido; fórmula de KV corregida; coste de entrada en el presupuesto                           |
| §12 a §17                          | **Nuevas** (r5 las anunciaba y no estaban en el fichero): gateway, telemetría, configuración, amenazas, guardrails y evaluación, requisitos no funcionales                                          |
| §18                                | **Nueva**: nodos remotos                                                                                                                                                                            |
| §19 a §21                          | **Nuevas**: fases con AC, riesgos, preguntas abiertas                                                                                                                                               |
| Alcance (D-71)                     | Windows fuera, sin descarga de modelos, tope por conteo de modelos cargados, decisor multilingüe sin modelo fijado                                                                                  |
| Decisor y publicación (D-72, D-73) | Decisor agnóstico y personalizable, verificación relativa a línea base, construcción de corpus (§16.4), rotación de huellas en nodos, política de licencia y contribución                           |
| Adenda de la coral                 | §22: la coral (colmena y equipo como modalidades), DSL, pizarra, mensajería, consenso, contexto portable y cambio de modelo, evoluciones propuestas para Arrea, D-74 a D-86, G-28 a G-31, F18 a F22 |
| Anexos                             | A (este), B (cierres), C (verificaciones y puertas)                                                                                                                                                 |

### A.2 Cambios de r6 a r7

| Área          | Cambio                                                                                                                                               |
| ------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------- |
| Método        | Resolución de J-00 a J-16 y de las incoherencias abiertas con decisiones D-87 a D-92; correcciones C-01 a C-12                                       |
| §1            | D-41 y D-44 renombradas o retiradas; D-87 a D-92                                                                                                     |
| §2, §3        | Reparto (Selector + Placer); `Cache.Completions` fuera de v1; LRU con clave única; tipo del token de cancelación                                     |
| §4            | `opts.require` y `opts.context`; adjuntos; `Decision.affinity`; `Session.last_call`; `calibrate_rag` y `calibrate_overhead`; nuevos códigos de error |
| §5            | `Chunker.max_chunk_bytes/0`; `ETS` fuera de los stores del RAG; `Detector.measure` con `source`                                                      |
| §6            | Defecto del refusal y sus dos reglas; afinidad; `min_similarity` con defecto                                                                         |
| §7            | Memoria con autor, versión y `superseded_by`; separación RAG y memoria                                                                               |
| §8            | `min_score` con defecto y `calibrate_rag`; SQLite como store por defecto; `rag_query` y `store_backend`                                              |
| §9, §10       | `side_effects`; truncado UTF-8; eventos de `handle/2`                                                                                                |
| §11           | Tres estados de la reserva, reintento en otro device, capas enteras, convenciones A y B de medida, presupuesto jerárquico                            |
| §12, §13      | Formato de la clave, límite con adjuntos, subconjunto de la API de chat; evento de calidad                                                           |
| §14           | `[consumers.*]`, `[rag]`, `max_attachment_bytes`, recarga completa, validaciones                                                                     |
| §15, §18, §19 | T-25; formatos de huellas, TLS del nodo y cuerpos de su API; añadidos de AC por fase                                                                 |
| Anexo C       | G-24 a G-27                                                                                                                                          |

## Anexo B · Cierres de especificación (CE) y errores corregidos

### B.1 Los 20 huecos de la evaluación de r5

| Hueco                                      | Cierre       | Dónde                                |
| ------------------------------------------ | ------------ | ------------------------------------ |
| 1 Structured output sin soporte nativo     | CE-01        | §4.2.1                               |
| 2 `tools.permissions: :confirm` en agentes | CE-02        | §9.3                                 |
| 3 Failover antes del primer chunk          | CE-15        | §2.9, §2.5                           |
| 4 `Command.spawn/3` (env, cd, framing)     | CE-19, CE-20 | §3.4                                 |
| 5 Reaper con `keep_engines`                | CE-05        | §2.8                                 |
| 6 `Gunther.Cache` con tope                 | CE-06        | §3.3                                 |
| 7 `Agent.Store` con campos                 | CE-07        | §10.1                                |
| 8 `sessions.idle_ttl_seconds` y reapertura | CE-08        | §4.6                                 |
| 9 `Selector` con estado por consumer       | CE-09        | §5.8                                 |
| 10 Fórmula de KV para GQA/SWA/MLA          | CE-24        | §11.5                                |
| 11 Truncado de JSON                        | CE-11        | §9.1                                 |
| 12 `which` y «sin ejecutar nada»           | CE-16        | §3.3                                 |
| 13 `.env`                                  | CE-17        | §3.3                                 |
| 14 SSRF por redirección                    | CE-28        | §9.3                                 |
| 15 §21 ausente                             | —            | §21                                  |
| 16 Anexo A ausente                         | —            | Anexo A                              |
| 17 `Hive.tell/2` con voz inexistente       | CE-17b       | §4.9 (sustituido por `Coral.tell/2`) |
| 18 `degraded` en `Response`                | CE-18b       | §4.2                                 |
| 19 RRF 1-based                             | CE-29        | §8.3                                 |
| 20 `Agent` behaviour vs módulo             | CE-20b       | §5                                   |

### B.2 Hallazgos adicionales de r6

| #    | Hallazgo                                                                                                                   | Cierre               |
| ---- | -------------------------------------------------------------------------------------------------------------------------- | -------------------- |
| H-01 | D-02 definía a la vez la taxonomía cerrada y `exclusive`, y `exclusive` no estaba en el esquema                            | CE-H01 (§1.4, §14.1) |
| H-02 | La fórmula de KV fijaba `q8_0 = 1` byte por elemento y usaba una sola dimensión por cabeza para claves y valores           | CE-24 (§11.5)        |
| H-03 | Un `Port` no puede separar `stderr` de `stdout`; r5 pedía `stderr` a logs en el MCP stdio                                  | CE-20 (§3.4)         |
| H-04 | `foreign` mezclaba memoria ajena con memoria propia aún no asignada                                                        | CE-23 (§11.3)        |
| H-05 | El presupuesto solo contaba el coste de salida                                                                             | CE-25 (§11.6)        |
| H-06 | El servidor MCP «sin estado» ignoraba que el modo compatible exige sesiones                                                | CE-H15 (§9.2)        |
| H-07 | Una errata en una clave de seguridad se degradaba a aviso                                                                  | CE-H11 (§14.2)       |
| H-08 | El nombre de backend no identifica un GPU físico: doble conteo posible                                                     | D-65, CE-26 (§11.8)  |
| H-09 | `timeout` ambiguo entre plazo total y por intento                                                                          | CE-12 (§2.5)         |
| H-10 | No había tabla error→acción para retry, failover y breaker                                                                 | CE-13 (§2.5)         |
| H-11 | Cancelación sin mecanismo definido; `stream!` podía dejar procesos vivos                                                   | CE-14 (§2.9)         |
| H-12 | «Primer chunk» sin definición                                                                                              | CE-15 (§2.9)         |
| H-13 | La lista de permitidos no fijaba la identidad del ejecutable                                                               | CE-18 (§3.4)         |
| H-14 | Un flag de `llama-server` activa herramientas de agente \[V\]; la clave de API por argv es visible en la lista de procesos | CE-19, §11.1         |
| H-15 | El margen de «15 %» del modo aproximado no tenía fundamento                                                                | CE-21 (§7.6)         |
| H-16 | Las descripciones de tools de un servidor MCP entraban sin límite ni marca                                                 | CE-22 (§9.3)         |
| H-17 | Exposición del gateway sin reglas explícitas                                                                               | CE-27 (§12.2)        |
| H-18 | Las sesiones no tenían espacio de nombres por consumer                                                                     | CE-30 (§4.6, §7.1)   |
| H-19 | Deserialización de lo persistido sin garantías                                                                             | CE-07, T-12          |
| H-20 | Semántica de guardrails de output con streaming sin definir                                                                | CE-31 (§16.2)        |
| H-21 | El estado del `Selector` no tenía tope                                                                                     | §5.8                 |
| H-22 | `max_concurrency` y `--parallel` se configuraban por separado                                                              | §11.1                |
| H-23 | La cifra «~21 s» y «~50 ms» eran estimaciones sin fuente                                                                   | D-64, §6.3           |
| H-24 | `Arrea.Resource` figuraba como puerta aunque el ledger propio ya es la decisión                                            | D-48, Q-14 (§11.3)   |

### B.3 Resolución de las incoherencias y de la evaluación del paquete (r7)

**Precedencias entre D-01 a D-28 y r7 (D-91)**

| #           | Resolución                                                                                                                                                                                                          | Dónde         |
| ----------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------- |
| J-00        | Se mantiene la numeración de r6: D-02 es la taxonomía de skills (ratificada en r8, Q-16) y D-02b es `exclusive`                                                                                                     | §1.4          |
| J-01        | Prevalece el SPEC vigente: el reparto está en v1 (D-41, D-53) y los destinos se clasifican con `locality` y `node`                                                                                                  | §6.8, §18     |
| J-02, J-07  | Ledger propio y entero en MiB (D-48); se retira la cuota decimal. **Q-14 cerrada en r8: `Arrea.Resource` existe en `main` según la medición del dueño (D-13); su publicación en Hex está pendiente de G-28; si G-28 demuestra que cumple los invariantes de §11.3, el ledger pasa a fachada** | §11.3         |
| J-03        | Producción: versiones de Hex (`~>`, §0.3). La rama `main` de las hermanas solo se usa en el trabajo semanal de CI y en desarrollo local                                                                             | §0.3, §3.7    |
| J-04        | Defecto `wait` (D-88)                                                                                                                                                                                               | §6.9          |
| J-05, J-08  | `[consumers.*]` con `default_model`, `priority` y `[[consumers.<id>.rules]]` (D-87, Q-15)                                                                                                                           | §6.8.1, §14.1 |
| J-06        | Evento `[:provider, :quality]` (D-90)                                                                                                                                                                               | §13.1         |
| J-09        | Sin CLI (D-31); se retira la fase de CLI de D-18                                                                                                                                                                    | §1.1          |
| J-10        | Prevalece §10.1: se retira la regla del agente con circuito abierto                                                                                                                                                 | §10.1         |
| J-11        | Memoria con autor, versión y `superseded_by` (D-90)                                                                                                                                                                 | §7.2          |
| J-12 a J-16 | D-89                                                                                                                                                                                                                | §11.1, §11.3  |

**Evaluación del paquete**: C-01 §19; C-02 sustituida por D-36 (§8.3); C-03 §14.1; C-04 §14.4; C-05 y C-07 §18.4; C-06 §12.2; C-08 §3.3; C-09 §4.9; C-10 §2.9; C-11 §9.1; C-12 §8.3. C-13 a C-18 se aplican a los documentos del paquete.

### B.4 Cierres de r8

| #     | Hueco                                                                                                                    | Cierre                                                                  | Dónde                     |
| ----- | ------------------------------------------------------------------------------------------------------------------------ | ----------------------------------------------------------------------- | ------------------------- |
| CE-34 | D-09 y D-87 hablan de «reglas del consumer», «reglas globales» y `default_model` sin fijar la sintaxis ni la precedencia | Reglas de consumer en `[[consumers.<id>.rules]]`, precedencia en §6.8.1 | §6.8.1, §14.1, §14.2, §19 |

## Anexo C · Verificaciones y puertas F0

### C.1 Registro de hechos verificados \[V\] (consultado el 2026-10-25)

| Hecho                                                                                                                                                                                                                                                                                                                                             | Fuente                                                                                                                                                                                |
| ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| El servidor RPC de llama.cpp advierte de no exponerlo a una red abierta; no tiene autenticación incorporada; vulnerabilidades críticas de ejecución remota publicadas (CVE-2026-34159, corregida en la compilación b8492; CVE-2026-39909)                                                                                                         | github.com/ggml-org/llama.cpp/issues/9460; docs.rs/crate/ghost-link (comentario sobre `ggml-rpc-server`); research.averlon.ai (CVE-2026-34159); cve.halosecurity.com (CVE-2026-39909) |
| Vulnerabilidad de ejecución de código en llama.cpp por GGUF manipulado (anterior a la compilación b7824)                                                                                                                                                                                                                                          | vuln.today/tag/llama-cpp                                                                                                                                                              |
| Formato de `--list-devices`: `NOMBRE: descripción (total MiB, libre MiB free)`; ejemplos CUDA y Vulkan; CPU puede no aparecer; caso `free > total` en CUDA                                                                                                                                                                                        | github.com/ggml-org/llama.cpp/issues/17536, /issues/16659, /pull/16276, /pull/16039                                                                                                   |
| Memoria compartida informada por Vulkan en APU                                                                                                                                                                                                                                                                                                    | community.frame.work (hilo de Strix Halo)                                                                                                                                             |
| Flags y variables: `--device`, `--list-devices`, `--fit`, `--fit-target` (defecto 1024), `--swa-full`; `--alias`, `--parallel`, `--api-key`, `--api-key-file`, `--ssl-key-file`, `--ssl-cert-file`, `--grammar-file`, `--cache-prompt`, `--no-webui`; `GET /health` público; `LLAMA_API_KEY`; flag de herramientas de agente con aviso del README | manpages.debian.org (llama-server.1); mintlify.com/ggml-org/llama.cpp (server); agenticwire.news (llama-server)                                                                       |
| Arch-Router-1.5B: modelo de 1,5 B parámetros de enrutado por preferencias, salida `{"route": "..."}`, ruta `other`, versión GGUF, licencia de Katanemo                                                                                                                                                                                            | huggingface.co/katanemo/Arch-Router-1.5B y su versión `.gguf`                                                                                                                         |
| RouteLLM: probabilidad de que gane el modelo fuerte, umbral calibrable; routers de factorización de matrices, BERT, LLM causal y ranking ponderado                                                                                                                                                                                                | github.com/lm-sys/RouteLLM; lmsys.org/blog/2024-07-01-routellm                                                                                                                        |
| Licencia de Katanemo (texto en el repositorio de Arch-Function-3B): uso comercial libre salvo empaquetado como parte de framework, proxy, middleware o gateway, que requiere licencia aparte                                                                                                                                                      | huggingface.co/katanemo/Arch-Function-3B (commit «Update License to relax commercial use»)                                                                                            |
| Enrutador de NVIDIA (Apache 2.0): intención con Qwen 1,7 B o red neuronal sobre CLIP                                                                                                                                                                                                                                                              | everydev.ai/tools/nvidia-llm-router                                                                                                                                                   |
| Clasificador de intención mmBERT multilingüe (Apache 2.0), 14 categorías fijas                                                                                                                                                                                                                                                                    | huggingface.co/vllm-sr/mmbert-intent-classifier-lora                                                                                                                                  |
| `arrea` 3.1.0 y 4.0.0: README con Leader, WorkerSupervisor, Worker, Monitor, `subscribe/0` sin filtro, `send_message` entre workers, telemetría de comunicación, políticas, pool, config global; versiones publicadas; sin `Arrea.Resource` en el README; README de 4.0.0 idéntico al de 3.1.0                                                    | hex.pm/packages/arrea/3.1.0/files; hex.pm/packages/arrea/4.0.0/files/README.md                                                                                                        |
| `snodo` 0.2.0 declara los protocolos MCP 2026-07-28, 2025-11-25 y 2025-06-18 con cliente, servidor, stdio y HTTP; `hermes_mcp` 0.14.1 existe y su README no declara 2026-07-28                                                                                                                                                                    | hex.pm/packages/snodo/0.2.0/files; hexdocs.pm/hermes_mcp                                                                                                                              |
| `sqlite-vec` busca por fuerza bruta (exacta); su índice «rescore» sigue siendo fuerza bruta sobre vectores cuantizados                                                                                                                                                                                                                            | github.com/asg017/sqlite-vec (pull 276)                                                                                                                                               |
| Ataques de redirección contra routers y defensas                                                                                                                                                                                                                                                                                                  | arxiv.org/abs/2501.01818; arxiv.org/abs/2601.21380                                                                                                                                    |
| MCP 2026-07-28: sin sesiones ni `initialize`; `Mcp-Method` y `Mcp-Name`; `resultType`; contexto de trazas en `_meta`; política de códigos de error y de ciclo de vida                                                                                                                                                                             | modelcontextprotocol.io/specification/2026-07-28/changelog; workos.com/blog/mcp-stateless-spec-2026-07-28                                                                             |
| `arrea` 3.0.0 lista `Bulkhead` y `CircuitBreaker`; `Arrea.Supervisor` con `:rest_for_one` y dos Registries globales                                                                                                                                                                                                                               | hex.pm/packages/arrea/3.0.0/files                                                                                                                                                     |
| El paquete `resiliency` ofrece `CircuitBreaker`, `Bulkhead`, `RateLimiter`, `BackoffRetry`, `SingleFlight`, `Hedged`                                                                                                                                                                                                                              | hexdocs.pm/resiliency                                                                                                                                                                 |
| `Arrea.Resource` **existe en `main` según la medición del dueño (D-13); su publicación en Hex está pendiente de G-28** (23 KB, tests, `main` desde 2026-10-10)                                                                                                                                                                                                                                                              | Confirmado por D-13; ratificado en Q-14 (r8)                                                                                                                                          |

### C.2 Puertas F0

Cada puerta es una pregunta binaria con test. **Las dos ramas ya están diseñadas**; el resultado solo elige cuál se aplica. La política de ejecución está en `docs/04-f0-puertas.md` §«Política de ejecución» y en `CIERRE-DP0.md` §3.

| Puerta | Pregunta y test                                                                                                                                                                                         | Si pasa (rama A)                                                     | Si falla (rama B)                                                                                                                                                    |
| ------ | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | -------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| G-01   | ¿`mix deps.tree` de las tres hermanas es limpio y sin ciclos?                                                                                                                                           | Sin cambios                                                          | Resolver con los mantenedores antes de F2                                                                                                                            |
| G-02   | ¿`Arrea.CircuitBreaker` admite umbrales por breaker y firma `call` compatible? Dos breakers con umbrales distintos                                                                                      | Umbrales por provider                                                | `circuit_breaker.*` global y documentado; o `resiliency` si gana la matriz (criterios: umbrales por instancia, single-flight, mantenimiento, licencia, dependencias) |
| G-03   | ¿Half-open con una sola sonda? N llamadas concurrentes, una sola sonda                                                                                                                                  | Se usa                                                               | Breaker mínimo propio tras `Gunther.Resilience`                                                                                                                      |
| G-04   | ¿Firmas de `Bulkhead` y `RateLimiter` (fallo rápido, peso por llamada)?                                                                                                                                 | `tpm` por peso                                                       | Solo `rpm`; warning de `Doctor`                                                                                                                                      |
| G-05   | ¿`Apero.Retry` admite predicado `retryable?` y `retry_after_ms`?                                                                                                                                        | Se usa directo                                                       | Envoltorio en `Gunther.Resilience`                                                                                                                                   |
| G-06   | ¿`SafeCommand` evita cargar la config del shell y bloquea `rm -rf /` y acepta `nvidia-smi --query-gpu=memory.free`? Latencia con un `.zshrc` lento                                                      | Sin cambios                                                          | Fijar `shell` y vaciar el entorno; ajustar reglas                                                                                                                    |
| G-06b  | ¿Firmas de `Trebejo.Proc` (`kill/2`, `lsof/1`, `list/0`)?                                                                                                                                               | Se usan                                                              | Capa fina propia dentro de `Gunther.Command`                                                                                                                         |
| G-07   | ¿`Apero.Conf` expone el parser de TOML necesario?                                                                                                                                                       | Se usa                                                               | Dependencia directa de un parser de TOML                                                                                                                             |
| G-08   | Matriz del `Spawner`: R1 a R8 sobre la línea base `Port` y candidatos (`muontrap`, `erlexec`, otros); ¿`Port` separa `stderr`?                                                                          | Candidato que cumple R1 a R8                                         | Línea base con las consecuencias de §3.4                                                                                                                             |
| G-09   | ¿Existe `llama-fit-params` en el binario fijado, con salida analizable y aborto con `-ngl` fijo?                                                                                                        | Método `fit`                                                         | `--fit on` en el arranque; reserva por fórmula o `vram_mb`                                                                                                           |
| G-10   | ¿Analiza el parser de §11.7 las salidas reales de CUDA, Vulkan, ROCm y Metal? Nombres de ROCm y Metal                                                                                                   | Detector `LlamaCpp`                                                  | Detector de fabricante por backend                                                                                                                                   |
| G-11   | ¿Entregan `nvidia-smi`, `rocm-smi`/`amd-smi` y Vulkan un id físico y la atribución por proceso?                                                                                                         | `physical_id` automático y `:per_process`                            | `[[devices.map]]` obligatorio y regla de quiescencia (§11.3)                                                                                                         |
| G-12   | ¿Acepta `llama-server` por petición esquema JSON o gramática, `logprobs`, tokenización, y reutiliza la caché de prompt con el mismo prefijo? ¿Qué rutas se exponen por el proxy?                        | Salida restringida nativa, confianza por `logprobs`, contador exacto | Salida validada con abstención, confianza ausente (⇒ abstención si `min_confidence` fijado), modo `approximate` calibrado                                            |
| G-13   | ¿Se lee la línea de comandos completa de un PID en Linux y macOS?                                                                                                                                       | Reconciliación con adopción                                          | Sin adopción: se mata por PID, puerto e identidad HTTP y se arranca limpio                                                                                           |
| G-14   | ¿Claves de cabecera GGUF (`head_count_kv`, `key_length`, `value_length`, `sliding_window`, `kv_lora_rank`) y tabla de tamaños de tipos de ggml? ¿`formula_kv_mib` = `kv_mib` informado por el servidor? | Fórmula válida por tipo                                              | Tipo marcado «no válido» y `fit` o `vram_mb`                                                                                                                         |
| G-15   | MCP: método de descubrimiento de versión, liveness, regla de framing de stdio en 2026-07-28                                                                                                             | Se usan                                                              | `tools/list` como liveness; framing por líneas con reensamblado                                                                                                      |
| G-16   | ¿Nombre `gunther` libre en hex.pm?                                                                                                                                                                      | Se publica                                                           | Otro nombre de paquete; el namespace no cambia                                                                                                                       |
| G-17   | ¿Etiquetas reales de `arrea` frente a la insignia 3.0.0?                                                                                                                                                | `~> 3.0`                                                             | Fijar la versión real                                                                                                                                                |
| G-18   | ¿La plantilla de decisión reproduce los ejemplos de la ficha del modelo (Arch-Router)?                                                                                                                  | Plantilla fija                                                       | Otra plantilla o otro modelo (Q-02)                                                                                                                                  |
| G-19   | ¿mTLS con huella fijada funciona con `:ssl`, `Finch` y `Bandit`? ¿Qué concede la distribución de Erlang a un nodo conectado?                                                                            | Diseño de §18                                                        | Capa propia de verificación con `verify_fun`                                                                                                                         |
| G-20   | ¿El proxy del agente de nodo reenvía SSE sin almacenar en búfer?                                                                                                                                        | Proxy mediado                                                        | Streaming por conexión directa con TLS del engine (requiere compilación con SSL)                                                                                     |
| G-21   | ¿Solapamiento de `Apero.Llm.Health` y `ConfigManager` con Gunther?                                                                                                                                      | Sin solape                                                           | Gunther no los usa                                                                                                                                                   |
| G-22   | Matriz de clientes HTTP/SSE de Elixir para LLM (criterios en §5.1)                                                                                                                                      | Se usa el ganador como transporte                                    | Cliente propio sobre `Finch`                                                                                                                                         |
| G-23   | ¿Hay herramienta de auditoría de dependencias adecuada además de `mix hex.audit`?                                                                                                                       | Se añade a CI                                                        | Solo `mix hex.audit`                                                                                                                                                 |
| G-24   | ¿Se carga `sqlite-vec` desde el binding de SQLite de Elixir y funcionan las escrituras concurrentes?                                                                                                    | Store SQLite con `sqlite-vec`                                        | Vectores en tabla normal puntuados en proceso (búsqueda exacta)                                                                                                      |
| G-25   | ¿Funcionan `pgvector` y `tsvector` desde el cliente de Postgres de Elixir con los tipos necesarios?                                                                                                     | Store Postgres                                                       | Postgres sin vectores nativos o fuera de v1                                                                                                                          |
| G-26   | ¿Está FTS5 disponible en el SQLite que usa el binding?                                                                                                                                                  | Léxico con FTS5                                                      | Léxico BM25 en proceso                                                                                                                                               |
| G-27   | SDK de MCP existentes en Elixir (`snodo`, `hermes_mcp`, otros): matriz con los criterios de G-22 más cobertura de la revisión 2026-07-28 y control de SSRF                                              | Se usa el ganador como base de los transportes                       | Transporte propio (D-35)                                                                                                                                             |
| G-28   | Código fuente de `Arrea.Leader`, `Worker`, `Monitor` y pool: ¿cumple R-A1 a R-A5? ¿Qué cambió en 4.0.0? ¿`Arrea.Resource` permite implementar `foreign` y `available` de §11.3 sin duplicar medidas?    | Arrea como anfitrión de miembros (F22); posible fachada del ledger   | Implementación propia de la coral (D-78) y propuestas A-1 a A-8 a su autor; ledger propio sigue                                                                      |
| G-29   | Caché de prompt por provider y por `llama-server`: ¿`cached_input` se informa? ¿Qué la invalida al cambiar de modelo o recargar el engine?                                                              | Afinidad con sentido (`prefer`)                                      | `router.affinity = off` únicamente                                                                                                                                   |
| G-30   | Corpus de continuidad: ¿`portable` retiene los hechos fijados igual que `resend` dentro de la tolerancia del operador?                                                                                  | `on_switch` en `portable` o `auto`                                   | `on_switch = resend`                                                                                                                                                 |
| G-31   | ¿El DSL de macros genera un `Plan` idéntico al de la vía de datos, con errores con línea, en Elixir 1.19?                                                                                               | DSL de Elixir                                                        | Solo datos y TOML hasta que pase                                                                                                                                     |

## Anexo D · Cambios de r8 a r9

### E.1 Cambios de contenido (SPEC)

| #     | Sección             | Cambio                                                                                                                                                                          |
| ----- | ------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| T-01  | §0.3, N-11          | El toolchain del proyecto pasa a **Erlang 28.5.0.7** y **Elixir 1.19.5-otp-28**, los mismos que `ropero`. Antes: «OTP 27 (CI en 27 y 28)» con Elixir 1.19, y 27.3 / 1.19.1 en el repositorio. |

**Por que** (instruccion del dueño del 2026-10-28): un solo toolchain para
todo el ecosistema `Lorenzo-SF`. Un numero de version distinto entre
repositorios hace que un fallo aparezca en un sitio y no en otro, y que el
tiempo perdido en diagnosticarlo no tenga relacion con el fallo.

**T-01 no cambia ninguna decision de diseno.** No toca D-nn, ni M-nn, ni
CE-nn, ni los AC de §19. Cambia el entorno en el que se ejecuta y se
verifica.

### E.2 Cambios en documentos que no son el SPEC

| #    | Documento                        | Cambio                                                                              |
| ---- | -------------------------------- | ----------------------------------------------------------------------------------- |
| T-02 | `.tool-versions`                 | `erlang 28.5.0.7` / `elixir 1.19.5-otp-28`                                          |
| T-03 | `.github/workflows/ci.yml`       | Todos los jobs usan OTP 28.5.0.7 y Elixir 1.19.5-otp-28; la matriz 27/28 desaparece |
| T-04 | `mix.exs`, `README.md`, `docs/`  | Referencias al fichero de la revision vigente: `SPEC-000-GUNTHER_r9.md`             |

### E.3 Correcciones editoriales posteriores a la aprobacion (2026-10-28)

Sin cambio de comportamiento; solicitadas por el dueño tras la revision de r8.
Se aplican **en r9**, no en r8: r8 se conserva como historico sin tocar.

| #    | Seccion                                     | Correccion                                                                                                                                   |
| ---- | ------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------- |
| E-01 | §6.8.1, §14                                 | Bloque TOML valido; precedencia aclarada: los vetos se acumulan y la privacidad se expresa como `veto`, no como `force`                    |
| E-02 | §1.4, §3.2, §11.3, §21, Anexos B y D, ADR 48 y 91 | `Arrea.Resource`: «existe en `main` segun la medicion del dueno (D-13); su publicacion en Hex esta pendiente de G-28» (regla de no-suposicion, §0.6) |
| E-03 | Cabecera, Anexo D.3                          | **Superada**: decia que F0 no estaba iniciado. F0 y F1 estan cerrados desde el 2026-10-28; r9 lo refleja en la cabecera y en §19        |
| E-04 | §19 (F0), Anexo C                            | Recuento de puertas: **32** (G-01 a G-31, con G-06b)                                                                                     |
| E-05 | Regla final                                 | Redaccion: «una fase se considera terminada por evidencia (sus AC ejecutados)», alineado con D-10                                            |
| E-06 | Raiz                                         | `LICENSE` con el texto oficial e integro de Apache-2.0 (verificado byte a byte contra `apache.org`); `NOTICE` con ano y titular; `.gitignore`; fuera los `.DS_Store` que estaban versionados |

## Anexo D · Cambios de r7 a r8

### D.1 Cambios de contenido (SPEC)

| #     | Sección                                                    | Cambio                                                                                                                          |
| ----- | ---------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------- |
| M-01  | §6.5, §6.8 (nueva §6.8.1), §6.10, §14.1, §14.2, §19        | Reglas por consumer (`[[consumers.<id>.rules]]`) con precedencia explícita. Tres filas nuevas en §6.10. Ampliación de AC de F4. |
| M-02  | §17                                                        | N-15 = 50 ms p99.                                                                                                               |
| M-03  | §0.2, §1.3, §1.5, §4.9, §5, §10.2, §22.1, §22.19, glosario | Renombrado colmena/mesa camilla/Hive/Voice → coral/Gunther.Coral; `:hive` como modalidad.                                       |
| M-04  | §1.4 (D-48, D-91), §3.2                                    | Q-14 cerrada: `Arrea.Resource` existe en `main` según la medición del dueño (D-13); su publicación en Hex está pendiente de G-28; ledger propio en v1; condición de fachada para G-28.                    |
| M-05  | §6.8 (nueva §6.8.1), §14.1, §14.2                          | Q-15 cerrada: los tres niveles de D-09.                                                                                         |
| M-06  | §1.3                                                       | Q-16 ratificada: taxonomía cerrada de skills.                                                                                   |
| M-07  | §21, §22.19                                                | Q-09 a Q-13 cerradas con los matices del dueño.                                                                                 |
| M-08  | §21                                                        | Q-01 a Q-08 ratificadas.                                                                                                        |
| CE-34 | §6.8.1, §14.1, §14.2, §19                                  | Detalle que faltaba en D-09 y D-87: sintaxis y precedencia de las reglas de consumer.                                           |

### D.2 Cambios en documentos que no son el SPEC

| #    | Documento                      | Cambio                                                                             |
| ---- | ------------------------------ | ---------------------------------------------------------------------------------- |
| M-09 | `docs/08-decisiones/README.md` | D-48 a D-92 marcadas `aceptada`.                                                   |
| M-10 | `docs/12-roadmap.md`           | Coral (F18-F22) marcada «aprobada, v1.1+, con G1-G9 en v1».                        |
| M-11 | `docs/13-registro-de-fases.md` | Fila DP0 rellena: fecha, AC ejecutados, desviaciones, decisiones nuevas (ninguna). |

### D.3 Estado del proyecto a fecha de r8

| Elemento     | Estado                                                                                               |
| ------------ | ---------------------------------------------------------------------------------------------------- |
| DP0          | **Cerrado** (`CIERRE-DP0.md`)                                                                        |
| F0           | **En ejecución** (política en `CIERRE-DP0.md` §3 y `docs/04-f0-puertas.md` §«Política de ejecución») |
| Q-01 a Q-16  | **Todas cerradas**                                                                                   |
| D-01 a D-92  | **Todas aceptadas** (con las notas de r7 y r8)                                                       |
| Código       | Sin publicar; proyecto Mix pendiente de crear                                                        |
| Próximo hito | Cerrar las puertas que bloquean F1 (G-01, G-05, G-07, G-16, G-17, G-21, G-23) y abrir F1 en paralelo |

---

## Regla final

**Una fase se considera terminada por evidencia (sus AC ejecutados), no por volumen de archivos ni por cantidad de código.** El SPEC define qué se construye; las instrucciones, cómo se trabaja; el plan, qué falta y cómo se comprueba. Cuando una decisión se apruebe, registrarla, actualizar las tareas afectadas y continuar sin reabrirla innecesariamente.

**Estado formal a fecha de r9:** la especificación está **congelada** salvo que una puerta de F0 obligue a aplicar su rama B (que también está escrita) o que una revisión `rN+1` con ADR y aprobación del dueño la modifique. F0 y F1 están cerrados (2026-10-28) y sus ramas B (G-05, G-06, G-17) ya están aplicadas.
