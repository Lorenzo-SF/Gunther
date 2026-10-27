# ADR D-88 — Defecto del refusal y reglas invariantes

- **Estado**: propuesta (resuelta por delegación del dueño en r7)
- **Fecha**: 2026-10-26
- **Fuente**: SPEC §6.9; resuelve J-04 (D-09, D-11)

## Contexto
D-09 y D-11 dejaron el defecto del refusal sin fijar; el ejemplo de §14.1 ya usaba `wait`.

## Decisión
Defecto `[refusal] policy = "wait"` con `wait_ms` 10 000. Ningún valor puede cambiar dos reglas: ninguna política devuelve un modelo vetado, y `:refused_capacity` y `:refused_timeout` llevan `requested_mib`, `available_mib` y `capacity_mib` con `:unknown` cuando no se sabe (nunca un número que signifique «no se sabe»).

## Alternativas consideradas
`fail` como defecto (descartado: con una GPU compartida, esperar a que se libere es más útil que fallar de inmediato; el operador puede cambiarlo).

## Consecuencias
Decisión reversible por configuración.

## Verificación
F5.

- **Puertas F0 de las que depende**: ninguna
