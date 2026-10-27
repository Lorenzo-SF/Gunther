# ADR D-79 — Consenso como behaviour

- **Estado**: propuesta
- **Fecha**: 2026-10-26
- **Fuente**: SPEC §22.8

## Contexto
El consenso entre modelos puede lograrse de formas distintas y no hay una medida objetiva de acuerdo sobre texto libre.

## Decisión
`Gunther.Coral.Consensus` es un behaviour registrable con estrategias integradas (`:majority`, `:weighted`, `:judge`, `:synthesis`, `:rounds`, `:borda`). El consenso sobre texto libre solo se obtiene mediante juez o síntesis; el comportamiento sin consenso es configuración.

## Alternativas consideradas
Una medida de similitud semántica fija (descartado: sin umbral objetivo; puede añadirse como estrategia de terceros).

## Consecuencias
Una respuesta con consenso no garantiza que sea correcta (R-14).

## Verificación
F19.

- **Puertas F0 de las que depende**: ninguna
