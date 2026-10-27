# ADR D-45 — Registry por instancia

- **Estado**: propuesta
- **Fecha**: 2026-10-25
- **Fuente**: SPEC §2.7, §4.1

## Contexto
Los tests `async: true` y los despliegues con varias instancias necesitan aislamiento.

## Decisión
`Gunther.start_link(registry: MyRegistry, name: MyGunther)` aísla dos árboles en la misma VM. Todos los nombres de breaker, bulkhead y rate limiter llevan el prefijo `{Gunther, instance, ...}`. Límite conocido: `Arrea.Registry`, `Arrea.CircuitBreaker.Registry` y la config de Arrea son globales.

## Alternativas consideradas
El SPEC r6 no recoge alternativas descartadas para esta decisión; no se inventan.

## Consecuencias
La configuración de breaker puede quedar global (G-02).

## Verificación
F1; G-02.

- **Puertas F0 de las que depende**: G-02
