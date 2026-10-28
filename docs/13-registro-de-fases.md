# Registro de fases y puertas

Se rellena al cerrar cada fase y cada puerta (formato en `04-f0-puertas.md`). Los tiempos medidos aquí son los únicos datos válidos para planificar fases posteriores.

## Fases

| Fase    | Inicio     | Fin            | AC ejecutados (enlace a la salida)                                                                                 | Desviaciones | Decisiones nuevas                                                             |
| ------- | ---------- | -------------- | ------------------------------------------------------------------------------------------------------------------ | ------------ | ----------------------------------------------------------------------------- |
| **DP0** | 2026-10-20 | **2026-10-26** | Aprobación de D-48 a D-92 (45 ADRs); cierre de Q-01 a Q-16; política de F0 fijada. Ver `CIERRE-DP0.md` §1, §2 y §3 | Ninguna      | Ninguna (las notas de Q-14 y Q-15 se aplican en r8; no son decisiones nuevas) |
| **DP1** | pendiente  |                |                                                                                                                    |              |                                                                               |
| **DP2** | pendiente  |                |                                                                                                                    |              |                                                                               |
| **DP3** | pendiente  |                |                                                                                                                    |              |                                                                               |
| **DP4** | pendiente  |                |                                                                                                                    |              |                                                                               |
| **F0**  | 2026-10-27 | **2026-10-28** | 11 puertas medidas con scripts reproducibles (`probes/`) y la salida integra en `probes/output/` | Sin desviaciones | G-05, G-06 y G-17 fallan y tienen rama B aplicada |
| **F1**  | 2026-10-28 | **2026-10-28** | Nucleo, router (las seis capas), pipeline de §2.5. 10 AC de F1 ejecutados (`scripts/check_ac.sh docs/fases/F1.md`) y 10 comprobaciones de cierre (`scripts/check_phase.sh F1`) | Sin desviaciones del SPEC; un AC diferido a F3 con razon escrita | La capa `:rule` corta cuando opino (§6.10): `:embedding` y `:llm` no corren |
| **F2**  | 2026-10-28 | **en curso**    | Tipos de ggml, parser GGUF, formula de KV, ledger (A y B), Placer y detectores. 10 AC cumplidos y 2 pendientes (`scripts/check_ac.sh docs/fases/F2.md`); 11 comprobaciones de cierre en verde (`scripts/check_phase.sh F2`); **CI verde en `main`** (run `f836f58`, los seis jobs en `success`) | `swa_full = true` es el defecto medido de llama.cpp: la formula de SWA es exacta, no una cota. Pide revision r10 | 2 AC bloqueados por hardware (salidas reales de `--list-devices` y `kv_mib` real) |
| **F3**  | 2026-10-29 |                | Nota de fase escrita (`docs/fases/F3.md`): AC de §19 y de §19.1 con su test, el AC diferido de F1 (F1-9), un AC bloqueado por hardware y los WP con sus dependencias. La cola de trabajo pasa a ser **derivada** (`scripts/next_task.sh`) | Sin desviaciones del SPEC | La nota de fase lleva **dos tablas** (WP de 3 celdas y AC de 4 celdas): las dos las lee el script de la cola, y una fila que no se reconoce hace fallar el script en vez de decidir sobre un estado inventado |
| **F4**  | pendiente  |                |                                                                                                                    |              |                                                                               |
| **F5**  | pendiente  |                |                                                                                                                    |              |                                                                               |
| **F6**  | pendiente  |                |                                                                                                                    |              |                                                                               |
| **F7**  | pendiente  |                |                                                                                                                    |              |                                                                               |
| **F8**  | pendiente  |                |                                                                                                                    |              |                                                                               |
| **F9**  | pendiente  |                |                                                                                                                    |              |                                                                               |
| **F10** | pendiente  |                |                                                                                                                    |              |                                                                               |
| **F11** | pendiente  |                |                                                                                                                    |              |                                                                               |
| **F12** | pendiente  |                |                                                                                                                    |              |                                                                               |
| **F13** | pendiente  |                |                                                                                                                    |              |                                                                               |
| **F14** | pendiente  |                |                                                                                                                    |              |                                                                               |
| **F15** | pendiente  |                |                                                                                                                    |              |                                                                               |
| **F16** | pendiente  |                |                                                                                                                    |              |                                                                               |
| **F18** | pendiente  |                |                                                                                                                    |              |                                                                               |
| **F19** | pendiente  |                |                                                                                                                    |              |                                                                               |
| **F20** | pendiente  |                |                                                                                                                    |              |                                                                               |
| **F21** | pendiente  |                |                                                                                                                    |              |                                                                               |
| **F22** | pendiente  |                |                                                                                                                    |              |                                                                               |

