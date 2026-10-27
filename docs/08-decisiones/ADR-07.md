# ADR D-07 — El enrutado sube de fase, y el gateway baja al 8

- **Estado**: aceptada
- **Decidida**: 2026-10-11, por el dueño.
- **Fuente**: README original de `08-decisiones` (decidido hasta 2026-10-21; `main` 398a1b9)

## Contexto
El enrutado estaba **fuera de la tabla** y es el producto: `Scorer` solo tenía
`score/4` para `:rule`, y `:embedding` y `:llm` caían en un catch-all que
devolvía `:miss` mientras `DecisionEngine` ya las llamaba. El
`Gunther.Router.Classifier` —que existe desde la fase 1— **no lo invocaba
nadie**.

El gateway baja porque **va justo detrás de lo que tiene que servir**, y porque
un gateway montado antes del enrutado expone una respuesta que no cambia.

## Decisión
**Qué**: el orden nuevo pone el enrutado en la 3 y el gateway en la 8.

## Alternativas consideradas
El documento original no recoge alternativas descartadas para esta decisión.

## Consecuencias
El documento original no recoge consecuencias adicionales.

## Verificación
El documento original no define una verificación específica; ver las puertas F0.

- **Puertas F0 de las que depende**: ninguna
