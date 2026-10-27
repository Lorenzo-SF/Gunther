# ADR D-54 — MCP en la revisión 2026-07-28 con compatibilidad 2025-11-25

- **Estado**: propuesta
- **Fecha**: 2026-10-25
- **SPEC**: SPEC-000-GUNTHER r6

## Contexto
La revisión vigente elimina sesiones y el handshake `initialize` (verificado en el changelog oficial).

## Decisión
El servidor implementa 2026-07-28 sin estado y ofrece, opcional y desactivado por defecto, un modo compatible con 2025-11-25 que sí mantiene sesiones con tope.

## Alternativas consideradas
Solo 2025-11-25 (descartado: obsoleta). Solo 2026-07-28 (descartado: rompe a clientes que no han migrado).

## Consecuencias
La versión soportada vive en una constante con aviso semanal de CI si aparece otra revisión.

## Verificación
G-15; F7-04 y F7-05.

- **Puertas F0 de las que depende**: G-15
