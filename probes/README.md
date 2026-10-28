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
