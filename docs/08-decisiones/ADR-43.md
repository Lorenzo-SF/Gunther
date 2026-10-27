# ADR D-43 — Contexto gestionado

- **Estado**: aceptada (DP0, r8)
- **Fecha**: 2026-10-25
- **Fuente**: SPEC r8 §7.3, §7.5, §7.6

## Contexto

El contexto que entra al modelo lo gestiona Gunther con topes explícitos. Sin gestión del contexto:

- El prompt se desborda (`:context_overflow`).

- Un par `tool_call` + `tool_result` se puede partir, corrompiendo el historial.

- Los tokens se cuentan mal (subestimar → overflow; sobreestimar → gasto innecesario).

- La compactación es ad-hoc.

## Decisión

**Orden de ensamblado del prompt** (§7.3): `system` → plantilla versionada (`prompt:`) → memoria (hechos) → RAG (con citas) → historial de sesión → mensaje actual.

**Estrategias de compactación** (§7.5):

- `:none`: si no cabe, `:context_overflow`.

- `:truncate`: descarta turnos antiguos hasta que quepa.

- `:summary`: resume los turnos antiguos.

- `{:custom, mod}`: `mod.compact(history, max_tokens)`.

**Reglas**:

- Nunca se parte un par `tool_call` + `tool_result`.

- Se conservan los mensajes `system` y los fijados.

- `:summary` se ejecuta **tras responder** (estado `:compacting`), salvo que no quepa, caso en que se usa `:truncate` como salvavidas síncrono.

- El modelo del resumen es `context.summary_model` (el más barato con skill suficiente).

**Contadores de tokens** (§7.6):

1.  Contador exacto del provider (si existe).

2.  `Gunther.Tokenizer` registrado para ese modelo.

3.  Modo `approximate` (solo si está calibrado con `Doctor.calibrate_tokenizer/2`).

Sin contador ni calibración, el modelo sale del conjunto con `filtered: :no_token_counter`.

## Alternativas consideradas

- **Contexto gestionado por el usuario**: descartada porque el usuario tendría que implementar la compactación y el conteo de tokens.

- **Compactación solo por truncado**: descartada porque pierde información importante.

- **Contadores aproximados sin calibración**: descartada porque subestima o sobreestima tokens (CE-21). Un margen fijo del 15 % no tiene fundamento.

- **Compactación síncrona siempre**: descartada porque bloquea la respuesta. `:summary` se hace tras responder.

## Consecuencias

- Sin contador ni calibración, un modelo no puede participar cuando se necesita contar tokens (D-58).

- Nunca se parte un par `tool_call` + `tool_result`.

- `:summary` se ejecuta tras responder; `:truncate` como salvavidas síncrono.

- El modo `approximate` requiere calibración por modelo.

## Verificación

- F8-04, F8-05.
- CE-21 (calibración de tokens).

- **Puertas F0 de las que depende**: G-12
