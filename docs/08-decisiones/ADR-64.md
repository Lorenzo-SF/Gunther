# ADR D-64 — Regla de no-suposición y lint de documento

- **Estado**: propuesta
- **Fecha**: 2026-10-25
- **SPEC**: SPEC-000-GUNTHER r6

## Contexto
El dueño exige que nada se dé por hecho, estime o imagine.

## Decisión
Toda afirmación externa lleva [V] con fuente, [V5] o [G] con test y ramas; toda cifra es parámetro, fórmula o umbral del dueño; lint de cadenas prohibidas en CI.

## Alternativas consideradas
Revisión manual (descartado: no es comprobable).

## Consecuencias
El diseño no depende de cuál sea el resultado de una puerta.

## Verificación
`scripts/doc_lint.sh`; N-09.

- **Puertas F0 de las que depende**: ninguna: se comprueba con `scripts/doc_lint.sh`
