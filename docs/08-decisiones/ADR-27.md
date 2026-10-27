# ADR D-27 — Quién elige el device y cómo se le dice al motor

- **Estado**: aceptada
- **Decidida**: 2026-10-20, por el dueño (medición + corrección de la
propuesta del agente).
- **Fuente**: README original de `08-decisiones` (decidido hasta 2026-10-21; `main` 398a1b9)

- **Sustituida por D-65** (identidad física y detector del propio engine) **y por SPEC §11.5** (fórmula de KV corregida). Se conserva el texto original.
- Nombre actual del módulo de colocación: Placer (D-53); `Gunther.Engine.Placer` sustituye a `Gunther.Engine.Placer` en el texto.
- Resuelta en r7 (D-89). Choque original: D-27 decide que el motor reciba un **entero de capas calculado** y no `-1`, con `--fit` encendido como red de seguridad; el SPEC r6 §11.1 y §11.5 no pasan `--n-gpu-layers` calculado: usan `llama-fit-params` o `--fit on` con `--fit-target`.
- Resuelta en r7 (D-89). Choque original: D-27 reserva **el peso real** (en los dos sentidos); el SPEC r6 §11.3 reserva `ceil(peso) + engine.vram_margin_mib` (1024 por defecto).
- Resuelta en r7 (D-89). Choque original: D-27 reintenta la carga en otro device si el motor falla en uno (con varios devices); el SPEC r6 no define ese reintento (§11.1 marca `:failed` y el failover cambia de modelo, no de device).

## Contexto
#### La medición que decide la pregunta

El mismo modelo (`Qwen3-Coder-30B-IQ3_XXS`, 12,8 GB), la misma RTX 5080
(16303 MiB), cuatro configuraciones:

| Configuración | Resultado |
|---|---|
| `--n-gpu-layers 99`, caché f16 | **OOM** — pedía 12288 MiB de KV cache |
| `--n-gpu-layers 99`, caché `q8_0` | **OOM** — pedía 6528 MiB de KV cache |
| `--n-gpu-layers 99`, caché `q8_0`, ctx 32768 | carga, **15551 MiB** |
| `--n-gpu-layers -1`, caché `q8_0`, ctx 131072 | carga, **14913 MiB** |
| `--n-gpu-layers -1`, caché `q8_0`, ctx 131072, `--fit off` | **OOM — muere** |

Dos hechos que la decisión depende:

1. **`-1` depende de `--fit`.** Con `--fit off`, `-1` pide todo y hace OOM.
   Con `--fit on`, `-1` se recorta y carga. El catálogo usa `-1` en casi
   todos los modelos, así que «apagar `--fit` y dejar `-1`» es lo que
   el consejero propuso primero y la medición muestra que **no carga**.

2. **La huella no es del modelo, es de la configuración.** El mismo fichero
   ocupa 15551 MiB con ctx 32768, 14913 con ctx 131072 y `-1`, y **no
   cabe** con `99` en ningún contexto. Las tres variables —`ctx-size`, tipo
   de caché, `n-gpu-layers`— viven en `model_args` o se derivan de ellas.

**Conclusión**: `vram_mb` **no puede ser un número del modelo**. El mismo
modelo con distinto `model_args` ocupa 15551 o 14913 MiB, o no cabe. Un
número en el catálogo no puede ser la verdad porque la verdad depende de
unos flags que el catálogo también tiene.

## Decisión
**Qué**: **Gunther elige el device y se lo impone al motor.** La reserva
(`Arrea.Resource`) se hace **antes** de arrancar, con un peso que sale de
la configuración y no del catálogo. El motor arranca con `--device CUDA<N>
--split-mode none --main-gpu N`, y el `--fit` se deja en `on` como red de
seguridad, pero el número de capas que Gunther le pasa es un **entero
calculado**, no `-1`.

#### Las tres correcciones a la opción A

