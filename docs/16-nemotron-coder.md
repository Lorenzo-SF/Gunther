# El Nemotron como *coder*: configuración y modo de razonamiento

**Fecha: 2026-10-28.** Este documento decide cómo se sirve el
`NVIDIA-Nemotron-3.5-Lightning-30B-A3B` para que trabaje como *coder* de
Gunther, y recoge el diagnóstico de la configuración que había.

El prompt que se le pasa al modelo está en
[`17-prompt-del-coder.md`](17-prompt-del-coder.md).

---

## 1. La pregunta: ¿thinking sí o no?

**Sí. Con razonamiento.**

Y no es una preferencia: es lo que el modelo **hace por defecto** y lo que
NVIDIA diseñó para este uso.

El `chat_template.jinja` de NVIDIA (9867 bytes, el que hay en la carpeta del
modelo) lo dice en su línea 12:

```jinja
{%- set enable_thinking = enable_thinking if enable_thinking is defined else True %}
```

Sin `enable_thinking`, el modelo **razona**. El prompt de generación es
literalmente `assistant\n<think>\n` cuando piensa, y `assistant\n<think></think>`
cuando no.

Para el trabajo de un *coder* —leer un SPEC, escribir un test que falla,
cazar un bug invertido— el razonamiento es el producto. Sin él, el modelo
responde rápido y mal, y el ciclo TDD se rompe: escribe el test, no lo
ejecuta, y afirma que pasa.

### El matiz que importa: el modo es **binario**

Este template **no tiene niveles de razonamiento**. No hay `low`/`medium`/
`high`: hay `enable_thinking` sí o no. Lo que diga NVIDIA de
`temperature = 0.6` (thinking) frente a `0.2` (instruct) se refiere al
muestreo de cada modo, no a una escala de profundidad.

### Se puede cambiar por petición

El servidor acepta el kwarg en el cuerpo de la petición, y el cuerpo **pisa**
a la línea de comandos:

```json
{"chat_template_kwargs": {"enable_thinking": false}}
```

Y `reasoning_effort: "none"` también lo desactiva
(`tools/server/server-common.cpp:1499`).

Ojo con esto: **si el cliente manda `reasoning_effort: "none"`, el modelo no
razona**, por mucho que el servidor arranque con `enable_thinking: true`. En
mcode, el nivel de effort se elige con `--effort`; para el Nemotron vía
llama.cpp ese campo es **inerte** salvo el valor `none` (el template no lo
usa). Conclusión: **no pongas el effort en `none`**.

---

## 2. Lo que hay que arreglar antes de nada

Cinco cosas de la configuración actual. La primera es la grave.

### 2.1 Falta `--chat-template-file` (esto rompe el thinking)

El `chat_template.jinja` está al lado del GGUF, pero **no se le pasa al
servidor**. Sin ese flag, el servidor usa el template que trae la
arquitectura en llama.cpp, que para esta familia es el de la comunidad:
`models/templates/NVIDIA-Nemotron-3-Nano-30B-A3B-BF16.jinja`, **el del
NANO**. Con ese template el modelo responde en HTML y no razona bien.

Da igual que el GGUF lo lleve embebido: el conversor **nunca** lee el
`chat_template.jinja` de NVIDIA (sale de `tokenizer_config.json`, que en este
modelo no tiene la clave `chat_template`), así que un GGUF fabricado a mano no
lo lleva. Por eso el fichero está al lado: para pasarlo.

```bash
--chat-template-file "$model_dir/chat_template.jinja"
```

Si el GGUF lo trae embebido y es el bueno, el flag es inofensivo. Si no lo
trae, el flag es **lo que hace que el modelo razon**. Conviene ponerlo siempre.

### 2.2 `--reasoning-budget 32768` es incompatible con `--n-predict 8192`

El presupuesto de razonamiento son los tokens que el modelo puede gastar
**dentro** del bloque `<think>`. Si el presupuesto (32768) es **mayor** que
el máximo de tokens totales (8192), el presupuesto nunca se agota: lo que
corta es `n-predict`, y el modelo se pasa los 8192 tokens **razonando**. La
respuesta final se queda sin sitio y sale vacía o cortada.

El orden correcto es al revés: **presupuesto de razonamiento < máximo de
tokens totales**. Con un margen para la respuesta.

```bash
--reasoning-budget 8192 --n-predict 16384
```

El presupuesto acotado tiene una segunda ventaja: si el modelo se enrosca en
un bucle de razonamiento, corta a los 8192 tokens en vez de consume minutos
de GPU. Para un agente, eso es la diferencia entre un run de 20 minutos y uno
de dos horas.

### 2.3 `--temp 1.0` debería ser `0.6`