**Nota sobre F17.** La colmena, que era F17 en r5/r6, se sustituye por F18 a F22 (la coral) en r7 y r8. La numeración original se conserva como referencia histórica; no hay una F17 activa.

## Puertas

### Plantilla de una puerta

```
### G-nn — título
- Fecha:            AAAA-MM-DD
- Entorno:          SO, versión; Elixir/OTP; versiones exactas de las librerías o binarios
- Procedimiento:    pasos ejecutados (o enlace al script en probes/)
- Salida:           ruta del fichero con la salida íntegra
- Resultado:        PASA | FALLA | BLOQUEADA
- Rama aplicada:    A | B | B (provisional)
- Cambios en SPEC:  secciones tocadas (para la próxima revisión)
```

### Plantilla de una fase

```
### Fnn
- Inicio / Fin / AC ejecutados (enlace) / Desviaciones / Decisiones nuevas
```

## Resumen de puertas

| Puerta | Resultado     | Rama | Bloquea F1 |
| ------ | ------------- | ---- | ---------- |
| G-01   | PASA          | A    | Sí         |
| G-02   | PASA          | A    | No (F5)    |
| G-03   | PASA          | A    | No (F5)    |
| G-04   | PASA          | A    | No (F5)    |
| G-05   | FALLA         | B    | Sí         |
| G-16   | PASA          | A    | Sí         |
| G-17   | FALLA         | B    | Sí         |
| G-06   | FALLA         | B    | No         |
| G-07   | PASA          | A    | Sí         |
| G-21   | PASA          | A    | Sí         |
| G-23   | PASA          | A    | Sí         |

Las puertas que bloquean F1 (G-01, G-05, G-07, G-16, G-17, G-21, G-23) están
todas `PASA` o `FALLA` con rama B aplicada. **F1 puede abrirse.**

Las puertas G-08 a G-15, G-18 a G-20, G-22, G-24 a G-27 y G-29 a G-31 se
ejecutan en la fase que las consume (F2, F3, F6, F7, F11, F12, F15, F20, F21)
y se registran aqui al cerrarse. G-28 depende de F0-02 (el ledger propio ya
esta escrito: `lib/gunther/core/resource/ledger.ex`).

### G-01 — Dependencias sin ciclos

- Fecha:            2026-10-27
- Entorno:          Linux 5.x x86_64; Elixir 1.19.1 / OTP 28.0; arrea 3.1.0,
  apero 4.1.0, trebejo 2.1.0
- Procedimiento:    `probes/g01_deps.sh` (`mix deps.tree`, `mix deps.get
  --check-locked`, `mix hex.outdated`)
- Salida:           `probes/output/g01-2026-10-27.txt`
- Resultado:        PASA
- Rama aplicada:    A
- Cambios en SPEC:  ninguno

El arbol resuelve sin ciclos. `mix hex.outdated` informa `arrea 3.1.0 →
Update not possible`: no es un conflicto del arbol sino la restriccion de
`trebejo` (vease G-17).

### G-02 — Umbrales por breaker en Arrea.CircuitBreaker

- Fecha:            2026-10-27
- Entorno:          el de G-01; arrea 3.1.0
- Procedimiento:    `probes/g02_g04_resiliencia.sh`; dos breakers con umbrales
  distintos, ambos forzados a fallar
