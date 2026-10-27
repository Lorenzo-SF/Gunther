# ADR D-39 — Evaluación como contrato

- **Estado**: propuesta
- **Fecha**: 2026-10-25
- **Fuente**: SPEC §4.11, §16.3, §6.11

## Contexto
La evaluación forma parte del producto, no de un proyecto aparte.

## Decisión
`Gunther.Eval.run(spec, opts)` ejecuta un corpus JSONL y devuelve un informe reproducible con métricas definidas (exactitud top-1, percentiles por rango más próximo, recall, MRR, nDCG). Es el mecanismo de verificación de los modelos de decisión (D-68, D-72).

## Alternativas consideradas
El SPEC r6 no recoge alternativas descartadas para esta decisión; no se inventan.

## Consecuencias
Los informes se escriben de forma atómica y se ligan al hash del modelo y de la configuración.

## Verificación
F4-09, F10-02, F10-03.

- **Puertas F0 de las que depende**: G-12, G-18 (vía D-68)
