# ADR D-67 — Perfiles de engine definidos en el nodo

- **Estado**: aceptada (DP0, r8)
- **Fecha**: 2026-10-25
- **SPEC**: SPEC-000-GUNTHER r6

## Contexto
Si el controlador enviara comandos, comprometerlo equivaldría a ejecución remota en el nodo.

## Decisión
El controlador referencia un perfil por id y solo ajusta `allowed_overrides` dentro de máximos; rutas, binarios y entorno los fija el nodo.

## Alternativas consideradas
Comandos libres desde el controlador (descartado).

## Consecuencias
El nodo valida, limita y audita.

## Verificación
F15-01.

- **Puertas F0 de las que depende**: ninguna: se comprueba en F15-01
