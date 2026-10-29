# Planificación del relevo: el modelo *coder*

**Estado a 2026-10-29.** Este documento es el plan de traspaso del desarrollo de
Gunther a un modelo que hace de *coder*: qué hereda, cómo trabaja, qué
comprueba, hasta dónde decide y cómo se revisa lo que deja.

El contrato corto que el modelo lee al arrancar está en `AGENTS.md` (raíz del
repositorio). Este documento es el largo: el porqué de cada cosa.

---

## 0. Para qué existe

Gunther tiene dueño y un plan de fases, pero el trabajo se ha hecho en
sesiones cortas con un asistente que tiene acceso a red, GitHub y a las
hermanas `arrea`, `apero` y `trebejo`. El dueño quiere **continuar el
desarrollo con un modelo local** (Nemotron 3.5 Lightning 30B-A3B) que actúe
como *coder*, y quiere poder revisar después si lo está haciendo bien.

Eso impone tres cosas que este documento fija:

1. **El estado real, medido.** El coder arranca sabiendo exactamente qué está
   hecho, qué está a medias y qué está bloqueado, para no repetir trabajo ni
   inventar que algo funciona.
2. **Un método que un modelo de 30B pueda sostener.** El ritmo de un ciclo
   TDD completo, con sus comprobaciones, es lo que mantiene la calidad; sin
   él, un modelo grande produce mucho código que nadie ha ejecutado.
3. **Un criterio de revisión verificable.** Lo que hará el dueño —o el
   asistente— al revisar el trabajo del coder son checks concretos, no
   impresiones.

### 0.1 Un aviso antes de nada: hay dos proyectos con nombre parecido

En la cuenta de GitHub hay **dos** repositorios que se parecen:

| Repo | Qué es |
| ---- | ------ |
| **`Lorenzo-SF/Gunther`** | **Este.** El framework con SPEC propio (`SPEC-000-GUNTHER_r9.md`), ADRs D-01 a D-92 y las fases F0 a F22. |
| `Lorenzo-SF/candil` | Una librería anterior de inferencia LLM: 133 módulos, MCP, RAG, gateway, agentes, mesa camilla, router de tres capas. |

**No son el mismo código.** Este proyecto **no tiene** MCP, RAG, agentes ni mesa
camilla: son fases futuras (F7, F13, F11, F12). Si una búsqueda, un `grep` o un
recuerdo traen el otro, es ruido. Todo lo que dice este documento se refiere
al primero.

---

## 1. El relevo: el estado real

### 1.1 Qué está hecho

| Fase | Estado | Qué significa |
| ---- | ------ | -------------- |
| DP0 | Cerrada | El dueño aprobó D-48 a D-92 y respondió §21. Está en `CIERRE-DP0.md`. |
| F0 | **Cerrada** | Verificación: 11 puertas medidas con scripts reproducibles en `probes/`. Cinco puertas tienen rama B propia. |
| F1 | **Cerrada** | Núcleo: config, validador, catálogo, errores, comando, caché, cancelación, telemetría, contexto, decisión. |
| F2 | **En curso** | Recursos: tipos de ggml, parser GGUF, fórmula de KV, ledger, placer, colocación por nodo, detectores y calibración de overhead. |

**Las cifras exactas no están aquí, y a propósito.** El número de tests, de
doctests y de AC cumplidos se lee en `docs/13-registro-de-fases.md` y en la
salida de los scripts. Una cifra escrita en un documento de planificación es
una cifra que se queda vieja, y una cifra vieja es peor que ninguna: el
modelo contesta con datos de un repo que ya no es este.

### 1.2 Qué falta dentro de F2

De los doce AC de F2, **diez están cumplidos y ejecutados**. Los dos que
quedan dependen de una máquina con GPU y de una grabación real:

| AC | Qué falta | Por qué |
| -- | --------- | ------- |
| F2-AC1 | La salida **grabada** de `llama-server --list-devices` de CUDA, Vulkan, ROCm y Metal. | No hay GPU en el entorno de trabajo. |
| F2-AC6 | La comparación del `kv_mib` calculado por Gunther con el que **informa** `llama-server` al cargar. | Idem: hace falta el motor con un modelo real. |

Todo lo demás de F2 está implementado, probado y documentado en
`docs/fases/F2.md`. El script `probes/f2_datos.sh` recoge en una sola pasada
todo lo que hace falta para cerrar esos dos AC: la salida del motor, los
valores crudos del GGUF, el `kv_mib` que informa el servidor y la comparación
con la fórmula de Gunther.

### 1.3 Lo que estaba bloqueado, y como se resolvio

**La CI de GitHub no arrancaba.** Todos los jobs nacían con `steps: 0`,
`runner_name: ''` y `run_queued_at: None`, y los logs daban 404. Se comprobó
que el commit rojo era idéntico byte a byte al verde anterior, que relanzar el
run verde también fallaba, y que el estado de GitHub era "All Systems
Operational": era la **cuota de minutos de Actions agotada** (un repo
privado los consume), no un fallo de código.

