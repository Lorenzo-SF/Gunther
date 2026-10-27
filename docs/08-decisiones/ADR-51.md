# ADR D-51 — Pipeline de resiliencia con orden fijo

- **Estado**: propuesta
- **Fecha**: 2026-10-25
- **SPEC**: SPEC-000-GUNTHER r6

## Contexto
r4 delegaba retry, breaker, bulkhead y rate limit sin fijar cómo se componen; el orden cambia el comportamiento.

## Decisión
Orden de fuera a dentro: retry, rate limit, bulkhead, breaker, timeout de intento, llamada (SPEC §2.5), con tabla error→acción.

## Alternativas consideradas
Orden libre por provider (descartado: imprevisible).

## Consecuencias
Los rechazos de bulkhead y rate limit no abren el breaker; el plazo total acota todo.

## Verificación
Una prueba por fila de la tabla (F5-01).

- **Puertas F0 de las que depende**: G-02, G-03, G-04, G-05