**A.1 · Nada de `--fit off`.** Al revés: `--fit` **on** es lo que permite
que el `-1` del catálogo funcione. Si Gunther decide el device y quiere que
el motor no recorte, la forma de decirlo no es apagar `--fit` — es **no
poner `-1`** y poner el número de capas que Gunther calcula. Si Gunther
decide, decide también las capas, y entonces `--fit` no tiene nada que
recortar.

**A.2 · `--device` no acepta índices.** El formato real es el nombre que da
`--list-devices` —`CUDA0`, no `0`— (medido: `--device 0` → `invalid
device: 0`). Hay que traducir `device_index` (entero) → `CUDA<N>`. Y
`--main-gpu` **sí** es un índice. **Dos sistemas de coordenadas en la misma
línea de comando.** `--split-mode none` para un solo device.

**A.3 · El peso de la reserva se calcula, no se declara.** Ver abajo.

#### El peso de la reserva

La huella que se reserva al cargar es **los pesos del modelo + el KV cache
al `ctx-size` declarado**, porque el KV cache se reserva entera al cargar:
no depende del contexto que se use, sino del máximo que se declara. Eso es
un dato que se puede calcular **antes** de arrancar.

El catálogo da la configuración (`context_size`, `model_args` con el tipo
de caché), y el peso es una función de ella. `vram_mb` **no es la verdad**:
es una estimación que el usuario escribe a mano, en un campo que el
cargador avisa cuando está vacío pero no cuando está equivocado (D-26). Es
el mismo patrón por tercera vez.

**De dónde sale el peso**: de la configuración y del tamaño del fichero
GGUF (los pesos). La fórmula del KV cache necesita los parámetros de la
arquitectura (capas, cabezas KV, dimensión de cabeza), que están en los
metadatos del GGUF. El mecanismo concreto —parser de GGUF en Elixir vs.
llamar a `llama-fit-params` vs. un fichero de medición aprendida— se decide
en la implementación; la decisión es que **el peso no puede ser un número
del catálogo**, y que debe ser calculable antes de arrancar. `vram_mb`
queda como fallback/estimación, no como verdad.

#### La reserva tiene tres estados

La medición muestra que el OOM **mata el proceso**: no es un error suave,
es llama-server saliendo con «exiting due to model loading error». Por eso
la reserva necesita **tres estados, no dos**:

1. **`reservada`** — Gunther ha adquirido capacidad en `Arrea.Resource`
   antes de arrancar, con el peso calculado.
2. **`arrancada`** — el motor ha cargado y Gunther ha medido la VRAM real
   por PID (D-16). Si la medición es mayor que la reserva, se corrige
   (`release` + `acquire` con la medición, opción (ii) de D-27). Si es
   menor, la reserva se queda como está (conservador).
3. **`liberada`** — el motor se para o muere. La reserva se libera.

El paso de `reservada` a `arrancada` **falla** cuando el motor muere (OOM).
En ese caso la reserva se libera y el caller recibe el error. Sin este
paso, un OOM deja una reserva fantasma y el planificador cree que ese
device está ocupado.

#### Reintento

Con **varios devices**, si el motor falla al cargar en uno, se libera la
reserva y se reintenta en otro (opción C). Con **una sola GPU**, un OOM es
un OOM: no hay a dónde reintentar, y la respuesta honesta es «no cabe», no
«reintenta». El reintento es un beneficio de tener varios devices, no un
requisito de la reserva.

## Alternativas consideradas
#### Lo que esto NO hace

- **Multi-GPU con split** (`--split-mode layer`, `--tensor-split`): es otro
  problema (P-6), no se toca ahora. Cada motor va a un solo device.
- **Cablear `Arrea.Resource`**: hecho en la implementación (2026-10-21).
  Queda el reintento multi-device (P-6). **Y `vram_mb` en el catálogo no se
  rellena** (P-10): la medición dice que el mismo modelo ocupa 795, 7978 o
  10452 MiB según la memoria libre del instante, así que un número del
  catálogo sería la cifra de un momento y no la verdad.