**La solución fue la de raíz: el repositorio pasa a público.** Un repo
público **no consume minutos**, así que la CI volvió a funcionar sin tocar
nada de la facturación. Antes se auditó el contenido entero (sin secretos, sin
tokens, sin datos privados). De paso el workflow ganó `workflow_dispatch`:
relanzar la CI a mano es justo lo que hace falta cuando el fallo es de la
cuenta y no del código.

**Estado a 2026-10-28**: la CI corre y está **verde** (los seis jobs en
`success`). La regla para el coder:

> El trabajo se deja en una rama, con su PR abierto y su nota de fase. El
> **merge** es del dueño. Lo que sí puede hacer el coder es **comprobar la
> CI** y decir si está verde.

Escribir código, probarlo en local, abrir el PR y **leer el resultado de la
CI** está permitido. Declarar una fase cerrada, no: la firma es del dueño.

---

## 2. El modelo y su stack

### 2.1 Qué es el Nemotron 3.5 Lightning 30B-A3B

Datos del modelo card y de la documentación de NVIDIA (agosto de 2026):

| Propiedad | Valor |
| --------- | ----- |
| Parámetros | 30 000 millones en total (31 577 937 344 exactos); **3 000 millones activos** por pasada |
| Arquitectura | MoE híbrido: **Mamba-2** + Transformer, con una capa de **MTP** (Multi-Token Prediction) |
| Capas / dimensión oculta | 52 / 2688 |
| Expertos | 128 enrutados (top-6) + 1 compartido |
| Contexto | hasta 1 000 000 de tokens (embeddings de posición: 262 144) |
| Muestreo recomendado | `temperature` 1.0, `top_p` 0.95 |
| Variantes | BF16 (instruct), NVFP4, Base-BF16 |
| Licencia | OpenMDW 1.1 |

Publicaciones medidas por NVIDIA: SWE-Bench Verified 52,20 · GPQA Diamond
76,45 · Tau2 Telecom 59,65 · IFBench 72,00 · **AA-LCR 52,38** · RULER-v1 (1M)
91,52.

### 2.2 Qué implica para el trabajo

Cuatro consecuencias, cada una de ellas una regla de método:

**a) Es un modelo de agentes de larga duración, pero pierde el hilo en el
contexto largo.** AA-LCR 52,38 con RULER-v1 al 91,52 dice exactamente eso:
recupera bien una aguja en un contexto enorme, pero a 30B activos pierde la
respuesta a mitad de una conversación larga. *Regla:* **una tarea por
sesión**, y el estado vive **en ficheros** (nota de fase, CHANGELOG, commits),
nunca en el hilo de la conversación. El modelo debe poder reentrar en el
trabajo leyendo el repositorio, sin depender de lo que se dijo antes.

**b) Es un caso real de la ruta SSM del cálculo de KV.** Gunther calcula el
tamaño de la KV cache según el tipo de atención (MHA, GQA, MLA, SSM) y el
SPEC §11.5 tiene una rama SSM que hoy solo se prueba con datos inventados. Un
Nemotron real es el fixture más honesto que existe para esa rama: es un
Mamba-2 con 52 bloques. Cuando haya GPU, el GGUF del Nemotron da los valores
del mundo real para esa fórmula.

**c) El Nemotron trae MTP, y el MTP tiene una trampa de verdad.** Los GGUFs
públicos del Nemotron vienen en dos formas: con la capa MTP **embebida**
(53 bloques, `nextn_predict_layers = 1`) o **suelta**. Con el motor `atomic`
que usa `ropero`, la forma embebida **no carga**: el cargador espera 417
tensores y el modelo crea 408, porque `nemotron_h_moe` no tiene rama MTP. La
forma que funciona son 52 bloques (`nextn = 0`): el `MXFP4_MOE` de `vcruz305`
(17,98 GB, 401 tensores) o el `NVFP4` de `tngtech` (18,49 GB, 52 bloques) con
el `mtp-*.gguf` suelto aparte. Un GGUF con MTP embebida muere con
`wrong number of tensors; expected 417, got 408`.

**d) El NVFP4 de llama.cpp sin parchear "habla cosas raras".** El cuantizador de
llama.cpp no tiene rama para NVFP4: mete a 4 bits también la atención, el
Mamba y el embedding, el estado recurrente se desincroniza y la salida se
vuelve texto de razonamiento degenerado. La variante que funciona es
`MXFP4_MOE` (solo los expertos en MXFP4, el resto en F16) o el motor parcheado
—en `atomic`, `src/llama-quant.cpp` con una rama que manda `ne[2] > 1` a
NVFP4 y el resto a Q8_0.

### 2.2 bis El modo de razonamiento, decidido

El Nemotron **razona por defecto**: su `chat_template.jinja` hace
`enable_thinking if enable_thinking is defined else True`. El modo es
**binario** (si/no), no una escala, y NVIDIA pide `temperature = 0.6` con
`top_p = 0.95` en modo thinking.

