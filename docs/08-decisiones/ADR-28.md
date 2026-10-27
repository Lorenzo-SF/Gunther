# ADR D-28 — Qué es un «device» y de dónde salen sus cifras

- **Estado**: aceptada
- **Decidida**: 2026-10-22, a propuesta del dueño, escrita por el consejero.
- **Fuente**: README original de `08-decisiones` (decidido hasta 2026-10-21; `main` 398a1b9)

- **Sustituida por D-65** (el device se identifica por `physical_id`). Se conserva el texto original.
- Nombre actual del módulo de colocación: Placer (D-53). `Gunther.Detector.LlamaCpp` sustituye a `Detector.LlamaCpp` (D-59, D-65).
- Resuelta en r7 (D-89). Choque original: D-28 exige una sola fuente de medida por backend (la fórmula miente si `capacity` y `free` vienen de fuentes distintas); el SPEC r6 §11.3, en el caso `:per_process`, calcula `foreign` con las cifras por proceso de otra herramienta mientras `capacity` sale de `--list-devices`.
- Resuelta en r7 (D-89). Choque original: D-28 convierte el overhead en una calibración por backend con procedencia medida; el SPEC r6 no define ninguna calibración de overhead (usa la convención del motor sin overhead propio).

## Contexto
**Por qué ahora**: D-27 dejó la reserva escribiendo en MiB de VRAM, y P-12
surgió de medir que Gunther **no ve** una GPU que no sea de NVIDIA. No es un
detalle de implementación: es el punto donde el «device» del scheduler deja de
ser una GPU y pasa a ser un presupuesto con nombre.

## Decisión
**Qué**: un device no es «una GPU NVIDIA». Es **un slot con un nombre, un
presupuesto y una sola fuente de medida**. El nombre con el que se le habla al
motor sale del motor; las cifras salen de una única fuente por backend; y
`:system` desaparece del ledger.

#### El nombre lo publica el motor

`llama-server --list-devices` publica el nombre real:

```
CUDA0: NVIDIA GeForce RTX 5080 Laptop GPU (15933 MiB, 15683 MiB free)
```

Ese `CUDA0` es el que acepta `--device`. **No se deriva del índice**:
`CUDA#{device}` vale para CUDA y es **falso** para ROCm, SYCL o Vulkan.

`--main-gpu` sigue siendo un índice, pero es **otra coordenada**: no se
confunde con el nombre del device.

El índice del scheduler es el que acompaña a ese nombre en la lista del motor
. Si la medida viene del sistema y no se puede emparejar el índice del
sistema con el nombre del motor, el device queda `usable: false`: no se
inventa el nombre ni se cruzan coordenadas.

#### Una sola fuente por backend

La invariante es:

```
available = capacity − foreign − gunther_used
```

donde:

- `gunther_used` = suma de los titulares de modelos de Gunther, **excluyendo
  `:system` y `:foreign`**.
- `foreign` = la memoria que no es de los modelos de Gunther, medida **en la
  misma fuente que `capacity`**.

**La fórmula miente si `capacity` viene de una fuente y `free` de otra**. No
se registra la capacidad de `nvidia-smi` y se mide el libre del motor, ni al
revés.

##### Convención A · la del motor

`capacity = total_engine` y `free = free_engine`, los dos de
`--list-devices`:

```
foreign   = max(capacity − free_engine − gunther_used, 0)
available = max(free_engine − gunther_used, 0)
```

El overhead ya está **fuera** de `capacity`: no se resta otra vez y no se
registra `:system`.

##### Convención B · la del sistema

`capacity = total_system` y `free = free_os`, los dos de la misma medición del
sistema (`nvidia-smi` en CUDA):

```
foreign   = max(total_system − free_os − gunther_used + overhead, 0)
available = max(free_os − overhead − gunther_used, 0)
```

El `overhead` va **dentro** de `foreign`, no como titular aparte.

**Y el overhead no es una constante universal**: los 370 MiB son la medida
de CUDA **en esta máquina** (16303 − 370 = 15933, que es exactamente el
total que ve llama-server). En ROCm, SYCL, Vulkan o Metal se mide o se
declara desconocido; **no se hereda**.

#### Memoria unificada

En un backend de memoria unificada no hay una GPU con memoria separada: hay
un presupuesto del sistema. La fórmula es:

```
foreign   = max(total − free − gunther_used, 0)
available = max(free − gunther_used, 0)
```

`foreign` **nunca es 0 por defecto**: se calcula. Si no hay una medida real
de `free`, el device queda `usable: false`; no se pone `free = total`.

#### Sin medición no hay cifra

Si `capacity` o `free` no son enteros **medidos**:

- no se registra el resource, o se registra con `usable: false`;
- el scheduler devuelve `:no_gpu` o `:memory_unknown`;
- **nunca** se devuelve `available = 0` como si fuera una medida.

Un `0` solo es válido si `capacity` y `free` se midieron y la resta da 0 (la
GPU está llena de verdad). «No lo sé» no es «no queda nada».

#### Se retira `:system`

`Gunther.Engine.Resource` deja de adquirir el titular `:system`. Con la
fuente del motor el overhead ya está fuera de `capacity`; con la del
sistema va dentro de `foreign`. **Tenerlo además como titular lo descuenta
dos veces**.

`@overhead_mb` deja de ser una constante global: pasa a ser una
**calibración por backend**, con su procedencia medida. Si no se conoce,
el backend no usa la convención del sistema o queda `usable: false`.

## Alternativas consideradas
#### Lo que esta decisión NO hace

- **Multi-GPU con split** (`--split-mode layer`, `--tensor-split`): sigue en
  P-6. El engine lo hace; el ledger cuenta por device.
- **CPU**: no hay device que reservar; `--device none`.
- **Proveedores remotos**: no ocupan esta GPU; no entran en el ledger.

## Consecuencias
#### Consecuencias

- **P-12 deja de ser una deuda y pasa a ser la implementación de esta
  decisión**. Y toca más ficheros de los que parecía:
  `engine/server.ex`, `engine/fit_params.ex`, `engine/resource.ex`,
  `scheduler.ex`, `scheduler/devices.ex` y `detector/devices.ex`.
- **D-27 deja de decir que `CUDA<N>` es la forma general**: era la
  convención de CUDA, no la del proyecto.
- El **nombre interno del resource** (`resource.ex:2-10`) sigue siendo
  `:cuda0`… `:cuda31` → D-28 tiene que decidir si es el nombre del backend
  o un identificador neutro; no se deja como deuda oculta.

## Verificación
#### Verificación

- `--list-devices` con `CUDA0` → `--device CUDA0`; con ROCm → `ROCm0`,
  **nunca** `CUDA0`.
- **Ningún** resource registra `:system`.
- `unified_memory/0` **no** devuelve `free = total` con `usable: true`.
- `sync_foreign/1` que no puede medir devuelve `:memory_unknown`, y el
  scheduler **no coloca**.
- GPU llena de verdad → `available: 0` **medido**; medición ausente →
  `:memory_unknown`, no 0.
- Un caso por backend simulado con `Gunther.FakeGPU` y una puerta de máquina
  con GPU real.

- **Puertas F0 de las que depende**: G-10, G-11
