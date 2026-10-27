# ADR D-05 — Las siete hermanas desde su `main`, no desde Hex

- **Estado**: aceptada
- **Decidida**: 2026-10-10, por el dueño.
- **Fuente**: README original de `08-decisiones` (decidido hasta 2026-10-21; `main` 398a1b9)

- **Texto actualizado**: las versiones mínimas vigentes son las de SPEC §0.3 (`arrea ~> 3.0`, `apero ~> 4.0`, `trebejo ~> 2.0`), no las de la primera revisión del plan. Se conserva el texto original.
- Resuelta en r7 (D-91, J-03). Choque original: D-05 decide tomar las hermanas de su `main` (con `override: true` y SHA fijado en `mix.lock`); el SPEC r6 §0.3 las declara como versiones de Hex (`~>`) y §3.7 solo prevé un `mix deps.update` semanal en CI. Hay que decidir si D-05 sigue vigente o queda sustituida por la declaración de §0.3.

## Contexto
**El motivo medido**: lo publicado en Hex era `arrea 3.1.0` y el repo estaba
también en 3.1.0. Mergeado `Arrea.Resource` en `main`, **para Gunther no había
cambiado nada**, y Hex no admite republicar una versión ya publicada. La fase 2
no desbloqueaba la 3 hasta hacer eso a mano.

**Y una trampa que costó un rato**: `botica ~> 2.2` depende de `arrea ~> 3.1`
**desde Hex**. Sin `override: true` el solvedor ve dos Arreas distintas y se
niega. Con el flag, Gunther y botica reciben la misma.

## Decisión
**Qué**: Gunther deja de tomar `apero`, `arrea`, `trebejo`, `batamanta`, `alaja` y
`botica` de Hex y los toma de su `main`.

## Alternativas consideradas
El documento original no recoge alternativas descartadas para esta decisión.

## Consecuencias
**El coste de conocer, escrito en `mix.exs`**: Gunther no recoge automáticamente un
fix de una hermana. `mix deps.update <hermana>` a propósito.

**Lo que NO se cede**: `mix.lock` fija el **SHA exacto** de cada una. La build
sigue siendo reproducible y una build vieja no se rompe sola.

## Verificación
El documento original no define una verificación específica; ver las puertas F0.

- **Puertas F0 de las que depende**: G-01, G-17