**Para este papel, thinking ON.** El trabajo de un coder (leer un SPEC,
escribir un test que falla, cazar un bug invertido) *es* razonamiento; sin
el, el modelo escribe el test, no lo ejecuta y afirma que pasa.

La configuración completa, con el diagnóstico de los cinco fallos que tenía
(el que de verdad duele es que no se pasaba el `chat_template.jinja`, con lo
cual el servidor usaba el template de la comunidad y el modelo no razonaba
bien), esta en
[`16-nemotron-coder.md`](16-nemotron-coder.md). El prompt que se le pasa al
modelo, en [`17-prompt-del-coder.md`](17-prompt-del-coder.md).

### 2.3 El entorno que necesita

El coder trabaja sobre el repositorio, así que necesita el toolchain
**exacto** del proyecto, que es el mismo que usa `ropero`:

```
Erlang 28.5.0.7
Elixir 1.19.5-otp-28
```

Se comprueba así, y si no coincide, **no se empieza**:

```bash
elixir --version
```

Las dos versiones tienen que ser esas. El repositorio tiene `.tool-versions`
con las dos, para `asdf` o `mise`.

Y el servicio de inference:

- **ropero** levanta el `llama-server` con el GGUF del Nemotron y expone una
  API compatible con OpenAI en `http://127.0.0.1:<puerto>/v1`.
- El **runtime de agentic coding** (opencode v2, mcode o Pi) es el que
  habla con ese servidor. El id del modelo lo decide el servidor: se lee de
  `/v1/models` del propio `llama-server`. **Nunca inventar el nombre del
  modelo.**
- En opencode v2 el flag `--auto` (autoaprobar permisos) es **global** y va
  **antes** del subcomando: `opencode --auto run --model <provider>/<modelo>
  --agent build`. Sin él, una configuración con `"shell": "ask"` se queda
  colgada en headless, porque nadie contesta el permiso.
- Para un trabajo largo conviene un `--cwd` sobre el repositorio y
  `--permission full` (o `smart`), y un volcado de la sesión en JSON: es lo
  que permite revisar después qué hizo el modelo.

---

## 3. El método: el ciclo de trabajo

### 3.1 El ciclo, paso a paso

Cada paquete de trabajo (WP) es un ciclo. El ciclo **no se salta pasos**, y en
particular el paso 2 no se salta nunca.

**Paso 1 — Leer el contrato.**
La sección del SPEC que cubre el WP, los AC de §19 que le tocan, el ADR
relacionado y la nota de fase. Si el código necesita un comportamiento que el
SPEC no dice, **eso es una pregunta para el dueño**, no una decisión del
coder: se para, se anota y se sigue con lo demás.

**Paso 2 — El test rojo.**
Se escribe el test del AC **antes** de la implementación, y se ve fallar.
Un test que pasa sin código que lo justifique no es un test: es decorado.
El orden de los commits deja esta prueba: primero el test, después la
implementación.

**Paso 3 — Implementación mínima.**
Lo mínimo que hace pasar el test. Ni una línea de más. Lo que sobra se
elimina en el refactor, o se justifica en la nota de fase.

**Paso 4 — Formato y suite.**

```bash
mix format && mix test
```

**Paso 5 — Refactor.**
Con los checks en verde. Aquí es donde se paga la deuda: un módulo con tres
responsabilidades se parte aquí, con los tests verdes en todo momento.

**Paso 6 — Las comprobaciones.**
Las seis de la §3.2, más las dos puertas de fase. **Un check en rojo para
el trabajo**: se arregla o se documenta por qué no puede arreglarse, pero no
se deja en rojo "para después".

**Paso 7 — El registro.**
Nota de fase (AC ejecutados, desviaciones, bugs encontrados), `CHANGELOG.md`,
`docs/13-registro-de-fases.md`.

**Paso 8 — El commit.**

```
feat(F3-04): el transporte HTTP con cancelacion y contrapresion
```

Con prefijo (`feat`, `fix`, `docs`, `test`, `refactor`, `chore`), el
identificador del WP, y **fecha entre las 20:00 y las 02:00 Europe/Berlin,
en día laborable**.

```bash
export GIT_AUTHOR_DATE="2026-10-29T21:30:00+02:00"
export GIT_COMMITTER_DATE="$GIT_AUTHOR_DATE"
```

**Paso 9 — El PR.**
Un PR por rama, con el orden de merge declarado si hay varios. El merge es
**squash**, que es el estilo del ecosistema (`arrea` deja el `(#33)` del PR en
el commit). Después de cada merge se verifica `main` con la suite completa, y
las ramas que quedan se actualizan con `main` (merge, nunca rebase de un PR
abierto).

### 3.2 Las comprobaciones y qué significa cada una

