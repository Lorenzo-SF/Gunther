# ADR D-56 — Colmena a v1.1 experimental

- **Estado**: propuesta
- **Fecha**: 2026-10-25
- **SPEC**: SPEC-000-GUNTHER r6

## Contexto
Es el módulo con menos apoyo del resto del documento y el único cuyo valor no se mide con el corpus del router.

## Decisión
v1 se entrega con varios `Classifier` combinados por Borda. La colmena se publica en v1.1 con criterio de promoción medible.

## Alternativas consideradas
Entregarla en v1 (descartado: riesgo alto sin evidencia).

## Consecuencias
Las voces solo deciden por modelos de decisión verificados (D-68).

## Verificación
F17.

- **Puertas F0 de las que depende**: ninguna: se mide en F17 con el corpus de D-68
