# ADR D-37 — Sesiones como contrato

- **Estado**: propuesta
- **Fecha**: 2026-10-25
- **Fuente**: SPEC §5.13, §7.1, §4.6

## Contexto
La sesión es un hilo conversacional cuyo almacenamiento es intercambiable.

## Decisión
`Gunther.SessionStore` es un behaviour (`load/save/delete/list`) con referencias `Memory` (ETS) y `Disk` (`Apero.File`, escritura atómica). Las sesiones tienen estados `:open`, `:compacting`, `:closed`, topes configurables y `open/2` que reabre desde el store.

## Alternativas consideradas
El SPEC r6 no recoge alternativas descartadas para esta decisión; no se inventan.

## Consecuencias
El mismo contrato sirve para el `AgentStore` (con el snapshot de CE-07).

## Verificación
F8-01, F8-02.

- **Puertas F0 de las que depende**: ninguna