| Comprobación | Qué mira | Por qué importa |
| ------------- | ------- | --------------- |
| `mix format --check-formatted` | El formato. | El CI falla aquí antes que en cualquier otro sitio. |
| `mix compile --force --warnings-as-errors` | Avisos del compilador. | Un aviso en Elixir 1.19 suele ser un `@spec` que no casa. |
| `mix credo --strict --format=oneline` | Avisos de Credo de **todas** las prioridades. | Sin `--strict` y sin contar los avisos, el check **nunca ve nada**. |
| `mix dialyzer` | Tipos. | El type checker de Elixir 1.19 y Dialyzer pillan lo que los tests no ven. |
| `mix test` | La suite. | Todo lo que hay. El número exacto se ve en la salida. |
| `bash scripts/check_boundaries.sh` | Las fronteras de §3.4 y §3.6. | `Gunther.Command` como única puerta de ejecución. |
| `bash scripts/doc_lint.sh` | El texto normativo. | Prohíbe «suponer», «estimar» y «aproximadamente». |
| `bash scripts/check_ac.sh docs/fases/F3.md F3` | Los AC de la fase, uno a uno. | Un AC sin test es un AC sin cumplir. |
| `bash scripts/check_phase.sh F3` | Todas las comprobaciones del cierre. | La puerta de la fase. |

`check_phase.sh` corre la suite **tres veces seguidas**: una suite que pasa
una vez y falla otra es una suite intermitente, y una suite intermitente es un
fallo aunque la siguiente vez salga verde.

### 3.3 El registro del trabajo

Todo lo que el coder hace deja rastro en cuatro sitios, y los cuatro se
revisan:

1. **`docs/fases/Fnn.md`** — la nota de fase: AC con su test, desviaciones del
   SPEC, bugs encontrados y lo que queda. Es el documento que se lee para
   entender qué se hizo y por qué.
2. **`docs/13-registro-de-fases.md`** — el registro vivo: fechas, AC
   ejecutados, desviaciones, decisiones nuevas.
3. **`CHANGELOG.md`** — lo que le importa a quien usa la librería.
4. **Los commits** — el porqué está en el mensaje, no en el diff. Un commit
   que dice *qué* y no *por qué* obliga a reconstruir el contexto a quien lo lea.

---

## 4. La cola

### 4.1 La cola está en el repositorio, no en este documento

**La cola no es una lista escrita a mano.** Una lista escrita a mano se pudre en
silencio: nadie la actualiza, el modelo trabaja sobre una lista que ya no
describe el repositorio, y el síntoma sale cuando el trabajo ya está hecho
mal. Es el mismo fallo que una lista de checkboxes, con el añadido de que
el modelo no se queja: sigue adelante con confianza.

La cola se **deriva**:

```bash
bash scripts/next_task.sh
```

De tres fuentes que ya existen y que no se pueden desincronizar entre sí:

| Fuente | Qué dice |
| ------ | -------- |
| `docs/01-plan-de-desarrollo.md` | Qué fases hay, en qué orden y qué WP tiene cada una |
| `docs/13-registro-de-fases.md` | Qué fases están cerradas (las que tienen **fecha** de fin) |
| `docs/fases/Fnn.md` | Qué AC hay, con su test, y qué AC cierra cada WP |

El script sale con:

- **0** y la tarea: hay trabajo.
- **1** y `no queda trabajo`: la fase está hecha (lo que queda depende del
  hardware, y se dice qué AC son).

**Un WP está terminado cuando todos sus AC están en verde**, y eso lo dice
`scripts/check_ac.sh --machine`, que **ejecuta los tests de verdad**. No hay
un "hecho" escrito a mano que se pueda quedar viejo.

### 4.2 Por qué el modelo no elige la tarea

Porque elegir es donde un modelo optimiza por lo que se le da mejor:
contestar. Con "elige una tarea", la tarea elegida fue "verificar que todo
está verde", que es un trabajo legítimo y no produce nada. Una sesión entera
se fue en correr checks y resumir, y no salió **ni un fichero**.

Con "ejecuta `scripts/next_task.sh` y haz lo que diga", la tarea viene de
fuera, es ejecutable, y el criterio de fin está escrito en el mismo sitio.

### 4.3 Los dos criterios de fin

| Nivel | Termina cuando | Quién lo firma |
| ----- | -------------- | -------------- |
| **Sesión** | El WP está hecho: el test de cada AC existe y su fichero pasa entero, `mix check.all` en verde, y hay un commit con el prefijo del WP. | El coder |
| **Fase** | La cola se agota (`next_task.sh` sale con 1) y `check_phase.sh` está en verde. | **El dueño** |

Una sesión = **un WP**. El Nemotron tiene AA-LCR 52,38: en un contexto largo
deja de encontrar lo que busca. Dos WP en una sesión es Context Rot.

### 4.4 Cómo se relanza, sesión a sesión

**`PROMPT.md` no se toca nunca más.** Es un fichero estable: el prompt
describe el método y el contrato, no el estado. Lo que cambia entre sesiones
es la tarea, y la tarea sale del repositorio.

```bash
scripts/coder.sh                # una sesión: un WP
scripts/coder.sh --bucle        # sesiones hasta que la cola se agote
scripts/coder.sh --bucle --max 5
```

El script hace, por sesión:

