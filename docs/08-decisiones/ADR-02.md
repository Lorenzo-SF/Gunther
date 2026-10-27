# ADR D-02 — Taxonomía de skills cerrada

- **Estado**: aceptada (DP0, r8; Q-16)
- **Decidida**: no consta en el documento original; ratificada en r8
- **Fuente**: SPEC-000-GUNTHER r8 §1.3

- Nota (r8, Q-16): **el documento original de decisiones no contiene esta decisión**: allí D-02 es `exclusive` (ver ADR D-02b). El SPEC r6 le asigna a D-02 la taxonomía cerrada de skills y mueve `exclusive` a D-02b. En DP0 (r8) el dueño ratificó la taxonomía cerrada con estas razones: (1) previsibilidad del catálogo; (2) filtros rápidos del router; (3) ampliar la lista es un cambio de contrato deliberado (SPEC §4.14).

## Contexto

El SPEC distingue «skill» (qué sabe hacer un modelo) de «recurso» (memoria de un device), porque ambos se llamaban «capacidad». En el código se usan `capabilities` para skills y `vram_mb` para recursos (§1.3).

## Decisión

La taxonomía de skills es **cerrada**: `:code`, `:reasoning`, `:redaction`, `:vision`, `:audio`, `:tools`, `:embeddings` (§1.3). Una skill fuera de la taxonomía no es válida en el catálogo. Ampliar la lista es un cambio de contrato (SPEC §4.14).

## Alternativas consideradas

El SPEC r6 no recoge alternativas descartadas para esta decisión. En DP0 (r8) el dueño confirmó que no se abre la taxonomía en v1: la lista cubre los siete skills que el router necesita filtrar y validar; una octava skill exige versión mayor.

## Consecuencias

Una skill fuera de la taxonomía no es válida en el catálogo; ampliar la lista es un cambio de contrato (SPEC §4.14).

## Verificación

Validación del catálogo (§14, F1-01).

- **Puertas F0 de las que depende**: ninguna
