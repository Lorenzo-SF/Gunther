# ADR D-42 — Cancelación propagada

- **Estado**: aceptada (DP0, r8)
- **Fecha**: 2026-10-25
- **Fuente**: SPEC r8 §2.9, §4.5

## Contexto

Una petición cancelada debe detener a todos los procesos que trabajan para ella. Sin cancelación:

- Un stream abandonado deja procesos vivos (productor, tasks de clasificador, tasks de embedding, tasks de tools). N-14 lo prohíbe.

- Un gateway que cierra la conexión no detiene la petición interna.

- Un agente cancelado sigue gastando presupuesto.

## Decisión

**Token de cancelación** (`Gunther.Cancel`): `Gunther.Cancel.new() :: %Gunther.Cancel{ref: :atomics.atomics_ref()}` (creada con `:atomics.new(1, signed: false)`). `Gunther.cancel(token)` hace `:atomics.put(ref, 1, 1)`; `cancelled?(token)` lee `:atomics.get(ref, 1) == 1`. Es O(1) y válido entre procesos.

El provider recibe `opts.cancelled?` (función de aridad 0) y **debe** consultarla entre chunks y abortar.

Todo `Task` hijo de una petición se arranca bajo `TaskSupervisor` y se enlaza al token.

**`stream!/2`** se implementa con `Stream.resource/3`: el productor es una tarea bajo `TaskSupervisor`; el consumidor demanda por lotes. Si el consumidor abandona la enumeración (`after_fun`), se activa el token de cancelación, se espera hasta `stream.cancel_grace_ms` (1000) y se mata la tarea.

**Invariante testeable**: tras abandonar un `stream!`, ningún proceso de la petición sigue vivo pasado `cancel_grace_ms`.

## Alternativas consideradas

- **Cancelación por mensaje `:cancel` a los procesos**: descartada porque requiere que cada proceso implemente el manejo y puede perder mensajes (si el proceso está en un `receive` con `after`, o si el mensaje llega antes de que el proceso esté listo).

- **Cancelación por cierre del stream**: descartada porque no detiene las tareas internas (clasificador, embedding, tools). El stream se cierra pero las tasks siguen.

- **Sin cancelación**: descartada porque un stream abandonado deja procesos vivos (N-14).

- **Cancelación por `Process.exit/2`**: descartada porque mata el proceso sin permitir limpieza (`terminate/2` no se llama si no hay `trap_exit`).

## Consecuencias

- Invariante N-14: ningún proceso vivo tras `stream.cancel_grace_ms`.

- El token es O(1) y válido entre procesos.

- Los providers reciben `opts.cancelled?` (función de aridad 0).

- El `ContractTest` verifica que un provider lento aborta al cancelar.

## Verificación

- F1-08, F3-08.
- CE-14 (mecanismo de cancelación).

- **Puertas F0 de las que depende**: ninguna
