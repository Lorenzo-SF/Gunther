# ADR D-71 — Alcance fijado por el dueño

- **Estado**: propuesta
- **Fecha**: 2026-10-25
- **SPEC**: SPEC-000-GUNTHER r6

## Contexto
Decisiones del dueño sobre alcance.

## Decisión
Windows fuera. Gunther no descarga ni distribuye modelos; gestiona arranque y parada de los instalados con tope de memoria y de conteo (`placement.max_loaded_models`). El decisor debe ser multilingüe y multi-tipo y no se fija un modelo.

## Alternativas consideradas
—

## Consecuencias
Ninguna licencia de modelo condiciona al paquete. La licencia de Katanemo (texto consultado en otro modelo de la misma empresa) restringe empaquetar el modelo en un framework o gateway; por eso Gunther no incluye modelos.

## Verificación
F2-07, F6-08.

- **Puertas F0 de las que depende**: ninguna: es una decisión de alcance
