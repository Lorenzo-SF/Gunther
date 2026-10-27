# ADR D-69 — Backends GPU soportados en v1

- **Estado**: aceptada (DP0, r8)
- **Fecha**: 2026-10-25
- **SPEC**: SPEC-000-GUNTHER r6

## Contexto
El dueño pidió CUDA, Vulkan, ROCm y Metal.

## Decisión
v1 soporta CUDA, Vulkan, ROCm, Metal y CPU con matriz de capacidades; otros backends se añaden implementando `Detector` y un perfil de `ArgsBuilder`.

## Alternativas consideradas
Incluir SYCL y OpenCL (descartado: sin datos de uso habitual).

## Consecuencias
La documentación declara por backend si está validado en hardware o solo con fixtures.

## Verificación
G-10, G-11; `03-estrategia-de-pruebas.md`.

- **Puertas F0 de las que depende**: G-10, G-11
