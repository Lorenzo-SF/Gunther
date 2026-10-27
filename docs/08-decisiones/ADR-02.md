# ADR D-02 — Taxonomía de skills cerrada

- **Estado**: propuesta
- **Decidida**: no consta en el documento original
- **Fuente**: SPEC-000-GUNTHER r6 §1.3

- Pendiente (Q-16, no bloquea): **el documento original de decisiones no contiene esta decisión**: allí D-02 es `exclusive` (ver ADR D-02b). El SPEC r6 le asigna a D-02 la taxonomía cerrada de skills y mueve `exclusive` a D-02b. Hay que confirmar la numeración y aportar el porqué de la taxonomía, que el SPEC no recoge.

## Contexto
El SPEC distingue «skill» (qué sabe hacer un modelo) de «recurso» (memoria de un device), porque ambos se llamaban «capacidad». En el código se usan `capabilities` para skills y `vram_mb` para recursos (§1.3).

## Decisión
La taxonomía de skills es **cerrada**: `:code`, `:reasoning`, `:redaction`, `:vision`, `:audio`, `:tools`, `:embeddings` (§1.3).

## Alternativas consideradas
El SPEC r6 no recoge alternativas descartadas para esta decisión.

## Consecuencias
Una skill fuera de la taxonomía no es válida en el catálogo; ampliar la lista es un cambio de contrato (SPEC §4.14).

## Verificación
Validación del catálogo (§14, F1-01).

- **Puertas F0 de las que depende**: ninguna
