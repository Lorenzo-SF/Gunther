# ADR D-83 — Reanudación al menos una vez con registro de efectos

- **Estado**: propuesta
- **Fecha**: 2026-10-26
- **Fuente**: SPEC §22.11

## Contexto
Reanudar una ejecución tras una caída puede repetir llamadas con efectos externos.

## Decisión
Reanudación al menos una vez por paso. Registro de intención antes y de resultado después para tools con `side_effects: :unsafe` (defecto); una intención sin resultado queda `uncertain` y se resuelve con `on_uncertain` (`:gate` por defecto o `:fail`).

## Alternativas consideradas
Repetir siempre el paso (descartado: repite efectos). Exactamente una vez (descartado: no se puede garantizar con efectos externos).

## Consecuencias
`Tools.register/2` gana `side_effects` (G7).

## Verificación
F19; N-18.

- **Puertas F0 de las que depende**: ninguna
