# ADR D-19 — `rest_for_one`: no se implementa

- **Estado**: aceptada
- **Decidida**: 2026-10-18, por el dueño (recomendación del agente, aceptada).
- **Fuente**: README original de `08-decisiones` (decidido hasta 2026-10-21; `main` 398a1b9)

## Contexto
**Por qué**: un agente que cede el turno a otro no existe hoy. La mesa camilla
(fase 9) es el primer candidato; si allí aparece la necesidad, se reabre.

## Decisión
**Qué**: `rest_for_one` no se implementa. Sin caso de uso real, YAGNI.

## Alternativas consideradas
El documento original no recoge alternativas descartadas para esta decisión.

## Consecuencias
**Se revisará cuando**: la mesa camilla (fase 9) muestre un caso donde un
agente deba caer junto a otro.

## Verificación
El documento original no define una verificación específica; ver las puertas F0.

- **Puertas F0 de las que depende**: ninguna
