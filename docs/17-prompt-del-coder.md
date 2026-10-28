# El prompt del *coder*: diseño

**El prompt está en [`../PROMPT.md`](../PROMPT.md).** Ese fichero es la fuente
única: se pasa tal cual con `mcode exec --file PROMPT.md` (o se pega como
prompt de sistema). Este documento explica **por qué** está escrito así.

Que no esté aquí, sino en un fichero aparte, es deliberado: una copia del
prompt dentro de un documento es una segunda fuente de verdad, y las dos
divergen. Lo que se desactualiza es el prompt, y cuando se desactualiza hay
que verlo en un solo sitio.

Hay un test que vigila que el prompt no se degrade
(`test/gunther/prompt_test.exs`): si le falta una pieza, el test lo dice.

---

## Las tres reglas de uso

1. **Una tarea por sesión.** El Nemotron 3.5 Lightning tiene AA-LCR 52,38:
   recupera bien una aguja en un contexto de un millón de tokens, pero a
   3 000 millones de activos pierde la respuesta a mitad de una conversación
   larga. De ahí la regla: **una tarea por sesión**, y el estado en ficheros,
   nunca en el hilo.
2. **El prompt de sistema y el `AGENTS.md` se complementan.** El prompt
   manda para la sesión; el `AGENTS.md` manda para el repositorio. Si
   cambian uno sin el otro, hay una contradicción: por eso el prompt le dice
   al modelo que lea el `AGENTS.md` al empezar.
3. **El `reasoning_effort` no puede ser `none`.** Si el cliente lo manda, el
   servidor de llama.cpp desactiva el razonamiento
   (`reasoning_effort: "none"` → `enable_thinking = false`), por mucho que el
   servidor arranque con `enable_thinking: true`. Ver
   [`16-nemotron-coder.md`](16-nemotron-coder.md) §1.

---

## Por qué el mapa de la documentación va primero

El repositorio está documentado: SPEC, ADR, plan de desarrollo, registro de
fases, notas de fase, estrategia de pruebas. Un modelo que no sabe que eso
existe **inventa**: se inventa un criterio de aceptación, se inventa el
nombre de un fichero, se inventa el estado de una fase.

Así que lo primero del prompt es una tabla de **qué fichero se lee para
qué**. Es media tabla de trabajo hecha: sin ella, el modelo deduce la
estructura del repo a base de `ls` y se equivoca.

Las secciones del SPEC que más se citan van enumeradas en el prompt: §0.6
(redacción), §3.4 y §3.6 (fronteras), §4.13 (errores), §11 (recursos), §19
(AC). Un AC que no está en §19 no es un criterio de aceptación.

## Por qué el estado se lee y no se recuerda

El prompt dice que **el fichero manda sobre la memoria del modelo**. Es la
defensa contra lo único que no se puede corregir: el modelo contesta con
datos de un repo que ya no es este, o con el estado de una fase de hace tres
semanas.

Y por eso el prompt **no lleva cifras del estado dentro** más allá de las
que estructuran el trabajo. Las cifras (cuántos tests, cuántos doctests, qué
fases están cerradas) están en `docs/13-registro-de-fases.md`, que se lee
cada vez. Una cifra dentro del prompt es una cifra que se queda vieja.

## Por qué las trampas llevan su porqué

"Be careful with the schema" no sirve de nada: el modelo no tiene ninguna
razón para RECORDAR ese aviso. Lo que funciona es el mecanismo:

> `grep` del nombre no prueba que exista el campo: sigue el **tipo**.

Eso es una instrucción accionable y, además, explica por qué la instrucción
existe. Las once trampas del prompt son todas de esa forma: qué pasó, por
qué no lo vio nadie, y cómo se caza la próxima vez.

## Por qué los límites son explícitos

Un modelo con el SPEC en la cabeza **es capaz** de cambiar el SPEC r9 sin
avisar, y de declarar cerrada una fase que no lo está. Se le dice que para,
y con qué se sustituye ("anótala y sigue con lo demás"): una decisión
bloqueada con el resto del trabajo hecho es un entregable, no un problema.

La misma lógica con el CI: el prompt no dice "no merges nunca", dice "mira el
run: tiene que estar en verde". Una puerta se comprueba; no se da por hecha.

## La pregunta del final

El prompt acaba con:

> ¿Puede alguien que no estuvo en esta sesión decir, leyendo el
> repositorio, qué se hizo, por qué y cómo se comprueba?

Es la pregunta que resume todo lo demás. Si la respuesta es sí, el trabajo
está hecho; si es no, no lo está — y da igual que el check de formato esté
verde.

---

## Lo que NO está en el prompt, y por qué

- **Los números del estado.** Viven en el registro de fases, que se lee.
- **La lista de ficheros del repo.** La tiene `docs/05-estructura-del-repositorio.md`.
- **El detalle de los AC de F3.** Los tiene el SPEC (§19) y la nota de fase.
- **La configuración del servidor de inferencia.** Es de la máquina, no del
  trabajo: está en [`16-nemotron-coder.md`](16-nemotron-coder.md), que es
  donde el dueño la consulta, no donde el modelo la lee.

Un prompt que intenta llevar el estado dentro se queda viejo el primer día
que el estado cambia. Uno que apunta a los ficheros no puede quedarse viejo:
o el fichero está al día, o hay que actualizarlo, y eso se ve.
