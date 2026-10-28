# Probes de F0

Scripts de las puertas G-01 a G-31. Cada puerta tiene un script reproducible
con un solo comando y su salida íntegra en `output/`.

**Fuera del paquete publicado**: `probes/` no se incluye en el `.hex` (ver
`files:` en `mix.exs`).

## Convención

```bash
./probes/g01_deps.sh        # ejecuta la puerta y escribe output/g01-<fecha>.txt
```

Los scripts usan el toolchain del entorno (`. /workspace/tools/env.sh` fuera del
sandbox) y son deterministas: no dependen de la red salvo que el encabezado de
la puerta lo indique.

## El probe de F2 (los datos que solo salen en una maquina con GPU)

`f2_datos.sh` **no** es una puerta: es la recogida de datos que necesitan los
AC de F2 que no se pueden cerrar en un sandbox sin GPU.

```bash
./probes/f2_datos.sh [RUTA_DEL_GGUF]
```

Trae:

1. la salida real de `llama-server --list-devices` (AC F2-1);
2. las herramientas del sistema (`nvidia-smi`, `rocm-smi`, `vulkaninfo`,
   `system_profiler`): la **convención B** de la medida (AC F2-1);
3. los valores crudos del GGUF (los que lee la fórmula de KV);
4. el `kv_mib` que informa `llama-server` al cargar, con todos los números
   del modelo y del contexto (AC F2-6);
5. y, si hay Elixir, la **comparación** entre ese valor y el de la fórmula de
   `Gunther.Resource.Weight`.

Al final imprime un bloque `===== INICIO DEL BLOQUE =====` /
`===== FIN DEL BLOQUE =====` con todo lo recogido.

No hace daño: no toca los modelos, no borra nada, y el servidor que arranca
para la medida lo para él mismo. Carga el modelo en CPU (`-ngl 0`), así que no
ocupa la VRAM.
