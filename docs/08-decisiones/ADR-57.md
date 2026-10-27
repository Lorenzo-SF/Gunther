# ADR D-57 — Warnings en `Response`; `:degraded` deja de ser error

- **Estado**: propuesta
- **Fecha**: 2026-10-25
- **SPEC**: SPEC-000-GUNTHER r6

## Contexto
r4 listaba `:degraded` como error con HTTP 200: contradictorio.

## Decisión
`Response.warnings` y un campo booleano `degraded` con regla escrita.

## Alternativas consideradas
Mantener errores con 200 (descartado).

## Consecuencias
El consumidor distingue respuesta degradada sin inspeccionar warnings.

## Verificación
F3-01.

- **Puertas F0 de las que depende**: ninguna: es una decisión de contrato
