# ADR D-46 — Contrato de voces

- **Estado**: aceptada (DP0, r8). Revisada por D-74 (M-03, Q-13)
- **Fecha**: 2026-10-25
- **Fuente**: SPEC r6 §10.2; SPEC r8 §4.9, §22

- Nota (r8, Q-13): el contrato de «voz» de r5/r6 se transforma en el contrato de **miembro de la modalidad `:hive`** de la coral. `maybe_rank/3` sobrevive como método del miembro; `Hive.tell/2` pasa a `Coral.tell/2`; `Hive.broadcast/1` pasa a `Coral.broadcast/1`. El `ctx` del miembro ofrece `decide/2` y no `chat`. Sin `GenServer.call` bloqueante entre miembros. La autoridad de cada miembro sobre el ranking sigue siendo la de D-68: solo ordena, no juzga.

## Contexto

Las voces opinan por la capa `:llm` mediante modelos de decisión verificados (D-68).

## Decisión

`init(opts)`, `handle_message(message, state)`, `maybe_rank(prompt, candidates, state, ctx)`; `ctx` ofrece `decide/2` y no `chat`; `Hive.tell/2` devuelve `{:error, :not_found}` si la voz no existe; sin `GenServer.call` bloqueante entre voces.

## Alternativas consideradas

El SPEC r6 no recoge alternativas descartadas para esta decisión; no se inventan.

## Consecuencias

Es v1.1 experimental (D-56), entregada como modalidad `:hive` de la coral (D-74) en F18-F22.

## Verificación

F18 (antes F17 en r5/r6). `ctx.decide/2` comprobado por el `ContractTest` del miembro.

- **Puertas F0 de las que depende**: ninguna (vía D-68)