1. comprueba el toolchain (si no es el oficial, para: lo que el coder
   verifique no vale),
2. lee la cola (`scripts/next_task.sh --json`),
3. relanza al coder con **`PROMPT.md` entero**, el modelo con su ruta
   (`custom_provider:<id>/<model-id>`) y `--permission full`,
4. **mide si la sesión ha producido algo**: la firma del repositorio (HEAD y
   árbol) antes y después,
5. y comprueba que los AC siguen en verde.

**El paso 4 es el que detecta el fallo silencioso.** Si el repositorio no ha
cambiado, la sesión no ha producido nada, y el bucle **para** en vez de
seguir gastando. Con el prompt anterior ese fallo no se veía: el comando
salía con 0 y todo parecía bien.

El bucle se para solo en dos casos: la cola se ha agotado (la fase está
hecha, y le toca al dueño firmarla), o una sesión no ha producido nada.

### 4.5 Lo que la nota de fase tiene que llevar

Sin esto, la cola no se puede derivar:

| Tabla | Celdas | Identificador | Para qué |
| ----- | ------ | ------------- | -------- |
| Los WP de la fase | **3** (`WP`, `Dependencias`, `AC que cierra`) | `Fnn-nn` (`F3-04`) | Qué WP hay y qué cierra cada uno |
| Los AC y dónde se verifican | **4** (`#`, `AC`, `Test que lo verifica`, `En`) | `Fnn-ACn` (`F3-AC7`) | Qué AC hay y qué test lo verifica |

Se distinguen por el **número de celdas** y por la **forma del
identificador**. Antes solo por el número de celdas, y los identificadores
se parecían: el WP del plan era `F3-01` y el AC de la nota `F3-1`. Un modelo
que las confundía cerraba el AC equivocado y declaraba un WP terminado sin
haberlo hecho. Los WP **no** se renombran (`Fnn-nn`), porque el SPEC §19.2 los
cita (`F1-01`, `F4-03`, `F4-04`) y el SPEC es la ley; los AC sí (`Fnn-ACn`),
porque son ids locales de la nota.

Una fila que no se reconoce (un número de celdas que no es 3 ni 4, o un
identificador con la forma de la otra tabla) hace **fallar** el script. Es
mejor que se quede sin saber qué hacer a que decida sobre un estado
inventado.

### 4.6 F3 · Provider, WP a WP

F3 es la siguiente fase que **no depende de hardware**, y es la que da un
sistema de extremo a extremo sobre providers mock y cloud. El orden del plan
(§4 de `docs/01-plan-de-desarrollo.md`):

Los nueve WP de F3 y su contenido están en el plan
(`docs/01-plan-de-desarrollo.md` §4, `### F3 · Provider`). **No se copian
aquí**: la misma verdad en dos sitios se separa, y el plan es su sitio. El
mapeo WP → AC está en la nota de fase (`docs/fases/F3.md`), que es el otro
sitio, y tampoco se duplica.

Lo que sí se dice aquí, porque no está en ninguna de las dos: los WP que
**no** dependen de una GPU se pueden hacer enteros en local.

`F3-06` necesita un `llama-server`: sirve un mock que hable el protocolo, que
es lo que hace `Gunther.Provider.Mock`.

Un aviso de alcance: `Provider.Mock` y `ContractTest` **ya existen** de la
F1 (`lib/gunther/core/provider/mock.ex` y `contract_test.ex`). El WP no es
escribirlos: es **extenderlos** a lo que F3 pide, y eso hay que decirlo en la
nota de fase.

### 4.7 F2 — Lo que solo falta es hardware

Los dos AC pendientes de F2 no los puede cerrar el coder: necesitan una
máquina con GPU. Lo que sí puede hacer:

- Dejar `probes/f2_datos.sh` listo y explicado (ya lo está).
- Revisar el probe **leyendo el script**, no ejecutándolo, y corregir lo que
  se vea mal.
- Grabar los fixtures cuando llegue la salida real: `test/fixtures/list_devices/`
  con su cabecera obligatoria (fecha, SO, controlador, versión de la
  compilación). **Un fixture sin cabecera no se admite.**

Cuando haya GPU, la secuencia es: ejecutar el probe → pegar la salida →
comparar el `kv_mib` calculado con el que informa el motor → cerrar F2-AC1 y
F2-AC6 en la nota de fase → **el dueño** revisa y approve el cierre.

---

## 5. Las reglas que no se negocian

Están en `AGENTS.md`; aquí van con el porqué, que es lo que un modelo no
deduce:

- **Los errores son valores.** Una excepción en un camino de datos es un
  proceso muerto, no un error manejado. La tabla de §4.13 es el catálogo
  cerrado; un código fuera de ella es `:internal_error`.
- **`Gunther.Command` es la única puerta de ejecución.** `System.cmd` y
  `Port.open` en otro sitio escapesan de la allow-list, del timeout y de la
  cancelación, que es justo lo que F1 construyó.
