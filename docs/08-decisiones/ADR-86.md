# ADR D-86 — Evoluciones propuestas para Arrea

- **Estado**: aceptada (DP0, r8)
- **Fecha**: 2026-10-26
- **Fuente**: SPEC §22.15

## Contexto
Los workers y los agentes comparten gran parte de su arquitectura; el dueño pide sugerir cambios en Arrea que no modifiquen su dominio.

## Decisión
Propuestas A-1 a A-8: suscripción con filtro, identificadores no atómicos, módulo de worker propio de larga vida, petición-respuesta con correlación, buzón máximo, grupos con plazo y cancelación común, instancia nombrada y metadatos tipados de comunicación. Todo lo específico de LLM queda en Gunther.

## Alternativas consideradas
Mover lógica de LLM a Arrea (descartado: cambia su dominio).

## Consecuencias
Cada propuesta se contrasta con el código fuente en G-28 antes de ofrecerse.

## Verificación
G-28.

- **Puertas F0 de las que depende**: G-28
