# ADR D-37 — Sesiones como contrato

- **Estado**: aceptada (DP0, r8)
- **Fecha**: 2026-10-25
- **Fuente**: SPEC r8 §5.13, §7.1, §4.6

## Contexto

Una sesión es un hilo conversacional. Se decidió que fuera un **contrato** (behaviour `Gunther.SessionStore`) con referencias `Memory` (ETS) y `Disk` (`Apero.File`, escritura atómica), porque:

1.  **Diferentes aplicaciones necesitan diferentes backends.** Tests → `Memory`. Producción → `Disk`. Despliegues distribuidos → un store externo (futuro). Si las sesiones están cableadas a ETS, no se puede cambiar el backend.
2.  **El contrato debe incluir los estados y los límites.** Una sesión pasa por `:open → :compacting → :open`, o `:closed`. Los límites son `sessions.max_sessions`, `sessions.idle_ttl_seconds`, `sessions.max_turns_in_memory`. Si el contrato no los define, cada implementación los inventa.
3.  **El `open/2` debe reabrir desde el store automáticamente.** Un usuario no quiere saber si la sesión estaba en memoria o en disco: `Session.open(name)` debe reabrirla. Un `load/1` separado duplica la API y obliga al usuario a saber cuándo llamar a cada uno.

## Decisión

`Gunther.SessionStore` es un behaviour con cuatro callbacks: `load(name)`, `save(name, session)`, `delete(name)`, `list()`. Referencias:

- `Memory` (ETS, defecto): rápido, local, no persiste.
- `Disk` (`Apero.File`, escritura atómica): persiste, puede firmarse con HMAC, puede cifrarse.

**`Session.open/2`** reabre desde el store automáticamente:

1.  Si la sesión está cargada, la devuelve.
2.  Si el store tiene una guardada con ese nombre, la carga y la devuelve.
3.  Si no existe, la crea (salvo `create: false`, que devuelve `{:error, :session_not_found}`).

**Las sesiones tienen espacio de nombres por consumer** (`{consumer, name}`, CE-30): dos consumers pueden usar el mismo nombre sin verse.

**Una sesión `:closed` no se reabre** (`:session_closed`).

## Alternativas consideradas

- **Sesiones en ETS sin contrato**: descartada porque no permite persistencia.
- **Sesiones como parte del `AgentStore`**: descartada porque una sesión no es un agente. Un agente tiene un bucle y un estado; una sesión tiene un historial de turnos.
- **`load/1` separado de `open/2`**: descartada porque duplica la API y obliga al usuario a saber cuándo llamar a cada uno.
- **Un `GenServer` por sesión**: descartada porque no escala con `max_sessions` (1024) y complica el lifecycle. Las sesiones viven en ETS detrás de un `GenServer` propietario.

## Consecuencias

- El contrato sirve también para el `AgentStore` con el snapshot de CE-07.
- `open/2` carga o crea la sesión; `create: false` devuelve `:session_not_found` si no existe.
- Una sesión descargada por `idle_ttl_seconds` sin `SessionStore` en disco **se pierde**; con `Disk` se reabre con su historial.
- `Session.last_call/1` (G4) devuelve `%{model, provider, input, cached_input} | nil` de la última llamada, para el cambio de modelo y la afinidad.

## Verificación

- F8-01, F8-02.
- CE-08 (`open/2` que reabre).
- CE-30 (aislamiento por consumer).

- **Puertas F0 de las que depende**: ninguna
