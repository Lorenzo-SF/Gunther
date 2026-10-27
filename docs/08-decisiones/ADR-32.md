# ADR D-32 — Tool-calling de primera clase

- **Estado**: aceptada (DP0, r8)
- **Fecha**: 2026-10-25
- **Fuente**: SPEC r8 §9.1, §9.4, §4.2

## Contexto

En muchas librerías de LLM, las tools son una **extensión externa**: el usuario define las tools en el prompt, el modelo devuelve `tool_calls` en la respuesta, el usuario parsea la respuesta, ejecuta la función, mete el resultado en el siguiente prompt, y repite. Este patrón tiene cuatro problemas:

1.  **El usuario reimplementa el bucle cada vez.** Validación de argumentos, ejecución, manejo de errores, siguiente iteración, límite de iteraciones. Es código repetido.
2.  **No hay permisos unificados.** ¿Qué tools puede ejecutar el modelo? ¿Con qué confirmación? Cada aplicación lo resuelve a su manera.
3.  **No hay truncado de resultados.** Un resultado grande satura el contexto del modelo y el prompt siguiente. Cada aplicación lo resuelve a su manera.
4.  **No hay presupuesto acumulado.** Un bucle de tools puede gastar sin control. Cada aplicación lo resuelve a su manera.

Gunther decidió que **las tools son parte del contrato de `chat/2`**: el bucle de tool_calls, los permisos, el truncado y el presupuesto los gestiona Gunther, no el usuario.

## Decisión

El modelo puede devolver `tool_calls` en la respuesta. Con `run_tools: true` (defecto), Gunther:

1.  Valida `arguments` contra el JSON Schema registrado.
2.  Comprueba permisos (`:auto`, `:confirm`, `:deny`) según `[tools.permissions]`.
3.  Invoca los `handler` de varias tools **en paralelo** (`Task.async_stream`, `tools.max_parallel`).
4.  Trunca cada resultado a `tools.max_result_bytes` (produce JSON válido, ver CE-11).
5.  Devuelve los resultados como mensajes `role=tool` con `tool_call_id`, en el orden de los ids.
6.  Vuelve al modelo, hasta `max_tool_iterations` (5).

Los errores de handler se pasan al modelo como `{error: reason}` (no se lanzan). El presupuesto se acumula entre iteraciones.

**Tools definidas por el cliente** (semántica OpenAI, gateway): Gunther **no las ejecuta**; devuelve los `tool_calls` al cliente. Si el nombre choca con una del registro, gana la del cliente y se avisa en la traza.

## Alternativas consideradas

- **Tools como extensión externa** (parsear y ejecutar fuera de Gunther): descartada por los cuatro problemas de contexto. El usuario tendría que reimplementar el bucle, los permisos, el truncado y el presupuesto.
- **Tools como un módulo separado** (no en `chat/2`): descartada porque entonces `chat/2` no podría manejar el bucle de `tool_calls` de forma atómica. Habría que llamar a `chat/2` y a `Tools.run/3` en un bucle externo.
- **`run_tools: false` por defecto**: descartada porque el caso de uso principal (un agente que usa tools) requiere el bucle. El usuario que quiera control manual pone `run_tools: false`.

## Consecuencias

- El contrato de `chat/2` incluye `:tools`, `:tool_choice`, `:run_tools`, `:max_tool_iterations` y `:approve_tools`.
- El registro de tools es **único** para locales y MCP (`Gunther.Tools`).
- Los permisos se configuran en `[tools]` y en `[[tools.permissions]]`.
- El truncado de resultados es determinista y produce JSON válido.
- El gateway devuelve al cliente las tools que él definió, y ejecuta las del registro.
- La confirmación en `chat/2` devuelve `:tool_confirmation_required` (CE-02); en un agente, emite `[:gunther, :tool, :confirm_required]` y espera `{:wait_human, ...}`.

## Verificación

- F7-01 a F7-03.
- CE-02 (protocolo de confirmación).
- CE-11 (truncado de JSON).

- **Puertas F0 de las que depende**: ninguna
