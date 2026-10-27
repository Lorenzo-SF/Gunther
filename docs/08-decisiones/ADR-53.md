# ADR D-53 — Selector y Placer separados

- **Estado**: aceptada (DP0, r8)
- **Fecha**: 2026-10-25
- **SPEC**: SPEC-000-GUNTHER r6

## Contexto
r4 usaba `Scheduler` para dos trabajos distintos: reparto justo y colocación en GPU.

## Decisión
`Selector` (reparto entre candidatos elegibles, estado por consumer) y `Placer` (colocación en devices).

## Alternativas consideradas
Un único scheduler (descartado: dos responsabilidades con ciclos de vida distintos).

## Consecuencias
El `Selector` es extensión pública; el `Placer` es interno.

## Verificación
F4-04, F2-07.

- **Puertas F0 de las que depende**: ninguna: es una decisión de estructura interna