- **Medición fuera de NVIDIA**: el peso se calcula de la configuración y de
  la medición por PID (`nvidia-smi`). En Metal/ROCm no hay `nvidia-smi`;
  ahí la reserva queda como estimación hasta que exista su equivalente.

## Consecuencias
#### Consecuencias

- **D-16 se hace real**: Gunther consume la medida (por PID) y decide el
  device. La columna `SLOT` del `gunther status` ya no usa el puerto (T-6).
- **El `-1` del catálogo deja de pasarse tal cual**: `build_args` pasa un
  entero que Gunther calcula, o `0` cuando `--cpu`. El `--fit` se queda
  encendido como red de seguridad, pero no tiene nada que recortar si el
  número es correcto.
- **`vram_mb` se degrada a fallback**: la verdad es el peso calculado +
  la medición. `vram_mb` sigue sirviendo cuando no hay otra cosa (CPU, o
  sin GPU).
- **P-4 queda desbloqueado**: la reserva se hace antes de arrancar, en el
  device que el plan eligió, con un peso que sale de la configuración.

## Historia de la implementación
#### Lo que se decidió al implementarlo (2026-10-21)

La implementación encontró tres cosas que la decisión no había fijado, y una
que estaba mal en el primer intento:

- **La cuota de `Arrea.Resource.acquire/4` es `0`, no `:infinity`.** El eje
  blando de `acquire/4` valida `is_number/1` en los dos importes; `:infinity`
  solo vale como opción `:quota` del resource. Pasar el átomo devolvía
  `:unknown_cost` y **abortaba todos los arranques de GPU**. El wrapper
  `Gunther.Engine.Resource.acquire/3` ya no acepta cuota: siempre `0`.
- **`vram_mb` no es obligatorio.** Si falta, el modelo **arranca** igualmente:
  se reserva una **estimación** provisional —un marcador de posición para los
  segundos que tarda `llama-fit-params` en medir— y en cuanto llega la
  medición, la reserva se **sustituye** por el peso real. Se avisa por
  `Logger.warning`. La reserva es planificación, no arranque: un modelo sin
  `vram_mb` no puede planificarse bien, pero no puede dejar de funcionar por
  eso.
- **`vram_mb` es una cota inferior declarada, y la reserva la sustituye.**
  El peso que se reserva es **el que el motor va a ocupar**, no
  `max(declarado, real)`. Si el peso medido es mayor, la reserva sube; si es
  menor, **también baja**, porque quedarse en la cota inferior reservaría
  memoria de más. Y esa bajada no es un detalle: con el mismo modelo y la
  misma GPU, el `vram_mb` medido en el pie (`coder`, 12744) es **mayor** que
  el peso ajustado que de verdad ocupa cuando llama.cpp recorta las capas que
  no caben (7978 con la memoria que había). Si la reserva se quedase en
  12744, no cabría en el device y **el modelo no arrancaría**: el `vram_mb`
  medido impediría que el modelo arrancase recortado.
- **La estimación por contexto no puede ser la reserva final.**
  `div(ctx, 1024) * 4` daba 512 MiB para un modelo que ocupa 7978: reservar
  de menos es peor que no reservar, porque el knapsack afirma capacidad que
  no tiene. Por eso la estimación es solo el marcador de posición de los
  segundos que tarda la medición, y lo que se reserva al final es **el peso
  real**.
- **La capacidad es la del motor.** Se registra el total de `nvidia-smi`
  (16303 MiB en la RTX 5080) y se reservan 370 MiB como titular `:system`;
  `available/1` devuelve 15933. La cuota de ese acquire también es `0`.
  **Pero 15933 no es la memoria que hay**: es la que habría si nadie más
  usara la GPU. La memoria que usa **otra gente** entra como un titular
  más, `:foreign` (ver la segunda ronda abajo).
- **El titular es `{alias, port}` y se construye en un solo sitio**
  (`Gunther.Engine.holder/2`). `Engine.start/3` reserva; `Server.terminate/2`
  libera. Si `init/1` falla, `terminate/2` no se llama y libera `Engine.start/3`.
  Los titulares ajenos a Gunther usan el átomo `:foreign`, que es otra cosa y
  no se confunde con ninguno de ellos.
