# ADR D-26 — El cargador del catálogo avisa de claves desconocidas

- **Estado**: aceptada
- **Decidida**: 2026-10-19, por el dueño.
- **Fuente**: README original de `08-decisiones` (decidido hasta 2026-10-21; `main` 398a1b9)

## Contexto
La raíz no es el cuarto campo: es que el cargador no avisaba. Con el aviso,
el cuarto se habría visto solo. Ahora se ve.

## Decisión
**Qué**: `Gunther.Config.Hydrate` ahora emite un `Logger.warning` cuando una
sección (`engine`, `model`, `provider`) tiene claves que no conoce. La causa
de fondo: tres veces el mismo fallo —`typical_latency_s`, `engine_pid`,
`vram_mb`— donde un campo existía en el struct pero nadie lo rellenaba ni
validaba, y el cargador lo ignoraba en silencio.

## Alternativas consideradas
El documento original no recoge alternativas descartadas para esta decisión.

## Consecuencias
**También**: `Model.vram_mb` se hidrata (`spec["vram_mb"]`) y se valida en
el schema (entero no negativo). El template del TOML lo documenta.

## Verificación
El documento original no define una verificación específica; ver las puertas F0.

- **Puertas F0 de las que depende**: ninguna
