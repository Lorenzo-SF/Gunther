# ADR D-70 — Contrato `Spawner` para procesos largos

- **Estado**: propuesta
- **Fecha**: 2026-10-25
- **SPEC**: SPEC-000-GUNTHER r6

## Contexto
Un `Port` de Erlang no separa stderr de stdout ni mata al hijo con la VM.

## Decisión
Contrato con requisitos R1 a R8 medibles; línea base `Port` con consecuencias documentadas; un candidato se adopta si pasa R1 a R8, tiene versión publicada en los últimos 24 meses y licencia OSI.

## Alternativas consideradas
Fijar una librería de terceros sin evaluar (descartado).

## Consecuencias
El MCP stdio usa `stderr: :inherit`; `llama-server` usa `:merge`.

## Verificación
G-08.

- **Puertas F0 de las que depende**: G-08
