# ADR D-68 — Modelos de decisión especializados con autoridad acotada

- **Estado**: aceptada (DP0, r8)
- **Fecha**: 2026-10-25
- **SPEC**: SPEC-000-GUNTHER r6

## Contexto
El dueño exige que el router y la colmena se apoyen en modelos especializados en decisiones; existen ataques publicados que redirigen a los routers.

## Decisión
Todo decisor es un `Classifier` con `DecisionSpec`; solo ve texto de autoría del caller; solo ordena dentro del conjunto que dejan `veto` y `force`; salida de forma fija con abstención ante salida inválida; se activa tras verificación.

## Alternativas consideradas
Un LLM de propósito general como decisor (permitido solo con `router.allow_general`). Decidir privacidad con el modelo (descartado: la privacidad son reglas).

## Consecuencias
Sin informe válido, la capa `:llm` queda saltada.

## Verificación
F4-05 a F4-10.

- **Puertas F0 de las que depende**: G-12, G-18
