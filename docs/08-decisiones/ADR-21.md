# ADR D-21 — `:degrade` se mantiene declarado y se reinterpreta al existir la cobertura

- **Estado**: aceptada
- **Decidida**: 2026-10-18, por el dueño (recomendación del agente, aceptada).
- **Fuente**: README original de `08-decisiones` (decidido hasta 2026-10-21; `main` 398a1b9)

- **Sustituida por D-57** (ya no es un error, es un warning) **y por D-68** (capa `:llm` con `DecisionSpec`). Se conserva el texto original.

## Contexto
**Por qué**: no borrar una decisión del dueño sin medir antes; y no implementar
algo que quizá se colapse en lo que ya hay.

## Decisión
**Qué**: `:degrade` sigue en el tipo del refusal (D-09) y sigue sin ser
alcanzable. Cuando exista el enrutado por cobertura, «degradar» es simplemente
pedirle al scorer que elija el siguiente candidato capaz (excluyendo el que
falló). Eso hace que `:degrade` deje de ser un tercer valor de la estrategia
y se convierta en comportamiento automático del enrutado. D-09 pasaría de «tres
estrategias» a «dos, y el tercero es cómo funciona el enrutado». Se mantiene
declarado hasta que la cobertura exista y se pueda medir si alguien lo echa de
menos.

## Alternativas consideradas
El documento original no recoge alternativas descartadas para esta decisión.

## Consecuencias
El documento original no recoge consecuencias adicionales.

## Verificación
El documento original no define una verificación específica; ver las puertas F0.

- **Puertas F0 de las que depende**: ninguna