- Salida:           `probes/output/g02_g04-2026-10-27.txt`
- Resultado:        PASA
- Rama aplicada:    A
- Cambios en SPEC:  ninguno

`Arrea.CircuitBreaker.start_link/1` acepta `name:`, `threshold:` y `timeout:`
por breaker. Cada instancia abre con su propio umbral. El codigo de
`Arrea.CircuitBreaker` es identico entre 3.1.0 y 4.0.0: la rama B de G-17 no
afecta a esta puerta.

### G-03 — Half-open con una sola sonda

- Fecha:            2026-10-27
- Entorno:          el de G-01; arrea 3.1.0
- Procedimiento:    `probes/g02_g04_resiliencia.sh`; breaker abierto, espera
  del half-open y N llamadas concurrentes
- Salida:           `probes/output/g02_g04-2026-10-27.txt`
- Resultado:        PASA
- Rama aplicada:    A
- Cambios en SPEC:  ninguno

En half-open pasa una sola sonda; las demas reciben el rechazo del breaker.

### G-04 — Bulkhead y RateLimiter

- Fecha:            2026-10-27
- Entorno:          el de G-01; arrea 3.1.0
- Procedimiento:    `probes/g02_g04_resiliencia.sh`; bulkhead al limite
  (fallo rapido, sin encolar) y rate limiter con peso por llamada
- Salida:           `probes/output/g02_g04-2026-10-27.txt`
- Resultado:        PASA
- Rama aplicada:    A
- Cambios en SPEC:  ninguno

`Arrea.Bulkhead` expone `available/1`, `run/2` y `run/3`: falla rapido al
llenarse, sin encolar. `Arrea.RateLimiter` expone `allow?/1` y `allow?/2`:
la variante de aridad dos admite **peso** por llamada, que es lo que necesita
el `tpm` con `tokens_entrada + max_tokens_efectivo` (SPEC §2.5).

### G-05 — Apero.Retry

- Fecha:            2026-10-27
- Entorno:          el de G-01; apero 4.1.0
- Procedimiento:    `probes/g05_retry.sh` (lectura de la API publicada de
  `Apero.Retry`: predicado de reintentabilidad y `retry_after`)
- Salida:           `probes/output/g05-2026-10-27.txt`
- Resultado:        FALLA
- Rama aplicada:    B
- Cambios en SPEC:  §2.5 (capa 1): el retry con `retry_after_ms` se
  implementa en `Gunther.Resilience`; `Apero.Retry` no se usa. Sin cambios en
  el texto del SPEC: la rama B ya estaba prevista.

`Apero.Retry.with/2` **si** admite el predicado de reintentabilidad
(`retry_on: (result -> boolean())`), asi que esa mitad de la puerta pasa. Lo
que no existe es el **retraso que dicta el servicio**: el unico temporizador
de `Apero.Retry` es su propio backoff exponencial (`base_delay`, `max_delay`)
mas el jitter. No hay `retry_after` ni forma de que un 429 o un 503 con
`Retry-After: 120` espere esos 120 ms.

Sin el, un 429 se reintentaria antes de tiempo y el budget de reintentos se
gastaria sin esperar al servidor: el servidor seguiria denegando y la
llamada fallaria por el motivo equivocado (agotamiento del budget en vez de
limite de tasa).

La capa 1 de §2.5 la implementa `Gunther.Resilience`, que ya necesita su
propio budget (§2.5) y su tabla de error → accion; ahi el `retry_after_ms`
del error manda sobre el backoff.

### G-16 — Nombre en Hex

- Fecha:            2026-10-27
- Entorno:          consulta HTTP a la API de Hex
- Procedimiento:    `probes/g16_nombre_hex.sh`
- Salida:           `probes/output/g16-2026-10-27.txt`
- Resultado:        PASA
- Rama aplicada:    A
- Cambios en SPEC:  ninguno

`GET https://hex.pm/api/packages/gunther` responde **404**: el nombre esta
libre. El paquete se publicara con el nombre `gunther`.

### G-17 — Versiones reales de arrea

- Fecha:            2026-10-27
- Entorno:          consulta HTTP a la API de Hex y lectura del README de
  `Lorenzo-SF/arrea`
