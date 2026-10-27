# ADR D-80 — Sobre de contexto `Gunther.Context`

- **Estado**: aceptada (DP0, r8)
- **Fecha**: 2026-10-26
- **Fuente**: SPEC §22.3, §22.14 (G2)

## Contexto
Para que las piezas se integren perfectamente, el consumer, el `trace_id`, el presupuesto, el token de cancelación, la sesión y el ámbito de memoria deben viajar juntos.

## Decisión
`%Gunther.Context{}` único, aceptado por `chat/2`, agentes, tools y RAG. Sin contexto se crea uno por defecto; las opciones explícitas ganan.

## Alternativas consideradas
Seguir pasando opciones sueltas (descartado: se pierden valores entre módulos).

## Consecuencias
No cambia el comportamiento de quien no usa la coral.

## Verificación
F1 (estructura), F3, F14.

- **Puertas F0 de las que depende**: ninguna
