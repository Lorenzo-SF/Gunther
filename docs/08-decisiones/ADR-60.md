# ADR D-60 — Modelo de amenazas; gateway en loopback por defecto

- **Estado**: aceptada (DP0, r8)
- **Fecha**: 2026-10-25
- **SPEC**: SPEC-000-GUNTHER r6

## Contexto
r4 no tenía modelo de amenazas.

## Decisión
SPEC §15 con amenazas, controles y pruebas; el gateway escucha en loopback por defecto y exige clave y TLS fuera de él.

## Alternativas consideradas
Seguridad ad hoc (descartado).

## Consecuencias
Lista de seguridad ejecutable en F16.

## Verificación
`07-seguridad-checklist.md`.

- **Puertas F0 de las que depende**: G-23 (auditoría de dependencias)