- Procedimiento:    `probes/g17_versiones_arrea.sh`
- Salida:           `probes/output/g17-2026-10-27.txt`
- Resultado:        FALLA
- Rama aplicada:    B
- Cambios en SPEC:  §3.2 y el requisito de `arrea`: la version fijada es
  `~> 3.1`, no `~> 4.0`. Sin cambios en el texto del SPEC: `~> 3.0` ya
  excluia 4.0.0 y la rama B solo concreta la version.

El README de `arrea` lleva la insignia `version-3.0.0` y Hex publica
**4.0.0**: la insignia va dos versiones por detras (3.0.0 publicado, 3.1.0
publicado, 4.0.0 publicado). La insignia no describe la version real.

**El conflicto que la puerta revela no es de arrea sino de trebejo.**
`trebejo` 2.1.0 (publicado) y su rama `main` exigen `arrea ~> 3.1`. Con
`arrea 4.0.0`Gunther no resolveria, porque `trebejo` obliga a bajar a 3.x.
Se fija `{:arrea, "~> 3.1"}`: cumple el `~> 3.0` del SPEC, es la unica
version resoluble junto a `trebejo` publicado, y `Arrea.CircuitBreaker` —la
primitiva que §2.5 necesita— es identica en 3.1.0 y 4.0.0.

El ledger de §11.3 es propio (D-48, ratificado en r8 con Q-14), asi que
`Arrea.Resource` —la unica novedad de 4.0.0— no se necesita en v1.

La insignia de `arrea` se corrige aparte, en el repositorio de `arrea`: es un
fallo del README, no de Gunther. Ver `issues/trebejo-arrea-4.md`.

### G-06 — SafeCommand

- Fecha:            2026-10-27
- Entorno:          el de G-01; trebejo 2.1.0
- Procedimiento:    `probes/g06_safecommand.sh` (firma `execute/3`, latencia,
  `rm -rf /`, `nvidia-smi` de solo lectura, y lectura del shell que se usa)
- Salida:           `probes/output/g06-2026-10-27.txt`
- Resultado:        FALLA
- Rama aplicada:    B
- Cambios en SPEC:  §3.4: el ejecutor es `Gunther.Command`, no
  `Trebejo.SafeCommand`. Sin cambios en el texto del SPEC: la rama B ya
  estaba prevista.

Falla en los dos criterios:

1. **Carga la configuracion del shell.** `Trebejo.SafeCommand.execute/3`
   delega en `Arrea.Command.execute/2`, que invoca `/bin/bash`; el stderr
   de todas las llamadas lo delata:
   `/bin/bash: line 1: /workspace/.home/.bashrc: No such file or directory`.
   La latencia de un comando trivial llega a **67 ms** frente a los 12 ms
   de una llamada equivalente que no carga el shell.
2. **No distingue el caso destructivo del de solo lectura.** La
   validacion de `SafeCommand` comprueba el **nombre** del comando contra
   un regex de caracteres seguros, no laBucket destructiva. `rm -rf /` pasa
   la validacion y se ejecuta; lo que lo detiene es el *failsafe* del
   propio `rm` de GNU ("`rm: it is dangerous to operate recursively on '/'`"),
   no Gunther ni `trebejo`. Un binario sin failsafe pasaria.

**La rama B es la que ya esta implementada.** `Gunther.Command` fuerza
`/bin/sh` sin cargar la config del shell y exige una **lista de permitidos**
antes de ejecutar: `rm -rf /` y `echo hola` devuelven `command_blocked` sin
llegar a lanzar nada. La lista de permitidos es el criterio de §3.4 (CE-18),
no una regla de "palabras peligrosas": un binario autorizado no puede hacer
daño, y uno no autorizado no se ejecuta ni aunque su nombre parezca inocuo.