- **Las hermana se tocan en cinco módulos.** `Arrea`, `Apero` y `Trebejo`
  quedan detrás de la frontera de §3.6.
- **Sin secretos** en el código, la documentación, los logs ni los commits.
  El repositorio va a ser público.
- **Procesos supervisados, esperas con plazo, buffers con tope.** (N-02, N-03,
  N-04.)
- **El type checker de Elixir 1.19 comprueba los argumentos contra el
  `@spec`.** `new(text: "x")` entrega una keyword list, no un mapa: un
  `Map.fetch!` sobre eso revienta en Dialyzer, no en el test.

---

## 6. Las trampas

Todas están medidas: cada una costó tiempo. Las que se repiten en cada sesión
son las que un modelo **no** detecta solo, porque a primera vista parecen lógicas.

### 6.1 En el código

1. **Las dos ramas de una decisión, invertidas.** En `Gunther.Memory.Server`
   el `put/3` comparaba la versión contra `nil` cuando **no** venía
   `:if_version`, y escribía sin comprobar cuando sí venía. Las dos ramas al
   revés: `put` no escribía **nunca**, ni la primera vez. El síntoma: un AC
   del SPEC que nadie cubre, porque su fase es posterior a la del código. *Cómo
   se caza:* el test del AC, escrito **antes** de la implementación.

2. **Un límite calculado con un valor que puede ser negativo.** El backoff
   del pipeline era `min(capped, remaining)`, y `remaining` es negativo si el
   plazo se agota *entre* el intento y el cálculo: `Process.sleep(-31)` →
   `FunctionClauseError`. **Intermitente**: no sale nunca en una corrida
   normal. *Cómo se caza:* un test **determinista** que agote el plazo a
   propósito.

3. **Una entrada malformada revienta en vez de bloquear.**
   `AllowList.resolve/2` hacía `entry[:name]` sobre la entrada: si no era un
   mapa, `FunctionClauseError` en vez de `:command_blocked`. Una lista de
   permitidos con una entrada rara **bloquea el comando**; no tumba el
   proceso.

4. **Un valor por defecto silencioso aguas arriba propaga datos falsos.**
   `Trebejo.OS` devuelve `:unknown` cuando su comando falla (no cuando la
   arquitectura es desconocida), y `cpu_count` devuelve los cores del BEAM.
   Los dos son **plausibles**, asi que el consumidor no tiene forma de
   saber que son mentira. Regla: si un valor puede significar dos cosas
   ("desconocido" y "no se pudo leer"), el que lo consume tiene que poder
   distinguirlas, o no debe consumirlo.
5. **Un doc que afirma lo contrario de lo que hace el código.** Medidos: el
   device de Metal se llama `MTL0`, no `Metal`; `q8_0` ocupa 1,0625 bytes por
   elemento, no 1; `swa_full` es `true` por defecto en llama.cpp master
   (`src/llama-context.cpp:4034`), así que la fórmula de la ventana deslizante
   es **exacta**, no una cota. Cuando el código y el doc discrepan, **decidir
   cuál miente antes de tocar el doc**: a veces el doc va bien y el código mal.

6. **Un default por clave ausente que no es un valor válido deja el sistema a
   medias.** El cuantizador de `freshisuis` devolvía "max" para cualquier
   clave ausente, el helper solo aceptaba cuatro valores, y el EPP se
   quedaba con el valor del modo anterior. *Regla:* un default se aplica en un
   **único punto**, y después se **verifica** que se aplicó.

### 6.2 En las comprobaciones

7. **Un doctest que no se ejecuta es un doctest muerto.** De 53 módulos del
   núcleo con doctests, solo 4 estaban declarados en un test: **157 doctests
   nunca se ejecutaron**. Y de los que sí se ejecutaban, **42 estaban mal**
   (hashes inventados, aritmética ingenua, factor 1000 de error, firmas que ya
   no existían). *La comprobación que lo evita:* un fichero central que
   declara **todos** los doctests (`test/gunther/doctests_test.exs`) más un
   check automático de que todo módulo con un `iex>` está en esa lista.

8. **Un check con OK falso es peor que no tener check.** En bash, un `return 1`
   dentro de un `eval` **retorna de la función que contiene el `eval`**: la
   comprobación **desaparece del informe** en vez de marcarse FALLA, y el
   script sale con 0. Un `exit 0` dentro del `eval` **mata el script entero**.
   *Regla:* una comprobación que puede fallar tiene que ser una **función
   propia** que devuelva su código de salida, nunca un predicado en una cadena
   evaluada. Y un script que imprime su informe al final **tiene que
   comprobar que el informe está completo**.

   **Contar los avisos con un filtro no es contar los avisos.** El check de
   Credo usaba `mix credo --format=oneline` **sin** `--strict`, y el formato
   por defecto de `--strict` no produce líneas `[`: el recuento salía
   siempre 0. Eso dejó la CI en rojo durante quince runs, con 18 avisos de
   Credo que el filtro `[F]|[W]|[R]` se tragaba. *Regla:* contar **todos** los
   avisos, de ninguna prioridad.

   Y el caso es el del propio repositorio: `mix check.all` y `mix check.static`
   usaban `credo` **sin** `--strict` y no incluían L4 (fronteras y lint de
   documento), aunque el README decía que eran cuatro capas. El alias era
   verde y no miraba casi nada. Ahora hay un test
   (`test/gunther/quality_gates_test.exs`) que fija lo que los aliases tienen
   que mirar, para que no se degrade en silencio.

