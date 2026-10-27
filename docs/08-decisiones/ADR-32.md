# ADR D-32 — Tool-calling de primera clase

- **Estado**: propuesta
- **Fecha**: 2026-10-25
- **Fuente**: SPEC §9.1, §9.4, §4.2

## Contexto
Las tools son parte del contrato de `chat/2`, no una extensión externa.

## Decisión
El modelo puede devolver `tool_calls`; con `run_tools: true` Gunther valida argumentos contra JSON Schema, comprueba permisos, invoca los `handler` en paralelo y devuelve los resultados como mensajes `role=tool`, hasta `max_tool_iterations` (5). Un error de handler se pasa al modelo como `{error: reason}`. Las tools definidas por el cliente se devuelven sin ejecutar.

## Alternativas consideradas
El SPEC r6 no recoge alternativas descartadas para esta decisión; no se inventan.

## Consecuencias
El presupuesto se acumula entre iteraciones. Los permisos y la confirmación (§9.3, CE-02) se añadieron en r6.

## Verificación
F7-01 a F7-03.

- **Puertas F0 de las que depende**: ninguna