**Firma que hay que respetar.** `Trebejo.SafeCommand.execute/3` espera el
**nombre** del comando y los **argumentos por separado**
(`execute("ls", ["-la"])`). Con `execute("ls -la", [])` el nombre entero no
pasa el regex y sale `:unsafe_command_name`: un error de uso parece un
comando peligroso. `Gunther.Command.run/3` tiene su propia firma
(`run(cmd, args, opts)`) y no sufre esa confusion.

### G-07 — TOML en Apero.Conf

- Fecha:            2026-10-27
- Entorno:          el de G-01; apero 4.1.0
- Procedimiento:    carga del ejemplo completo (`examples/gunther.example.toml`)
  con tablas anidadas y arrays de tablas
- Salida:           `probes/output/g07-2026-10-27.txt`
- Resultado:        PASA
- Rama aplicada:    A
- Cambios en SPEC:  ninguno

`Apero.Conf` acepta TOML con tablas anidadas y arrays de tablas. La rama B
(dependencia directa de un parser de TOML) no hace falta; `toml` queda como
dependencia indirecta de `apero`.

### G-21 — Apero.Llm

- Fecha:            2026-10-27
- Entorno:          el de G-01; apero 4.1.0
- Procedimiento:    `probes/g21_apero_llm.sh` (listado de los modulos que
  publica el paquete instalado)
- Salida:           `probes/output/g21-2026-10-27.txt`
- Resultado:        PASA
- Rama aplicada:    A
- Cambios en SPEC:  §3.2: la fila de `Apero.Llm` se retira de la tabla de
  dependencias; no hay modulo equivalente. Sin cambios en el resto del SPEC.

`Apero.Llm` **no existe** en apero 4.1.0. El paquete publica 50 modulos
(la lista completa esta en `probes/output/g21-2026-10-27.txt`): `Apero`,
`Apero.Application`, `Apero.Atomic.File`, `Apero.Backoff`, `Apero.Cache` (+
`Adapter`, `AdapterMonitor`, `Crypto`, `ETS`, `Supervisor`), `Apero.Clock`,
`Apero.Conf` (+ `Atom`, `Loader`, `Validator`), `Apero.Crypto` (+ `Cipher`,
`Hash`, `Key`, `Random`), `Apero.Env` (+ `Loader`, `Serializer`, `Store`),
`Apero.File` (+ `IO`, `Path`, `Tree`, `Watcher`), `Apero.Http` (+ `Adapter`,
`Adapter.Finch`, `Error`, `Finch`, `Method` y sus verbos, `Query`, `Request`,
`Response`), `Apero.Jsonl`, `Apero.Network`, `Apero.OS`, `Apero.Packages`,
`Apero.Proc`, `Apero.RateLimit` (+ `Bucket`) y `Apero.Retry`. No hay
`Apero.Llm`, ni `Apero.Llm.Health`, ni `Apero.Llm.ConfigManager`.

La puerta pasa con rama A **por la ausencia de solapamiento**: no hay nada
que solapar. El contrato de proveedor de Gunther (§3.4) es propio, y no se
descarta ninguna pieza de `apero` que si se usa.

**Nota para la proxima revision del SPEC.** La tabla de §3.2 evaluaba
`Apero.Llm.Health` y `Apero.Llm.ConfigManager` para la puerta G-21; la
puerta queda cerrada sinrama porque lo evaluado no existe. Si `apero` publica
un modulo de LLM en el futuro, G-21 se reabre (regla de `04-f0-puertas.md`:
una puerta cerrada solo se reabre con evidencia nueva).

### G-23 — Auditoria de dependencias

- Fecha:            2026-10-27
- Entorno:          el de G-01
- Procedimiento:    `mix deps.tree` (arbol completo) y revision de la
  licencia y el mantenimiento de cada dependencia directa
- Salida:           `probes/output/g01-2026-10-27.txt`
- Resultado:        PASA
- Rama aplicada:    A
- Cambios en SPEC:  ninguno

Arbol completo sin ciclos, sin arboles duplicados y sin dependencias
obligatorias que no aporten al alcance de v1. Las dependencias opcionales
(`plug`, `bandit`, `exqlite`, `postgrex`, `opentelemetry`) no se arrastran
al arbol de quien no las pide.