9. **`grep` del nombre no prueba que exista el campo.** El `grep` de un
   identificador encuentra la *palabra*; para saber si existe el **campo** hay
   que seguir el **tipo**. Un checker que valida un esquema sobre una tabla
   inexistente da verde, porque el ORM genera el companion desde el modelo.

10. **Un AC sin test es un AC sin cumplir.** `scripts/check_ac.sh` distingue
    `BLOQUEADA` y `PENDIENTE` de cumplidos: un AC bloqueado **no cierra la
    fase**. La redacción de la fila importa: el patrón es `| F<nn>-<nn> |`.

### 6.3 En git y en el CI

11. **Staging explícito.** Antes de commitear, `git status --porcelain` y
    `git diff --cached --name-only`: no arrastrar trabajo de otros carriles.

12. **La fecha de los commits** va entre las 20:00 y las 02:00
    Europe/Berlin, en día laborable, y **del día que es**: antes de fecharlos,
    `date`. Una fecha de mañana rompe el historial y miente sobre la hora.
    Exportar `GIT_AUTHOR_DATE` **y** `GIT_COMMITTER_DATE` antes de cada
    commit.

13. **El merge es squash**, que es el estilo del ecosistema. Y tras cada
    merge, `main` se verifica y las ramas que quedan se actualizan.

14. **Una CI que no arranca no es un fallo de código.** Los jobs con
    `steps: 0` y `runner_name: ''` son la cuenta sin permisos de ejecución
    (minutos agotados o cargo fallido). Antes de culpar al código: comparar
    el `head_sha` con el de un run verde. Y la solución no es esperar al
    reset: **un repositorio público no consume minutos**. Eso se midió: con
    el repo privado la CI no arrancaba, y al pasarlo a publico arranco y
    salio verde a la primera.

15. **`mix hex.build` con `files:` como mapa no funciona**: la lista de
    ficheros del paquete es una **lista**. El paquete publicado no lleva
    `probes/`, `_build/`, `deps/` ni `.github/`.

### 6.4 En el entorno

16. **`String.normalize/2` no descompone** en esta build. Para diacríticos,
    tabla explícita.
17. **Un assert enorme rompe el formatter de ExUnit.** Para comprobar un
    texto largo, comparar **longitud y SHA-256**, no el texto entero.

### 6.4 En el prompt

18. **Un prompt de agente necesita TAREA y CRITERIO de TERMINACIÓN.** La
    primera sesión del Nemotron con el prompt anterior leyó el SPEC, exploró
    el repositorio, corrió **todas** las comprobaciones (la suite entera,
    Credo, Dialyzer y las puertas de F1 y F2) y respondió con un resumen de
    ocho minutos. **Cero ficheros escritos.** Concluyó: «the implementation is
    complete and all acceptance criteria for F1 have been verified and closed».

    Lo que había hecho estaba bien. El problema era que **verificar no era la
    tarea**, y la causa estaba en el prompt: describía el *método* (ciclo de
    TDD, comprobaciones, trampas) pero no decía **qué hacer**, y decía «elige
    una tarea». «Elige» es opcional; como «verificar» estaba en la lista de
    cosas que hacer, verificar le parecía un trabajo terminado.

    *Regla, y es transversal a cualquier agente:* sin un criterio de
    terminación, un modelo optimiza por **poder contestar un resumen**, que es
    lo que se le da mejor. Un prompt de agente necesita tres cosas:

    1. **La tarea, en imperativo.** No «elige una tarea», sino lo que tiene
       que hacer, con el contenido mínimo que tiene que tener.
    2. **Lo que NO es un entregable, dicho explícitamente.** Leer, correr
       checks y resumir es el **punto de partida**, no el resultado.
    3. **El criterio de terminación.** Al terminar hay un **fichero nuevo o un
       commit**. «Lo he verificado y todo está verde» no es un resumen del
       trabajo.

    Y la tarea no se escribe en el prompt: **se lee de un script**, que la
    deriva del repositorio. Ver §4.1.

---

## 7. Los límites: lo que el coder no decide solo

Estas decisiones **son del dueño**, y el coder las propone por escrito:

