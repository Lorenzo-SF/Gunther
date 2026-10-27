# ADR D-82 — Afinidad de caché en el router

- **Estado**: propuesta
- **Fecha**: 2026-10-26
- **Fuente**: SPEC §22.12

## Contexto
Cambiar de modelo puede invalidar la caché; el router hoy no lo tiene en cuenta.

## Decisión
`router.affinity = "off"` (defecto) o `"prefer"` con un peso obligatorio: preferencia blanda entre candidatos elegibles, nunca sobre veto, force ni pin.

## Alternativas consideradas
Fijar el modelo de una sesión (descartado: rompe el enrutado).

## Consecuencias
Depende de cómo cada provider conserva e invalida su caché, que no está verificado.

## Verificación
G-29; F21.

- **Puertas F0 de las que depende**: G-29