## Puertas bloqueantes para F1

Las puertas que bloquean F1 son G-01, G-05, G-07, G-16, G-17, G-21 y G-23 (`CIERRE-DP0.md` §3.4). F1 no se abre hasta que estén `PASA` o `BLOQUEADA con rama B aplicada`.

## Puertas que bloquean F5

G-02, G-03, G-04, G-05 (`CIERRE-DP0.md` §3.5, punto 9). No bloquean F1.

## F1 — Nucleo, router y resiliencia

- Inicio: 2026-10-28
- Fin: **2026-10-28** (cerrada)
- AC ejecutados: `mix test` (207 tests, 17 doctests, 2 properties, 0 fallos),
  `mix credo` (0 avisos), `mix dialyzer` (0 errores),
  `scripts/check_boundaries.sh` (OK), `scripts/doc_lint.sh` (OK)
- Desviaciones: ninguna
- Decisiones nuevas:
  - **La capa `:rule` corta cuando opino** (§6.10). Un `veto` o un `prefer`
    que casa resuelve la capa `:rule`, y `:embedding` y `:llm` no corren. La
    capa `:embedding` solo actua cuando no hay reglas que opinen.
  - **El veto y el force se aplican antes de la cache** y un hit no los
    salta: son deterministas y gratis, y un cambio de reglas cambia el hash
    del catalogo, que es parte de la clave (§6.5).
  - **El ranking cacheado es el final** (con la estrategia ya aplicada), para
    que un hit se sirva tal cual. Cuando `least_used` y `round_robin` dependan
    de un estado que cambia, el ranking a guardar tiene que ser el previo a
    la estrategia.
  - **Sin hash de catalogo no hay cache**: sin el no hay forma de invalidarla.

### La CI que estaba en rojo desde el principio

Los quince runs de CI hasta ahora **fallaron**, y el de `main` tambien. Dos
motivos, y ninguno habia saltado en local:

1. **`mix hex.build` reventaba.** El `files:` del paquete era un **mapa** y
   Hex espera una **lista**: la recorre con `String.contains?/2`, que recibe
   una lista de patrones. Con un mapa, `mix hex.build` muere con un
   `FunctionClauseError`. Ahora `files:` es una lista explicita, y el
   paquete lleva lo que dice y nada mas.
2. **Credo avisaba de mas de lo que yo contaba.** La verificacion local
   filtraba la salida por `[F]`, `[W]` y `[R]`, y se tragaba los avisos de
   prioridad `D` y `C`. La CI cuenta todos. Eran 18: variables sin usar con
   nombre incoherente, modulos anidados que debian aliasearse y un
   "TODOS" en un comentario que Credo lee como un TODO.

### Bugs reales encontrados y corregidos

1. **El hash del catalogo cubria el nombre de las reglas y no su contenido.**
   Cambiar el `target`, la `action` o el `when` de una regla dejaba el hash
   igual, y la cache seguia sirviendo un ranking que las reglas nuevas ya
   habian invalidado.
2. **`Catalog.reload/0` llamaba a un `handle_call` que no existia**: reventaba
   en vez de recargar. Ademas, el reload no vaciaba la cache de decisiones.
3. **`Config.Server.get/1` hacia `exit` si el servidor no estaba arrancado.**
   Ahora devuelve `nil`: la ausencia de configuracion es un `config_error`,
   no una excepcion.
4. **La cache de decisiones reventaba si el proceso no estaba arrancado.**
   Ahora un `miss` es un `miss`, no un fallo.
5. **El propio checker de fases se tragaaba sus propios fallos.** Tres
   comprobaciones usaban `return 1` dentro de un `eval`, y una usaba
   `exit 0`: un `return` o un `exit` dentro de un `eval` aborta la funcion
   que lo contiene, asi que la comprobacion **desaparecia del informe** en
   vez de marcarse FALLA, y el script salia con 0. Un verde falso con el
   informe a medias se lee como un verde, que es justo lo que el script
   existe para evitar. Las diez comprobaciones son ahora funciones que
   devuelven su codigo de salida, y `scripts/check_phase_selftest.sh`
   comprueba el checker con dobles: que en verde salgan las diez, y que
   una en rojo aparezca marcada como FALLA con las otras nueve en verde y
   el script exiting con 1.

