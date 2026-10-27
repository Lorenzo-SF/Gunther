# ADR D-41 — Reparto en v1 (Selector + Placer)

- **Estado**: aceptada (renombrada por P-12 del dueño)
- **Fecha**: 2026-10-25
- **Fuente**: SPEC §2.1, §5.8, §11.4; D-53; respuesta del dueño P-12

## Contexto
El SPEC declaraba que el «scheduler» era el eje del producto. Desde D-53 se parte en `Selector` (reparto entre candidatos elegibles, estado por consumer) y `Placer` (colocación en devices); el módulo `Scheduler` ya no existe.

## Decisión
Hay reparto de carga entre candidatos desde v1. La decisión pasa a llamarse **«Reparto en v1 (Selector + Placer)»**. Texto de §2.1: «El reparto es el eje: Selector (equidad) + Placer (colocación)».

## Alternativas consideradas
El SPEC r6 no recoge alternativas descartadas.

## Consecuencias
Desaparece el nombre «Scheduler» de la decisión y del SPEC.

## Verificación
F4-04, F2-07.

- **Puertas F0 de las que depende**: ninguna

## Cambios necesarios en el SPEC (r7)

| # | Sección | Cambio | Estado |
| --- | --- | --- | --- |
| I-22 | §1.4 (D-41), §2.1 | Renombrar D-41 y sustituir la frase «El scheduler es el eje» por el texto de arriba | aplicada en r7 |
