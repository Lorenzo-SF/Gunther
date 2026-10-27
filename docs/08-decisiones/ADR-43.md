# ADR D-43 — Contexto gestionado

- **Estado**: propuesta
- **Fecha**: 2026-10-25
- **Fuente**: SPEC §7.3, §7.5, §7.6

## Contexto
El contexto que entra al modelo lo gestiona Gunther con topes explícitos.

## Decisión
Orden de ensamblado del prompt, estrategias de compactación (`:none`, `:truncate`, `:summary`, `{:custom, mod}`), reglas para no partir un par `tool_call`+`tool_result`, y contadores de tokens exactos o calibrados.

## Alternativas consideradas
El SPEC r6 no recoge alternativas descartadas para esta decisión; no se inventan.

## Consecuencias
Sin contador ni calibración, un modelo no puede participar cuando se necesita contar tokens (D-58).

## Verificación
F8-04, F8-05.

- **Puertas F0 de las que depende**: G-12
