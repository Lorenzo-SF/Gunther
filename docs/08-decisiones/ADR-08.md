# ADR D-08 — `one_for_all` y `rest_for_one` se escribieron como si fueran distintos

- **Estado**: aceptada
- **Decidida**: 2026-10-11.
- **Fuente**: README original de `08-decisiones` (decidido hasta 2026-10-21; `main` 398a1b9)

## Contexto
Los dos nombres estaban en el plan desde el principio. No se quitó ninguno: se dejó
**un solo modo implementado** y el otro escrito como lo que es.

**Una verdad, un sitio**: el `@moduledoc` de `Policy` lo dice y el test lo
demuestra.

## Decisión
**Qué**: documentado que **son el mismo resultado** con peticiones de una vez, y
que la diferencia solo aparece con un destino que pueda ceder el turno.

## Alternativas consideradas
El documento original no recoge alternativas descartadas para esta decisión.

## Consecuencias
El documento original no recoge consecuencias adicionales.

## Verificación
El documento original no define una verificación específica; ver las puertas F0.

- **Puertas F0 de las que depende**: ninguna
