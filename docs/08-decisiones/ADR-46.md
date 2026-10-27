# ADR D-46 — Contrato de voces

- **Estado**: propuesta
- **Fecha**: 2026-10-25
- **Fuente**: SPEC §10.2

## Contexto
Las voces opinan por la capa `:llm` mediante modelos de decisión verificados (D-68).

## Decisión
`init(opts)`, `handle_message(message, state)`, `maybe_rank(prompt, candidates, state, ctx)`; `ctx` ofrece `decide/2` y no `chat`; `Hive.tell/2` devuelve `{:error, :not_found}` si la voz no existe; sin `GenServer.call` bloqueante entre voces.

## Alternativas consideradas
El SPEC r6 no recoge alternativas descartadas para esta decisión; no se inventan.

## Consecuencias
Es v1.1 experimental (D-56).

## Verificación
F17.

- **Puertas F0 de las que depende**: ninguna (vía D-68)
