# ADR D-85 — Ganchos G1 a G9 antes de 1.0

- **Estado**: propuesta
- **Fecha**: 2026-10-26
- **Fuente**: SPEC §22.14

## Contexto
La coral puede publicarse después de 1.0, pero requiere puntos previstos en la API; añadirlos después exigiría versión mayor.

## Decisión
Se incorporan en v1: `opts.require`, `Gunther.Context`, eventos y supervisión externa de agentes, `Session.last_call` y `Decision.affinity`, presupuesto jerárquico, prefijo de telemetría, `side_effects` y permisos por rol de tools, autor y versión en `Memory`, y cuatro behaviours registrables.

## Alternativas consideradas
Esperar a la coral (descartado: riesgo de versión mayor).

## Consecuencias
Cada gancho tiene su fase de v1 en la tabla de §22.14.

## Verificación
F1, F3, F4, F5, F7, F8, F14.

- **Puertas F0 de las que depende**: ninguna
