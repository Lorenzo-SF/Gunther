# ADR D-76 — Terminación garantizada y despacho por modelo

- **Estado**: aceptada (DP0, r8)
- **Fecha**: 2026-10-26
- **Fuente**: SPEC §22.5, §22.11

## Contexto
Un grupo de agentes con bucles y reintentos puede no terminar y multiplicar el gasto; además, con pocos modelos cargables a la vez, el orden de las tareas provoca cargas y descargas continuas.

## Decisión
El grafo de aristas es acíclico; la repetición solo existe con `loop` (con `max` obligatorio y tope `coral.loop.max_cap`); toda ejecución tiene `max_steps`, `max_duration_ms` y presupuesto. El despacho puede agrupar tareas por modelo (`group_by_model`) con límite de espera.

## Alternativas consideradas
Grafos con ciclos libres (descartado: no se puede garantizar la terminación).

## Consecuencias
Todos los límites son parámetros con defecto declarado, calibrados con pruebas de carga.

## Verificación
F19: pruebas de límites y de despacho.

- **Puertas F0 de las que depende**: ninguna