NVIDIA recomienda `temperature = 0.6` con `top_p = 0.95` en modo thinking. El
`top_p` ya está bien; la temperatura no. Con 1.0 el modelo sampling más
errático, y para un agente que va a repetir la misma tarea mil veces, la
estabilidad importa más que la variedad.

### 2.4 `--keep 16384` es corto para un coder

`--keep` es lo que se conserva del historial cuando `--context-shift` recorta.
Con 16384 tokens, el prompt del sistema (que ya es largo) más el código más el
historial se truncan enseguida: el modelo pierde el contexto a mitad de tarea
y la calidad se desploma.

Subirlo a 65536, o al valor del `--ctx-size`. El coste es KV: con la KV
unificada en CPU son RAM y latencia (ver §3).

### 2.5 `--reasoning-preserve` no hace nada con este template

El flag pone `preserve_reasoning: "true"` en las kwargs del template
(`common/arg.cpp:3791`), pero eso solo se aplica si el template declara la
capacidad `supports_preserve_reasoning`
(`common/chat.cpp:1077`). El template de NVIDIA **no declara ninguna
capacidad**.

No es un daño (es inocuo), pero conviene saberlo: no esperes que el
razonamiento se preserve en el historial. El template ya lo resuelve por su
cuenta, reconstruyendo los turnos antiguos como `<think></think>` vacío
(líneas 104-105 y 124 de `chat_template.jinja`).

### 2.6 `--seed -1` quita la reproducibilidad

Con `-1` la semilla es aleatoria: el mismo prompt da una respuesta distinta
cada vez. Para un modelo que hace TDD, poder **reproducir un fallo** vale
mucho: si el test falla, repetirlo con la misma semilla dice si es el modelo
o el código.

No es obligatorio cambiarlo. Si se cambia, que sea un número fijo y se
documente.

---

## 3. La configuración corregida

Dos variantes, según la máquina. La diferencia no es el modelo: es **dónde
vive la KV cache**.

### Variante A — Metal (MacBook Pro M4 Max, 36 GB unificada)

```bash
"$LLAMA_BIN"
  --model "$gguf_path"
  --host "$HOST" --port "$port"
  --api-key "$LLAMA_API_KEY"
  --alias "$model"
  --ctx-size "$ctx_size"
  --threads 10 --threads-batch 20
  --flash-attn on
  --jinja
  --chat-template-file "$model_dir/chat_template.jinja"   # <-- LO QUE FALTABA
  --log-verbosity 4
  --parallel 1
  --load-mode none
  --kv-unified
  --no-kv-offload
  --batch-size 4096 --ubatch-size 1024
  --cache-reuse 512 --cache-prompt --context-shift
  --keep 65536                                            # <-- era 16384
  --poll 30 --metrics --perf
  --n-gpu-layers 54 --n-cpu-moe 16
  --cache-type-k turbo3 --cache-type-v turbo3
  --temp 0.6 --top-p 0.95 --top-k 0 --min-p 0.0           # <-- temp era 1.0
  --repeat-penalty 1.0 --repeat-last-n 64
  --n-predict 16384                                       # <-- era 8192
  --reasoning-budget 8192                                 # <-- era 32768
  --chat-template-kwargs '{"enable_thinking": true}'
  --reasoning-format deepseek
```

Lo que se ha quitado: `--reasoning-preserve` (inerte, ver §2.5) y `--seed -1`
(irreproducible, ver §2.6). Si se quiere reproducibilidad, poner
`--seed 42` y quitado el `-1`.

### Variante B — CUDA (portátil con RTX 5080, 16 GB de VRAM)

Aquí **no** se quiere `--no-kv-offload`: con la KV en la RAM del sistema la
atención se calcula en la CPU y los tokens por segundo se desploman (medido
en otro modelo: de 120-130 a 80-100). Y el NVFP4 del Nemotron son 17 GB, que
**no caben** en 16 GB: la GPU se llena y el proceso de CUDA se queda sin
memoria.

```bash
  --ctx-size 32768          # el contexto tiene que caber con los 17 GB fuera
  --keep 32768
  --n-gpu-layers 54 --n-cpu-moe 16
  --cache-type-k q4_0 --cache-type-v q4_0   # turbo3 es del fork atomic; q4_0 es universal
  (sin --kv-unified, sin --no-kv-offload: la KV en la VRAM)
```

Ojo: en el portátil hay 32 GB de RAM y el modelo pesa 17 GB; con
`--n-cpu-moe 16` una parte de los expertos se queda en la CPU. Es el
compromiso que hace que quepa.

**El `turbo3` es del fork `atomic`**, no de llama.cpp upstream. En un motor
upstream, `--cache-type-k turbo3` no existe y el arranque falla.

---

## 4. Cómo comprobar el GGUF antes de confiar en él

