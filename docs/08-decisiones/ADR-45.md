# ADR D-45 — Registry por instancia

- **Estado**: aceptada (DP0, r8)
- **Fecha**: 2026-10-25
- **Fuente**: SPEC r8 §2.7, §4.1

## Contexto

Los tests `async: true` y los despliegues con varias instancias necesitan aislamiento. Sin registry por instancia:

- Dos tests que arrancan Gunther chocan (mismo nombre de supervisor, mismo nombre de breaker, misma config).

- Dos instancias en la misma VM chocan.

- El estado de un test contamina el siguiente.

## Decisión

`Gunther.start_link(registry: MyRegistry, name: MyGunther)` aísla dos árboles en la misma VM. Cada test arranca su propio árbol con `async: true`.

Todos los nombres de breaker, bulkhead y rate limiter llevan el prefijo `{Gunther, instance, ...}`.

**Límite conocido**: `Arrea.Registry`, `Arrea.CircuitBreaker.Registry` y la config de Arrea (`config :arrea, :engine`) son **globales** \[V\]. Si `Arrea.CircuitBreaker` no admite umbrales por breaker (G-02), `circuit_breaker.*` queda global y se documenta; la rama alternativa de G-02 evalúa `resiliency`.

## Alternativas consideradas

- **Registry global único**: descartada porque dos instancias chocarían.

- **Sin registry (nombres fijos)**: descartada porque los tests no pueden correr en paralelo.

- **Un registry por tipo de proceso**: descartada porque complica la configuración sin beneficio claro.

## Consecuencias

- Límite conocido: `Arrea.Registry`, `Arrea.CircuitBreaker.Registry` y la config de Arrea son globales (G-02).

- La configuración de breaker puede quedar global.

- Los tests `async: true` son posibles.

- Cada test arranca su propio árbol y lo para al terminar.

## Verificación

- F1 (arranque con registry).
- G-02 (límite de Arrea).

- **Puertas F0 de las que depende**: G-02
