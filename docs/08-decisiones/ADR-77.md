# ADR D-77 — Pizarra de ejecución

- **Estado**: aceptada (DP0, r8)
- **Fecha**: 2026-10-26
- **Fuente**: SPEC §22.6

## Contexto
La memoria KV de §7.2 es un mapa en memoria sin versión, autor ni suscripción, y D-22 original definía autor y «sustituido por» que r6 dejó fuera (J-11).

## Decisión
`Board` por ejecución: entradas con versión, autor y paso; escritura con comparación y cambio; suscripción acotada a la ejecución; acceso por rol; límites con error explícito; promoción explícita a `Memory`.

## Alternativas consideradas
Usar `Memory` KV tal cual (descartado: sin versión ni suscripción).

## Consecuencias
Resuelve el hueco de comunicación por datos entre agentes y relaciona con J-11.

## Verificación
F18; G8 (autor y versión opcionales en `Memory`).

- **Puertas F0 de las que depende**: ninguna