| Decisión | Cómo la propone el coder |
| -------- | ------------------------ |
| Cambiar el SPEC | Una entrada en la tabla del Anexo D de la revisión siguiente (`r10`), con el porqué. No edita el SPEC. |
| Cerrar una fase | Los AC ejecutados y verdes, la puerta en verde y la nota de fase al día. **El cierre lo hace el dueño.** |
| Mergear un PR | El PR con su orden de merge declarado y **el resultado de la CI a la vista**. **El merge lo hace el dueño.** |
| Cambiar el toolchain | Una propuesta escrita con el motivo. |
| Publicar en hex.pm | Nunca sin permiso explícito. |
| Tocar `arrea`, `apero` o `trebejo` | Un issue en `issues/`, justificado y planificado, como se hizo con `trebejo` y `arrea`. |
| Declarar algo «validado en hardware» | Solo con la medición real, grabada y con su cabecera. |
| Cambiar una puerta (G-nn) | Con la sonda reproducible en `probes/` y la salida íntegra en `probes/output/`. |

---

## 8. La revisión: cómo se comprueba su trabajo

Esta es la lista que se usa cuando el dueño pida revisar el trabajo del coder.
Son **checks binarios**, no impresiones. Cada uno se responde con un comando.

### 8.1 La calidad, primero

```bash
bash scripts/check_phase.sh F3
```

Todas las comprobaciones en verde. Si alguna está en rojo, el trabajo **no** se
revisa: primero se arregla.

### 8.2 Los AC, uno a uno

```bash
bash scripts/check_ac.sh docs/fases/F3.md F3
```

Cada AC con su test. Un AC en `PENDIENTE` o `BLOQUEADA` está bien declarado;
un AC **declarado cumplido sin test** es un AC que no existe.

### 8.3 El TDD, mirando el historial

```bash
git log --oneline --reverse main..<rama>
git show <commit-de-test> --stat
```

- ¿El test llegó **antes** que la implementación? Un commit `test(...)` que
  precede al `feat(...)` es la prueba.
- ¿El test falla sin la implementación? `git stash` de los ficheros de
  `lib/` y ejecutar el test: tiene que fallar.

### 8.4 Las reglas del repo, una a una

| Pregunta | Cómo se responde |
| -------- | ---------------- |
| ¿Algún error es una excepción? | `grep -rn "raise " lib/` y mirar: solo en el framework. |
| ¿Algún comando fuera de `Gunther.Command`? | `bash scripts/check_boundaries.sh` (ya lo dice). |
| ¿Los doctests nuevos están declarados? | El check de `check_phase.sh` lo dice; si no, `grep -l "iex>" lib/` contra `test/gunther/doctests_test.exs`. |
| ¿Hay un `moduledoc` y un `@spec` en lo nuevo? | Leer el fichero. |
| ¿El SPEC y el código coinciden? | `grep` de la sección del SPEC y leer el código. |
| ¿La nota de fase cuenta lo que se hizo? | Leerla contra los commits. |
| ¿El CHANGELOG y el registro de fases están al día? | Leerlos contra los commits. |
| ¿Los commits tienen fecha y prefijo correctos? | `git log --format="%h %ad %s" --date=iso`. |
| ¿Hay secretos? | `git grep -iE "token\|secret\|password\|api[_-]?key"` sobre lo nuevo. |
| ¿Hay trabajo a medias? | `git status --porcelain` y `git diff`. |

### 8.5 La pregunta de fondo

> ¿Puede alguien que no estuvo en la sesión decir, leyendo el repositorio,
> qué se hizo, por qué y cómo se comprueba?

Si la respuesta es no, el trabajo está a medias, por muy verde que esté el
check de formato.

---

## 9. Lo que viene después

La secuencia **no está escrita aquí**: la calcula `scripts/next_task.sh`. Lo
que el dueño tiene que saber es cómo encadenarla:

1. **Sesión por WP.** Cada sesión hace un WP y deja un commit. La sesión
   siguiente arranca con `bash scripts/next_task.sh` y hace lo que diga.
2. **La cola se agota sola.** Cuando el script salga con 1 y diga que no
   queda trabajo, la fase está hecha y le toca al dueño: revisar, mirar la
   CI y firmar el cierre.
3. **En paralelo, cuando haya GPU**: el probe de F2 y el cierre de los dos AC
   de hardware.

Y una constante: **cada fase termina con su puerta en verde y su nota de
fase escrita**. Lo que no se mide no está hecho, y lo que no está escrito no
existe para el siguiente.

---

## Referencias

- `AGENTS.md` — el contrato corto de trabajo.
- `SPEC-000-GUNTHER_r9.md` — el comportamiento fijado (§0.6 reglas de
  redacción, §3.4 y §3.6 fronteras, §4.13 catálogo de errores, §19 AC).
- `docs/01-plan-de-desarrollo.md` — fases, WP y grafo de dependencias.
- `docs/02-proceso-de-desarrollo.md` — ramas, CI, versionado, lista de revisión
  de un WP.
- `docs/03-estrategia-de-pruebas.md` — capas de prueba y casos obligatorios.
- `docs/13-registro-de-fases.md` — el estado vivo.
- `docs/fases/` — las notas de fase.
- `scripts/next_task.sh` — la cola, derivada del repositorio.
- `scripts/check_phase.sh`, `scripts/check_ac.sh` — las puertas ejecutables.
- `probes/` — las sondas reproducibles.
