# ADR D-44 — Caché de completions (retirada de v1)

- **Estado**: aceptada (retirada por P-13 del dueño)
- **Fecha**: 2026-10-25
- **Fuente**: SPEC §2.3, §3.3; respuesta del dueño P-13

## Contexto
El árbol de supervisión incluía `Cache.Completions` como hijo opcional que reutiliza `Gunther.Cache`; ninguna sección definía su clave, TTL, condiciones de uso ni aislamiento por consumer.

## Decisión
**`Cache.Completions` sale de v1** y pasa a `docs/12-roadmap.md`. v1 conserva `Gunther.Cache` y la caché de decisiones (§6.5).

## Alternativas consideradas
Especificarla en v1 (descartado por el dueño).

## Consecuencias
Si vuelve, necesitará clave, TTL, condiciones (por ejemplo, solo con `temperature` cero o `seed`) y aislamiento por consumer, definidos en una decisión nueva.

## Verificación
Ninguno: no se implementa en v1.

- **Puertas F0 de las que depende**: ninguna

## Cambios necesarios en el SPEC (r7)

| # | Sección | Cambio | Estado |
| --- | --- | --- | --- |
| I-23 | §2.3, §3.3 | Quitar `Cache.Completions` del árbol de supervisión y de la descripción de `Gunther.Cache` | aplicada en r7 |
