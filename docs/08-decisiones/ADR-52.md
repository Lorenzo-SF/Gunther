# ADR D-52 — Failover entre candidatos

- **Estado**: propuesta
- **Fecha**: 2026-10-25
- **SPEC**: SPEC-000-GUNTHER r6

## Contexto
Sin ranking completo no hay segundo intento cuando un provider falla.

## Decisión
`Decision.ranked` lleva todos los candidatos elegibles ordenados; el failover consume esa lista hasta `router.max_failovers`.

## Alternativas consideradas
Fallar sin segundo intento (descartado).

## Consecuencias
El presupuesto y el plazo se acumulan entre saltos.

## Verificación
F5-03.

- **Puertas F0 de las que depende**: ninguna: depende solo de G-02 a G-05 a través de D-51
