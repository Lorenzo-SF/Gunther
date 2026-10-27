# ADR D-81 — Contexto portable y política de cambio de modelo

- **Estado**: aceptada (DP0, r8)
- **Fecha**: 2026-10-26
- **Fuente**: SPEC §22.12

## Contexto
Al cambiar de modelo, el historial se reenvía completo y no hay resumen incremental ni uso de lo observado en la caché; el dueño quiere retomar sin perder contexto ni reprocesar todo.

## Decisión
`Context.Portable` (hechos fijados, resumen incremental, últimos turnos, referencias) y `context.on_switch` (`resend` por defecto, `portable`, `auto`). Se activa solo con un informe de continuidad válido.

## Alternativas consideradas
Reenviar siempre el historial completo (se mantiene como defecto).

## Consecuencias
`portable_keep_turns`, `min_saving_tokens` y la tolerancia de continuidad son obligatorios y sin defecto.

## Verificación
G-30; F21.

- **Puertas F0 de las que depende**: G-30