### El cierre de la fase, y como se comprueba

Una fase **no** se da por cerrada porque el codigo compile y los tests
pasen. Se da por cerrada cuando las comprobaciones del cierre estan en
verde, y esas comprobaciones son ejecutables:

- **`scripts/check_ac.sh docs/fases/F1.md`**: ejecuta los AC de §19 (y los
  añadidos de r7 y r8) **por test**. Un AC esta cerrado cuando hay un test
  con ese nombre y el fichero entero pasa. Si un AC no tiene test, la fase
  no se cierra. Resultado: **10 cumplidos, 0 fallidos, 1 diferido**.
- **`scripts/check_phase.sh F1`**: las diez comprobaciones de calidad. Lo
  que el script no comprueba, no se puede afirmar. Resultado: **10 en verde**.

Las dos cosas que ese proceso destaparon:

1. **Un AC sin test no estaba cubierto.** El reensamblado de `:noeol` con
   mensajes mayores que el bufer de linea (CE-20) no tenia el test que el AC
   pide; lo tiene ahora. Y el consumer sin `default_model` tampoco.
2. **La puerta G6 (prefijo `[:gunther, :coral]` reservado) no era una
   reserva**: el puente aceptaba ese prefijo y lo emitia. Ahora **se niega a
   arrancar** con el, y el error es un valor.

### Lo que queda de F1

- El AC "chat/2 sin contexto se comporta igual que antes" esta **diferido a
  F3**, con la razon escrita en `docs/fases/F1.md`: `chat/2` no existe hasta
  F3. Diferir un AC no es cumplirlo.
- El estado de verificacion de los `DecisionSpec` connectedo al informe de
  evaluacion (§6.11) y el `Doctor.calibrate_router/2` son trabajo de F4. La
  mecanica de la capa `:llm` esta: lo que falta es el informe que la activa.

### El AC y el codigo: dos cosas que conviene tener escritas

- **El `reason` de un `force` o de un `veto`.** La enumeracion de §4.13
  incluye `:veto` y `:force`, y el codigo devolvia `:rule` para ambos: una
  desviacion de la letra del SPEC. **Esta cerrada**: el `reason` dice **por
  que** se eligio el destino (`:veto` seguridad, `:force` operador, `:rule`
  un `prefer` que solo pondera) y `layers_ran` sigue diciendo **que capas**
  corrieron. Son dos cosas distintas.
- **El ranking que se cachea.** El §6.5 dice "el ranking puro"; el codigo
  guarda el ranking **final** (con la estrategia ya aplicada) para que un hit
  se sirva tal cual. Cuando `least_used` y `round_robin` dependan de un
  estado que cambia, el ranking a guardar tiene que ser el previo a la
  estrategia.


---

## La CI: de muerta a verde (2026-10-28)

La CI del repositorio llevaba dias **sin arrancar**: todos los jobs nacian con
`steps: 0` y sin runner, y morian en 2-3 segundos. No era un fallo de codigo:
el commit rojo era identico byte a byte al verde anterior, relanzar el run
verde tambien fallaba, y el estado de GitHub era "All Systems Operational".

La causa era la **cuota de minutos de Actions**, que un repositorio
**privado** consume. Y la solucion no es esperar al reset del mes: **un
repositorio publico no consume minutos**. El repositorio, que ya estaba
preparado para ser publico (Apache-2.0 con `NOTICE`, `SECURITY.md`, y un
`CONTRIBUTING.md` que no acepta PRs de terceros), paso a publico el
2026-10-28, tras auditar el contenido: sin secretos, sin tokens, sin datos
privados.

Al pasar a publico, la CI arranco y salio **verde a la primera**. El unico
ajuste que hizo falta fue `bandit` de 1.14.0 a 1.14.1, por el aviso HIGH
EEF-CVE-2026-116078 (el job `audit` lo cazaba).

