# ADR D-30 — «Mente colmena» como nombre

- **Estado**: aceptada (DP0, r8). Sustituida por D-74 en el nombre (M-03, Q-13)
- **Fecha**: 2026-10-25
- **Fuente**: SPEC r6 §1.3, §10.2; SPEC r8 §0.2, §1.3, §22

- Nota (r8, Q-13): el nombre definitivo es **coral** (`Gunther.Coral`). «Mente colmena» y «mesa camilla» quedan como nombres históricos; `:hive` sobrevive como nombre de una modalidad de la coral. Los nombres `Hive`, `Voice` y `register_voice/3` de r5/r6 no existen como módulos en r8; ver la tabla de renombrado de §0.2 del SPEC r8 y el ADR D-74.

## Contexto

Es una decisión de nomenclatura: el nombre aparece en la tabla de conceptos (§1.3) y en el módulo `Gunther.Hive`.

## Decisión

El SPEC usaba «mente colmena» (y `Gunther.Hive`) para el módulo de voces coordinadas; en r6 era v1.1 experimental (D-56). Una voz no es un agente (D-14).

## Alternativas consideradas

El SPEC r6 no recoge alternativas descartadas para esta decisión; no se inventan.

## Consecuencias

Los nombres `Hive`, `Voice` y `register_voice/3` formaban parte de la API de v1.1 en r5/r6. En r8 (D-74) se sustituyen por `Gunther.Coral` y los cuatro behaviours nuevos de la coral (`:coral_mode`, `:consensus`, `:step`, `:run_store`).

## Verificación

Revisión de API en DP4.

- **Puertas F0 de las que depende**: ninguna
