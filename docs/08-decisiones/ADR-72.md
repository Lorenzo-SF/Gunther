# ADR D-72 — Decisor agnóstico y personalizable; verificación relativa a línea base

- **Estado**: aceptada (DP0, r8)
- **Fecha**: 2026-10-25
- **SPEC**: SPEC-000-GUNTHER r6

## Contexto
El dueño pide que el decisor sea customizable y agnóstico, y no sabe qué umbrales fijar.

## Decisión
El código no contiene nombres de modelos; plantilla, parser, salida e idiomas son configuración; las recomendaciones viven en la documentación. Un decisor se verifica por idioma requerido contra la mejor línea base (fallback, reglas más fallback) con el límite inferior del intervalo de Wilson al 95 % de confianza, también sobre casos adversarios.

## Alternativas consideradas
Umbrales absolutos fijados a mano (descartado: arbitrarios). Verificar con datos sintéticos únicamente (solo con permiso expreso).

## Consecuencias
El operador solo declara los idiomas que necesita; Gunther ofrece herramientas de corpus.

## Verificación
F4-09, F10-03.

- **Puertas F0 de las que depende**: G-12, G-18
