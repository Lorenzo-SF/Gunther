# ADR D-61 — Parada que apaga engines propios; reaper por marca

- **Estado**: aceptada (DP0, r8)
- **Fecha**: 2026-10-25
- **SPEC**: SPEC-000-GUNTHER r6

## Contexto
Matar por nombre de ejecutable puede cargarse el `llama-server` del usuario; dejar engines vivos tras cada parada retiene VRAM.

## Decisión
Todo proceso lanzado lleva `--alias gunther-<instancia>-<alias>`; `stop/1` apaga los engines propios; la reconciliación de 5 pasos solo adopta o mata lo que supera la verificación de identidad.

## Alternativas consideradas
Matar por nombre (descartado: peligroso).

## Consecuencias
Un PID reutilizado nunca recibe señales.

## Verificación
G-13; F6-06.

- **Puertas F0 de las que depende**: G-13
