# ADR D-29 — El LLM decide (capa `:llm`)

- **Estado**: propuesta
- **Fecha**: 2026-10-25
- **Fuente**: SPEC §6.1, §6.3, §6.11

- **Revisada por D-68** (modelos de decisión especializados, `DecisionSpec`, `DecisionView`). Se conserva el texto original de la decisión; D-68 la refina.

## Contexto
La capa `:llm` es la que opina cuando las baratas (caché, pin, reglas, embedding) no resuelven; su resultado alimenta el ranking de la decisión.

## Decisión
El router tiene una capa `:llm` que ordena candidatos con una llamada a un modelo de decisión. Sin modelo de decisión registrado, la capa no existe (§6.1). `router.llm` admite `never`, `fallback` (defecto) y `always`; con timeout `router.llm_timeout_ms` (§6.3).

## Alternativas consideradas
El SPEC r6 solo recoge la que D-68 descarta: un LLM de propósito general como decisor (permitido únicamente con `router.allow_general = true`). 

## Consecuencias
El coste de la capa se mide en F4, no tiene cifra a priori (§6.1).

## Verificación
F4-05 a F4-10 (SPEC §19).

- **Puertas F0 de las que depende**: G-12, G-18 (vía D-68)
