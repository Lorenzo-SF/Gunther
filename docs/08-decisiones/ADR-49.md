# ADR D-49 — Un paquete, dependencias opcionales y CI de fronteras

- **Estado**: aceptada (DP0, r8)
- **Fecha**: 2026-10-25
- **SPEC**: SPEC-000-GUNTHER r6

## Contexto
Gunther tiene un núcleo y módulos opcionales (gateway, MCP servidor, RAG, agentes, nodo).

## Decisión
Un único paquete Hex con dependencias `optional: true` y namespaces estrictos; `mix xref graph` y grep en CI comprueban las fronteras.

## Alternativas consideradas
Varios paquetes desde el inicio (descartado: coste de coordinación antes de saber si duele).

## Consecuencias
Si el paquete duele, se parte en apps. Cada módulo opcional falla con `config_error` claro si falta su dependencia.

## Verificación
Job `boundaries` de CI.

- **Puertas F0 de las que depende**: G-01