De paso, el workflow gano `workflow_dispatch`: relanzar la CI a mano es
justo lo que hace falta cuando el fallo es de la cuenta y no del codigo,
porque los jobs sin runner solo se ven relanzando.

**Medicion del 2026-10-28** (`f836f58`): 196 doctests, 5 properties, 413
tests, 0 fallos; Credo 0; Dialyzer 0; fronteras y lint de documento en verde;
las once comprobaciones de `scripts/check_phase.sh F2` en verde; y la CI de
GitHub con los seis jobs en `success`.

---

## La cola de trabajo: derivada, no escrita a mano (2026-10-29)

La primera sesion del Nemotron 3.5 Lightning como *coder* leyo el SPEC,
exploro el repositorio, corrio todas las comprobaciones (suite, Credo,
Dialyzer y las puertas de F1 y F2) y respondio con un resumen de ocho
minutos. **Cero ficheros escritos.** Concluyo que la implementacion estaba
completa.

Lo que habia hecho estaba bien. El problema era que **verificar no era la
tarea**, y la causa estaba en el prompt: describia el metodo pero no decia
que hacer, y decia «elige una tarea». Sin un criterio de terminacion, un
modelo optimiza por **poder contestar un resumen**, que es lo que se le da
mejor.

La leccion es transversal a cualquier agente: un prompt necesita **tarea**
(en imperativo), **lo que no es un entregable** (dicho) y **criterio de
terminacion** (un fichero nuevo o un commit).

### La solucion: la cola esta en el repositorio

`scripts/next_task.sh` dice que WP toca, y lo **deriva** de tres fuentes que
no se pueden desincronizar entre si:

1. **Que fase toca**: el orden recomendado del plan (`docs/01`) y las fases
   **cerradas** del registro (las que tienen fecha de fin; «en curso» no es
   una fecha).
2. **Que WP hay**: el plan, seccion 4.
3. **Que WP toca**: el primero cuyos AC **no** estan todos en verde, segun
   `scripts/check_ac.sh --machine`, que **ejecuta los tests de verdad**.

Una lista escrita a mano se pudre en silencio: nadie la actualiza, y el
modelo trabaja sobre una lista que ya no describe el repositorio. Aqui la
lista **es** el repositorio.

### Lo que hace falta para que la cola se pueda derivar

La nota de fase lleva **dos tablas**, y se distinguen por el **numero de
celdas**, no por el nombre del identificador (un AC `F4-12` y un WP `F4-12`
pueden llamarse igual):

| Tabla | Celdas | Contenido |
| ----- | ------ | --------- |
| Los WP de la fase | 3 | `WP`, `Dependencias`, `AC que cierra` |
| Los AC y donde se verifican | 4 | `#`, `AC`, `Test que lo verifica`, `En` |

**Una fila que no se reconoce hace fallar el script.** Es mejor que se quede
sin saber que hacer a que decida sobre un estado inventado: un checker con
OK falso es peor que no tener checker.

### El AC diferido no se pierde

`F1-9` («`chat/2` sin contexto se comporta igual que antes») estaba
diferido a F3 desde la nota de F1. Ahora esta **escrito en la nota de F3**,
con su test, y `check_ac.sh docs/fases/F3.md F3` lo comprueba. Diferir un AC
no es cumplirlo, pero tampoco es olvidarlo.

### Dos niveles de estado

`BLOQUEADA` (depende del hardware) y `PENDIENTE` (el trabajo no esta hecho)
cuentan igual en el informe de `check_ac.sh` (los dos son AC sin cumplir), pero
en la salida `--machine` se distinguen, porque **solo el segundo es trabajo
del coder**. Sin esa distincion, un WP cuyo unico AC pendiente es de hardware
no terminaria nunca, y el coder recibiria la misma tarea una sesion tras otra.

### La puerta de la fase

`scripts/check_phase.sh` tiene ahora una comprobacion mas: **la cola de
trabajo se puede derivar del repositorio**. Si `next_task.sh` no da una tarea
legible, la fase no se puede cerrar: el coder se quedaria parado.
