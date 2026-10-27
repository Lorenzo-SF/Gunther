# ADR D-33 — Salidas estructuradas

- **Estado**: propuesta
- **Fecha**: 2026-10-25
- **Fuente**: SPEC §4.2.1

## Contexto
r5 retiró el fallback por prompt al reescribir §4.2 y un provider sin soporte nativo devolvía texto libre con `structured: nil` en silencio (hueco 1 de la evaluación de r5).

## Decisión
`response_format` admite `:text`, `:json` y `{:json_schema, schema}`. Modo `:auto`: nativo si `supports?(:structured_output, model)`; si no, prompt con validación y hasta `structured.max_retries` reintentos con retroalimentación. Invariante: un `{:ok, _}` con formato estructurado nunca lleva `structured: nil`.

## Alternativas consideradas
Descartada por r6: devolver texto libre con `structured: nil` en silencio.

## Consecuencias
El streaming valida al terminar y no puede reintentar tras el commit.

## Verificación
F3-07; CE-01.

- **Puertas F0 de las que depende**: G-12