Tres comprobaciones, en este orden. La primera es la que de verdad puede
matar el arranque.

### 4.1 ¿El GGUF lleva la MTP embebida?

Un GGUF con la capa MTP **dentro** (53 bloques, `nextn_predict_layers = 1`)
hace que el motor `atomic` **aborte**:

```
done_getting_tensors: wrong number of tensors; expected 417, got 408
```

El atomic no lee la metadata `nextn_predict_layers`, así que no crea la capa
nextn y sobran 9 tensores. Los GGUFs que **sí** arrancan tienen 52 bloques
(`nextn = 0`) y el draft MTP va **suelto**, en otro fichero.

```bash
ropero/bin/_ggufcheck.py "$gguf_path" --meta
```

Dice cuántos bloques declara y cuántos tensores tiene su índice. Lo que
importa: **52 bloques** y **coincidir** con lo que el motor crea.

Si aborta con el error de arriba, la solución no es tocar el motor: es usar un
GGUF sin la MTP embebida, o pasarla suelta con `--model-draft`.

### 4.2 ¿El NVFP4 tiene el layout correcto?

El cuantizador de llama.cpp **no tiene rama para NVFP4**: si cuantizas tú, mete
a 4 bits también la atención, el Mamba y el embedding. El estado recurrente
del Mamba se desincroniza y el modelo "habla cosas raras" (texto de
razonamiento degenerado).

El layout correcto es el de NVIDIA: los expertos en NVFP4 y **todo lo demás en
F16** (atención, `ssm_in`/`ssm_out`, `token_embd`).

```bash
ropero/bin/_ggufcheck.py "$gguf_path" --info
```

Si el recuento sale con F16 en la atención y el Mamba, el fichero está bien.
Si casi todo es de 4 bits, está mal: hay que usar el GGUF de NVIDIA o el
motor parcheado.

### 4.3 ¿El chat template es el de NVIDIA?

```bash
wc -c "$model_dir/chat_template.jinja"     # 9867 = el de NVIDIA
head -12 "$model_dir/chat_template.jinja"   # debe verse enable_thinking
```

### 4.4 ¿El servidor responde y qué modelos expone?

```bash
curl -s -H "Authorization: Bearer $LLAMA_API_KEY" http://127.0.0.1:$port/v1/models
```

El `id` del modelo lo decide el servidor (el `--alias`). Es ese `id`, tal
cual, el que hay que poner en el cliente. **Nunca inventar el nombre del
modelo.**

---

## 5. Cómo lo usa mcode

El cliente habla con el servidor por la API compatible con OpenAI, y el
servidor exige la cabecera:

```bash
mcode provider add --name nemotron \\
  --base-url "http://127.0.0.1:$port/v1" \\
  --api-format openai-completions \\
  --model "$ALIAS_DEL_SERVIDOR" \\
  --api-key-env LLAMA_API_KEY

mcode exec --model custom_provider:nemotron/$ALIAS_DEL_SERVIDOR \\
  --cwd /ruta/al/repo --permission full --output-format json "..."
```

Tres cosas que se tripsan:

1. **La ruta del provider delante**: `custom_provider:<id>/<model-id>`. Sin
   ella, mcode busca en la ruta por defecto y falla con «Model "x/y" is not
   available for the "configured_provider" route».
2. **El effort no puede ser `none`**: si lo mandas, el servidor desactiva el
   razonamiento (`reasoning_effort: "none"` → `enable_thinking = false`).
   Cualquier otro valor es inerte con este template, así que da igual cuál
   sea.
3. **El razonamiento llega en `reasoning_content`**, no dentro del contenido.
   Con `--reasoning-format deepseek` el servidor separa el bloque `<think>`.

Y una cuarta, la de la que nadie habla: **el modelo pierde el hilo**. Con
AA-LCR 52,38, en un contexto largo este modelo deja de encontrar lo que
busca. De ahí la regla del plan: **una tarea por sesión** y el estado en
ficheros, nunca en el hilo.

---

## 6. Lo que no se ha medido

- El **rendimiento** real con esta configuración en cada máquina. Se sabe
  que el NVFP4 es correcto por layout y que el motor lo carga, pero los
  tokens por segundo con `--n-cpu-moe 16` y la KV en la CPU no están medidos.
- El **efecto** de `--reasoning-budget 8192` sobre la calidad del código: el
  valor esta bien por construccion (cabe dentro de `n-predict`), pero su
  efecto sobre el acierto no esta medido.
- Si el `--n-cpu-moe 16` es el punto óptimo para 16 GB de VRAM. Es un valor
  copiado de otra configuración; con 17 GB de pesos, el reparto entre
  expertos en GPU y en CPU es lo que decide si el motor entra.

Nada de esto está escrito como "funciona": está escrito como lo que falta por
medir.