- **`Server` atrapa salidas (`trap_exit`).** Sin eso, la salida de `LongRunning`
  —el motor murió— mataba el GenServer por el link **sin pasar por
  `terminate/2`**, y la reserva se quedaba puesta para siempre. El
  `handle_info` de `{:EXIT, lr_pid, reason}` para el server por la misma razón y
  así `terminate/2` corre. `Engine.stop/1` tolera la carrera con una parada en
  curso.

#### La segunda ronda (2026-10-21): lo que falló al arrancarlo de verdad

La primera implementación pasó los tests y **no arrancaba un modelo**. Los
tests medían las funciones, no el camino real. Estos son los fallos que solo
aparecieron al poner un GGUF delante, y lo que se cambió en cada uno.

**1 · El peso se leía de la línea equivocada.** `parse_weight/1` leía el
`projected to use` (19053 MiB) en vez del `mem=` ajustado (7978 MiB). La
diferencia no es un detalle: el `projected to use` es lo que haría falta **si
TODO el modelo cupiera en GPU**, y el `mem=` es lo que ocupará **después** de
recortar. Reservar 19053 contra una capacidad de 15933 se rechaza siempre, así
que **el modelo que necesita recorte era justo el que no podía arrancar** —
el recorte es lo que permite que un modelo grande quepa en una GPU pequeña.
llama.cpp puede escribir **varias** líneas `mem=` (prueba varias
configuraciones), así que ahora gana la última, validada contra el `-ngl` de
los args ajustados.

**2 · El `-ot` llegaba con las comillas dentro.** Partir la línea de args por
espacios deja el valor del `-ot` como `"blk\.11\.ffn_down.*=CPU,…"`, y
llama-server responde `error while handling argument "-ot": unknown buffer
type` y **no arranca**. Medido en las dos formas: con las comillas no arranca;
sin ellas carga y responde `{"status":"ok"}`. Ahora el tokenizador trata el
valor entrecomillado como una unidad y le quita las comillas.

**3 · La reserva solo subía, y había que bajar.** La corrección subía al peso
medido pero nunca bajaba, porque el diseño original decía que «bajar
devolvería capacidad que el motor sigue ocupando». La medición dice lo
contrario: el `vram_mb` del pie (12744) es **mayor** que el peso ajustado real
(7978), así que quedarse en la cota superior **impedía arrancar** al modelo
recortado. La reserva es **el peso real**, en los dos sentidos.

**4 · El ledger no veía la memoria ajena.** Decía 15933 MiB libres cuando los
reales eran menos: en la medición, 11518, de los que 4216 ocupaba un modelo de
**otra sesión**. La reserva se tomaba sobre memoria que ya no estaba, y el OOM
pasaba con la cuenta «correcta». `Arrea.Resource` no tiene API para cambiar la
capacidad de un resource registrado —y re-registrarlo perdería el ledger
entero—, así que la memoria ajena entra como **un titular más**, `:foreign`,
al lado de `:system`. Con eso, `available == free_real − 370`, que es
exactamente lo que un motor nuevo puede usar. Se reajusta antes de cada
colocación, con un umbral de 64 MiB para no provocar un `release`+`acquire`
por unos megas de diferencia entre dos lecturas de `nvidia-smi`.

**5 · Sin `vram_mb` no se reservaba nada.** Un modelo del catálogo sin
`vram_mb` arrancaba **sin reserva**: el planificador creía que ese device
estaba libre. Ahora se reserva la estimación como marcador de posición y se
sustituye por el peso medido en cuanto llega.

**6 · Un modelo de CPU pedía VRAM.** `Scheduler.plan/1` pasaba por el
knapsack de GPU a un modelo con `gpu_layers == 0`: con la GPU llena, un modelo
que corre en CPU se rechazaba con `:no_room`. **Un modelo de CPU no puede
quedarse sin arrancar por falta de GPU**, así que ahora devuelve
`{:ok, nil}`.

