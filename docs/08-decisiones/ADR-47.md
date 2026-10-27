# ADR D-47 — Integración con el ecosistema (arrea, apero, trebejo)

- **Estado**: aceptada (DP0, r8)
- **Fecha**: 2026-10-25
- **Fuente**: SPEC §3

- **Revisada por §3 de r6**, que reescribe la integración módulo a módulo. Se conserva la idea original de D-47.

## Contexto
r4 daba por hechas capacidades no verificadas.

## Decisión
Cada librería se toca solo desde cinco módulos de frontera (`Command`, `Resilience`, `Cache`, `Config.Loader`, `Platform`); se integra donde ya resuelve el problema y no donde el encaje es forzado.

## Alternativas consideradas
Descartadas por r5 y r6: `Arrea.Resource` como ledger, `SafeCommand` como único punto de ejecución, `Arrea.WorkerPool` para `llama-server`, `Arrea.Retry` (no existe; se usa `Apero.Retry`), reaper por nombre de ejecutable.

## Consecuencias
Las puertas G de §3.7 convierten cada hecho no verificado en un test con rama alternativa.

## Verificación
G-01 a G-07, G-17, G-21.

- **Puertas F0 de las que depende**: G-01 a G-07, G-17, G-21
