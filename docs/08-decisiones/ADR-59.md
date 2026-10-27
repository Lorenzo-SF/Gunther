# ADR D-59 — Behaviour `Detector`

- **Estado**: aceptada (DP0, r8)
- **Fecha**: 2026-10-25
- **SPEC**: SPEC-000-GUNTHER r6

## Contexto
El diseño de r4 solo cubría NVIDIA.

## Decisión
`Detector` con `devices/1` y `measure/1`; referencias `LlamaCpp`, `Nvidia`, `Rocm`, `Metal`, `Cpu`.

## Alternativas consideradas
Detector único de NVIDIA (descartado).

## Consecuencias
Ampliado por D-65 y D-69.

## Verificación
F2-03, F2-04.

- **Puertas F0 de las que depende**: G-10, G-11