**7 · El CLI y la API arrancaban por caminos distintos.** `gunther run` llamaba
`Engine.start/2` con `device = nil`: sin scheduler, sin reserva y sin
`--device`. El camino que usaba una persona era el que no reservaba. Ahora
los dos usan `Gunther.Engine.start_placed/2`, que es **el** camino: el
scheduler decide dónde va el modelo, se reserva la VRAM, y si hay que expulsar
a alguien, se expulsa.

**8 · `gunther stop` no paraba el motor.** El `engine_pid` del registro es el
pid del `llama-server`, un **proceso del sistema operativo**, y el dueño es un
BEAM: matar al dueño no se lleva por delante al motor. Medido: `gunther stop`
decía «1 instancia parada», el registro quedaba vacío, `gunther status` decía
«no hay instancias»… y el `llama-server` seguía ahí con **8116 MiB de VRAM
cogidos**. Dos herramientas diciendo verdad sobre cosas distintas, y la que
decía «parado» mintiendo. Ahora `stopped_remote/1` mata también al motor.

**9 · Cuando la GPU está llena, el recorte no cabía en el ledger.** Con otra
sesión ocupando la GPU (42 MiB libres de verdad), la memoria ajena que había
que descontar eran 16261 MiB, y el hueco que queda tras `:system` son 15933:
**no cabía**. El `acquire` del titular fallaba, el error se tragaba, y la
disponible se quedaba en **15933** — la cifra que no existía. Justo la
mentira que este módulo viene a quitar, en su forma extrema. Ahora el titular
se recorta a lo que queda representable, y la disponible cae a **0**: un 0 es
honesto; un 15933 no. Lo malo es que este caso **solo aparece cuando la GPU
está llena**, o sea cuando más importa.

**10 · Un motor de CPU pedía una GPU que no necesitaba.** El camino único
(`start_placed/2`) consulta al scheduler, y el scheduler solo ve el modelo: un
modelo del catálogo con `gpu_layers: 99` que se arranca con `--cpu` lo pide
igual. En una máquina sin GPU, `gunther run --cpu` se rechazaba con
`:no_room` — **un modelo que corre en CPU no puede quedarse sin arrancar por
falta de GPU**. Ahora el scheduler se consulta solo cuando el motor va a la
GPU.

**11 · El scheduler y la reserva podrían decir cosas distintas.** El scheduler
decía «cabe» comparando con `free_mb` de `nvidia-smi` (42 MiB), y la reserva
decía «no cabe» con la del ledger (0, porque el motor nuevo necesita 370 MiB
de contexto CUDA). El modelo no arrancaba, con un error que no explicaba nada.
Ahora **los dos sides usan la cifra del ledger**, que es la que descuenta el
overhead: `available` es exactamente lo que le cabe a un motor nuevo. Con la
misma cifra en los dos lados, la respuesta es la misma por construcción.

Y de ahí salió lo más caro de esta ronda: **un test que dependía de la
máquina**. `cpu_args_test.exs` arrancaba un motor de mentira por el CLI, y el
CLI ahora pasa por el scheduler: en CI (sin GPU) no había dónde colocarlo, y
en local la GPU podía estar ocupada por otra sesión. El test fallaba —o
pasaba— según la máquina, y **el fallo no era del código**.

Lo destapó el propio CI: en el runner **sin GPU** fallaron 8 tests, y ninguno
por un fallo del código —todos por `{:error, :capacity_unknown}` («no hay
capacidad») o por no haber sitio donde colocar el motor. La solución no es
saltarse el test (`@tag :skip`), que dejaría el caso sin cubrir: es **poner
delante un `nvidia-smi` de mentira** (`Gunther.FakeGPU`) que diga lo que el
test necesita. El código de producción no cambia, y el test además puede
reproducir un caso que en la máquina real es difícil: **la GPU llena**, que es
donde el titular `:foreign` no cabe en el ledger y la disponible tenía que
caer a 0. Un test que depende del hardware de quien lo corre no es un test: es
una lotería.

