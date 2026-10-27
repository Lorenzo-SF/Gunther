# ADR D-58 — Behaviour `Tokenizer`

- **Estado**: aceptada (DP0, r8)
- **Fecha**: 2026-10-25
- **SPEC**: SPEC-000-GUNTHER r6

## Contexto
La compactación y `max_prompt_tokens` exigen contar tokens.

## Decisión
Contador exacto del provider, `Tokenizer` registrado, o modo `approximate` calibrado por modelo; sin calibración, el modo aproximado no está disponible.

## Alternativas consideradas
Aproximar por caracteres con un margen fijo (descartado: sin fundamento).

## Consecuencias
Un modelo sin contador ni calibración sale del conjunto cuando se necesita contar.

## Verificación
G-12; F3-09, F8-05.

- **Puertas F0 de las que depende**: G-12
