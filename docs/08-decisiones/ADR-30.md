# ADR D-30 — «Mente colmena» como nombre

- **Estado**: propuesta
- **Fecha**: 2026-10-25
- **Fuente**: SPEC §1.3, §10.2

## Contexto
Es una decisión de nomenclatura: el nombre aparece en la tabla de conceptos (§1.3) y en el módulo `Gunther.Hive`.

## Decisión
El SPEC usa «mente colmena» (y `Gunther.Hive`) para el módulo de voces coordinadas; en r6 es v1.1 experimental (D-56). Una voz no es un agente (D-14).

## Alternativas consideradas
El SPEC r6 no recoge alternativas descartadas para esta decisión; no se inventan.

## Consecuencias
Los nombres `Hive`, `Voice` y `register_voice/3` forman parte de la API de v1.1.

## Verificación
Revisión de API en DP4.

- **Puertas F0 de las que depende**: ninguna