**12 · Y debajo de eso había un crash de producción.** El `nvidia-smi` de
mentira destapó un bug que no era de tests: `Gunther.Detector.GPU` pregunta la
versión de CUDA con `System.cmd("nvcc", ...)`, y **`System.cmd/3` no devuelve
un error cuando el binario no existe: lanza una `ErlangError` con `:enoent`**.
El driver de NVIDIA se puede instalar **sin el toolkit de CUDA**, así que
`nvcc` no está en muchísimas máquinas que sí tienen GPU —y en todas ellas
Gunther reventaba al detectar el hardware. En el CI se ve porque el runner
tiene `nvidia-smi` (el de mentira) y no tiene `nvcc`.

El arreglo es preguntar antes de ejecutar (`Gunther.Detector.GPU.cmd/2`), que
además cubre el caso de un binario que existe pero no se puede arrancar. Es
un crash de producción que llevaba años ahí, y lo ha destapado un test que
dependía de la máquina: **un test frágil no solo da falsos negativos, también
enseña cosas**.

#### La tercera ronda (2026-10-21): la revisión del consejero

El consejero revisó el PR y retiró tres cosas: **la semántica de
`vram_mb`**, **el error de «no hay GPU»** y **la identidad del titular**. Las
tres están cambiadas, y una de ellas ha encontrado un bug de verdad.

**`vram_mb` es una cota inferior, no una foto.** Es el **mínimo** que el
modelo ocupa con seguridad —el peso *después* de que llama.cpp recorte las
capas que no caben—, no el footprint completo y no «cuánto ocupaba la última
vez». Con esa semántica, el acquire inicial es seguro (si la cota no cabe, el
peso real, que es >= la cota, tampoco cabe) y el scheduler no rechaza un
modelo recortable por un número alto. **El catálogo no lleva ninguno**, y el
`template.ex` lo dice con esas palabras.

**El mutex no es una reserva.** Sin `vram_mb`, lo que se toma es un **mutex**
—una estimación provisional para serializar los arranques concurrentes
mientras `fit-params` mide—, y un mutex **no puede rechazar**: si no cabe,
el modelo sigue y **la medición** decide, que es lo único que sabe cuánto va
a ocupar de verdad. La honestidad del ledger la da el titular `:foreign`, no
la estimación.

**`:no_gpu` no es `:no_room`.** «Esta máquina no tiene GPU» y «no cabe» son
hechos distintos, y el primero tiene salida (`--cpu`) mientras el segundo no.
Ahora el scheduler devuelve `{:error, :no_gpu}` cuando no hay devices
usables, y la API y el CLI devuelven **el mismo** error. Unificar el
comportamiento sin unificar el error no arregla nada.

**El titular lleva una generación.** `{alias, port}` no es único en el
tiempo: si el puerto se reutiliza y el `terminate/2` del server viejo llega
tarde, su `release/2` —que quita la primera entrada de ese titular— podía
soltar la reserva **del modelo nuevo**. Ahora el titular es
`{alias, port, make_ref()}`, se crea **una vez** en `Engine.start/3` y lo
usan el acquire, la corrección y el `terminate/2`.

> Medido: con el titular sin generación, el test nuevo falla con «un release de
> un titular viejo soltó la reserva del nuevo». Con ella, verde.

Y una limitación que se ha **documentado** en vez de resuelta: el ajuste de
`:foreign` son dos llamadas (`release` + `acquire`) y entre ellas hay un hueco
—microsegundos— en el que otro arranque ve una disponible demasiado grande. El
daño está acotado, porque la corrección al peso **medido** es la que sí es
atómica y el modelo que no quepa se para. Con un solo usuario es despreciable;
si algún día el scheduler coloca dos modelos a la vez, hay que serializarlo
por device.

#### La cuarta ronda (2026-10-22): tres decisiones del consejero

