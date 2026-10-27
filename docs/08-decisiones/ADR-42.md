# ADR D-42 — Cancelación propagada

- **Estado**: propuesta
- **Fecha**: 2026-10-25
- **Fuente**: SPEC §2.9, §4.5

## Contexto
Una petición cancelada debe detener a todos los procesos que trabajan para ella.

## Decisión
`Gunther.Cancel.new/0` devuelve un token respaldado por `:atomics`; `Gunther.cancel/1` lo activa; los providers consultan `opts.cancelled?` entre chunks; las tareas hijas se enlazan al token. `stream!/2` limpia sus procesos al abandonarse.

## Alternativas consideradas
El SPEC r6 no recoge alternativas descartadas para esta decisión; no se inventan.

## Consecuencias
Invariante N-14: ningún proceso vivo tras `stream.cancel_grace_ms`.

## Verificación
F1-08, F3-08.

- **Puertas F0 de las que depende**: ninguna
