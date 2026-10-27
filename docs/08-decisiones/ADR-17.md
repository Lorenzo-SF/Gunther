# ADR D-17 — `Gunther.Provider`: registro, no lista cerrada

- **Estado**: aceptada
- **Decidida**: 2026-10-18, por el dueño (recomendación del agente, aceptada).
- **Fuente**: README original de `08-decisiones` (decidido hasta 2026-10-21; `main` 398a1b9)

## Contexto
**Por qué**: el gateway (fase 8) y MCP (fase 7) van a querer añadir providers
en tiempo de ejecución, y una lista cerrada exige cambio de código + release
por cada provider nuevo. La pérdida de exhaustividad en compile-time se
compensa con el behaviour, que es la misma forma que ya usan los agentes
(D-13, D-14).

## Decisión
**Qué**: los providers se registran en un registro abierto (`Gunther.Registry`,
el mismo patrón que `Policy.Destination` y los agentes), y cada uno implementa
un behaviour `Gunther.Providers.Provider` (chat, embed, models). Añadir un
provider es registrar un módulo, no cambiar código ni hacer una release.

## Alternativas consideradas
El documento original no recoge alternativas descartadas para esta decisión.

## Consecuencias
**Desbloquea**: Fase 7 (MCP), Fase 8 (Gateway), Fase 12 (CLI).

## Verificación
El documento original no define una verificación específica; ver las puertas F0.

- **Puertas F0 de las que depende**: ninguna