El consejero revisó la ronda anterior y decidió tres cosas. Las tres están
hechas, y **una de ellas era un bug de verdad** que solo se vio al medir.

**1 · Las víctimas se contaban con la estimación, no con la verdad.** El
scheduler expulsa a las víctimas **por tamaño**, así que la cuenta decide si
dice «no cabe» o expulsa a alguien. Y la cuenta era
`model.vram_mb || estimate_model_size(model)`: un modelo **corriendo** sin
`vram_mb` contaba como 512 MiB (la estimación) cuando ocupaba 7978 de
verdad.

Medido el 2026-10-22 con un `coder` corriendo: `nvidia-smi` decía **1054 MiB**
y el scheduler contaba **512**. Con un modelo de 8 GB la diferencia es de 7 GB,
y la expulsión no libera lo que cree que libera.

Ahora el tamaño de una instancia es el que dice `nvidia-smi`
(`Gunther.Engine.Placer.size_mb/2`), y la estimación solo se usa cuando **no hay
medición** —un modelo en CPU, o una máquina sin `nvidia-smi`.

**2 · Decidir y reservar son una sola operación, y no había cerrojo.** Dos
`start_placed/2` concurrentes pueden medir **la misma** memoria libre (el
`sync_foreign` de uno todavía no ve lo que el otro acaba de reservar) y decidir
los dos que su modelo cabe. El primero reserva; el segundo recibe un error de
acquire que no explica nada y su modelo no arranca, cuando lo que había era
sitio de sobra y una carrera.

Ahora hay un **semáforo** (`Gunther.Engine.Placement`): el segundo
espera y vuelve a decidir con la memoria ya cambiada.

> Y un detalle que costó un rato: el cerrojo **no** es `:global.trans/3`. En
> OTP 28 la API de cerrojos de `:global` ya no existe y `trans/3` se quedó
> **sin hacer nada**: medido, dos llamadas concurrentes de `trans/3` tardaron
> 1,0 s en vez de 2,0 s. El semáforo es un `GenServer` que **da el turno** (el
> motor tiene que seguir siendo hijo de quien lo pide, no del cerrojo) y
> suelta el turno aunque el que lo tenía se muera.

**3 · Un modelo que fija las capas en GPU se rechaza.** `llama-fit-params` no
puede ajustar un `--n-gpu-layers` que el usuario puso: aborta con *«n_gpu_layers
already set by user to 99»*. Sin medición no hay peso real, la reserva se
queda en una suposición y el motor arranca a ciegas.

Ahora el scheduler devuelve `{:error, :gpu_layers_fixed}` con un mensaje que
dice qué hacer (usa `-1` o `--cpu`), **en vez de arrancar a ciegas**. La
excepción son los modelos con `--n-cpu-moe`: los expertos se van a la RAM, lo
que queda en la VRAM cabe, y el modelo arranca bien — pero su reserva **tampoco
se mide**, y de eso avisa el motor con un warning.

Medido el 2026-10-22 con un modelo de 13 GB y la GPU con 15 886 MiB libres: con
99 el fit aborta y el motor sale con código 1; con `-1` el fit ajusta y el
modelo arranca.

## Verificación
#### Verificación de la implementación (2026-10-21)

Medido con `Agents-A1-4B-Q8_0.gguf` (4,48 GB), ctx 32768, caché `q8_0`,
device 0, y un `vram_mb` declarado de 1000:

| Paso | Medida |
|---|---|
| `available` antes | 15933 MiB (16303 − 370 de overhead) |
| `llama-fit-params` | 5395 MiB, `-c 32768 -ngl -1` |
| `available` con el motor cargado | 10538 MiB (reserva corregida de 1000 a 5395) |
| `available` tras parar | 15933 MiB |
| motor cargado | `healthy: true`, 5458 MiB en `nvidia-smi` por PID |

Los tests de máquina `resource_machine_test.exs` (arranque fallido y motor que
muere), `fit_params_machine_test.exs` y `scheduler_machine_test.exs` pasan con
la GPU real.

