# ADR D-65 — Identidad física de dispositivos y detector por defecto del propio engine

- **Estado**: aceptada (DP0, r8)
- **Fecha**: 2026-10-25
- **SPEC**: SPEC-000-GUNTHER r6

## Contexto
El nombre de backend no identifica un GPU físico: dos backends pueden ver el mismo GPU y contar su memoria dos veces.

## Decisión
El ledger se indexa por `physical_id`; mapeo obligatorio con más de un device; capacidad = mínimo de los totales; el detector por defecto ejecuta `--list-devices` del binario que lanzará el engine.

## Alternativas consideradas
Indexar por nombre de backend (descartado: doble conteo). Detector solo de fabricante (descartado: no cubre todos los backends).

## Consecuencias
Memoria unificada exige `max_mib` y `reserve_mib`.

## Verificación
G-10, G-11; F2.

- **Puertas F0 de las que depende**: G-10, G-11
