# ADR D-56 — Colmena a v1.1 experimental

- **Estado**: aceptada (DP0, r8). Sustituida por D-74 (M-03, Q-13)
- **Fecha**: 2026-10-25
- **SPEC**: SPEC r6 §10.2; SPEC r8 §22

- Nota (r8, Q-13): «colmena» pasa a ser la **modalidad `:hive` de la coral** (D-74). El criterio de promoción y la entrega posterior a 1.0 se mantienen: la modalidad `:hive` se entrega en F18-F22 con el resto de la coral. La numeración F17 de r5/r6 se sustituye por F18-F22.

## Contexto

Es el módulo con menos apoyo del resto del documento y el único cuyo valor no se mide con el corpus del router.

## Decisión

v1 se entrega con varios `Classifier` combinados por Borda. La colmena se publica en v1.1 con criterio de promoción medible. En r8 la colmena es la modalidad `:hive` de la coral (D-74) y se entrega en F18-F22.

## Alternativas consideradas

Entregarla en v1 (descartado: riesgo alto sin evidencia).

## Consecuencias

Los miembros de la modalidad `:hive` solo deciden por modelos de decisión verificados (D-68). El criterio de promoción se mide con el corpus del router.

## Verificación

F18-F22 (antes F17 en r5/r6).

- **Puertas F0 de las que depende**: ninguna. Se mide en F18-F22 con el corpus de D-68.