La primera ronda **no pudo arrancar un modelo del catálogo**: los GGUF de
`~/models/gguf/` habían desaparecido durante la sesión y ningún modelo del
catálogo declaraba `vram_mb`. La segunda ronda sí, y con el modelo que
importa: el que necesita recorte.

##### La segunda medición, con el modelo que necesita recorte

La tabla anterior usa un modelo de 4,48 GB que cabe de sobra. El caso
interesante es el otro: un modelo **grande** que solo arranca si llama.cpp
recorta las capas que no caben. Medido con `Qwen3-Coder-30B-IQ3_XXS` (12,8 GB),
ctx 131072, caché `q8_0`, tres veces con la GPU en distinto estado:

| Memoria libre en el momento | Peso ajustado (`mem=`) | `projected to use` |
|---|---|---|
| GPU ocupada | **795 MiB** | 19053 MiB |
| GPU medio libre | **7978 MiB** | 19053 MiB |
| GPU libre | **10452 MiB** | 19053 MiB |

Tres cosas salen de esta tabla:

1. **El peso que hay que reservar es el `mem=` ajustado**, no el
   `projected to use`: con 19053 contra una capacidad de 15933, la reserva se
   rechaza siempre y **el modelo que necesita recorte no puede arrancar**.
2. **El mismo modelo ocupa 795, 7978 o 10452 MiB** según cuánta memoria
   hubiera libre. No es una propiedad del modelo: es una propiedad del
   modelo **en esa GPU, en ese momento**.
3. Por lo tanto **`vram_mb` no se rellena en el catálogo** (P-10): un número
   escrito a mano sería la cifra de un instante, y Gunther lo corrige igual
   con el peso medido. Queda como **pista opcional** —una estimación previa
   para que un arranque que no cabe falle pronto en vez de a los 4 s—, y el
   comentario del `template.ex` lo dice así.

El criterio de aceptación del plan era que la disponible **dejase de mentir**:
que `available` fuese la memoria real menos el overhead, y no el total del
device. Medido: con 11718 MiB libres de verdad, la disponible pasó de **15933**
(la del total, que no existía) a **11348** (= 11718 − 370).

Y el arranque de verdad, con `gunther run --detach --port 9991 coder`: la
columna `VRAM` mostró **8116 MiB**, los mismos que `nvidia-smi` —el motor
usando lo que dice y no lo que el catálogo promete.

La puerta de máquina (`resource_machine_test.exs`) arranca el modelo **por el
camino único** —`Gunther.Engine.start_placed/2`—, así que el scheduler está en
el camino de verdad, y comprueba que hay reserva después de arrancar. Eso es
lo que prueba que `place/3` **se ejecutó**: `Engine.start/3` con `device = nil`
no reserva nada, así que que haya reserva prueba que alguien decidió un
device, y el único que decide es el scheduler. Medido el 2026-10-21 con
`Qwen3-Coder-30B-A3B-Instruct-UD-IQ3_XXS`: 3/3 en verde, el motor sano y la
reserva igual al peso ajustado.

Y la suite se pasa **con GPU y sin GPU**: los tests que miden hardware usan
el `nvidia-smi` de mentira, así que el resultado es el mismo en el runner de
CI (que no tiene GPU) y en la máquina con la RTX 5080 delante.

#### Cómo se revisa

- Si el peso calculado resulta sistemáticamente mayor o menor que la
  medición, la fórmula (o el parser de GGUF) se ajusta, no el contrato.
- Si un modelo con split multi-GPU resulta necesario, se abre P-6 con
  `--split-mode layer` + `--tensor-split`, y la reserva pasa a ser por
  device, no por motor.
- Si alguien quiere apagar `--fit` (para tener control total), primero hay
  que medir que el entero calculado cabe en el device elegido. Eso es un
  gate de máquina, no de CI.

- **Puertas F0 de las que depende**: G-09, G-10, G-11, G-14
