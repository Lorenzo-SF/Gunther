# ADR D-40 — Guardrails

- **Estado**: aceptada (DP0, r8)
- **Fecha**: 2026-10-25
- **Fuente**: SPEC r8 §5.10, §16.1, §16.2

## Contexto

Se necesita un punto de extensión para vetar o modificar contenido de entrada y salida. Los casos de uso:

- **Input**: vetar prompts con contenido prohibido (PII, secretos, contenido dañino) antes de enviarlos al modelo.

- **Output**: vetar respuestas del modelo antes de devolverlas al usuario (por compliance o por seguridad).

- **Modificación**: no vetar, sino reescribir el contenido (anonimizar, formatear, corregir).

Sin un contrato, cada aplicación implementa su propio sistema de guardrails, con distintos formatos, distintos timeouts, distintas políticas de error. El contrato unifica.

## Decisión

`Gunther.Guardrail.check(kind, content, ctx) :: :ok | {:veto, reason} | {:modify, new_content}`.

- **Input**: se aplica a los mensajes de autoría del caller **antes** de añadir contexto (§7.3). `{:veto, reason}` devuelve `:guardrail_input_veto`; `{:modify, new}` sustituye el contenido y añade el warning `:guardrail_modified`.

- **Output**: se aplica al contenido final antes de devolverlo. Con streaming y guardrails de output registrados, `guardrails.stream_mode` es **obligatorio** (sin defecto):
  - `buffered`: los chunks se retienen hasta completar la respuesta, se comprueba y se liberan o se vetan.
  - `post_hoc`: los chunks pasan; la comprobación es al terminar. Un veto no puede retirar lo ya entregado: devuelve `{:error, :guardrail_output_veto}`.

- **Límites de ejecución**: `guardrails.timeout_ms` (2000) por guardrail; fallo o vencimiento según `guardrails.on_error` (`"closed"` por defecto: se trata como veto; `"open"`: deja pasar con warning).

## Alternativas consideradas

- **Sin guardrails**: descartada porque el operador puede necesitar vetar contenido por compliance.

- **Guardrails solo de output**: descartada porque la inyección de input (T-01) requiere guardrails de input. Sin ellos, un prompt malicioso llega al modelo.

- **`stream_mode` con defecto (`buffered`)**: descartada porque cambia el comportamiento del streaming (latencia) y debe ser explícito. Un operador que active guardrails de output con streaming debe saber si paga latencia (`buffered`) o si acepta el riesgo (`post_hoc`).

- **Un solo `on_error` global**: descartada porque algunos guardrails pueden querer `closed` y otros `open`. La política es por config, no por guardrail, pero el dueño puede cambiarla en una fase posterior si aparece la demanda.

## Consecuencias

- Un veto `post_hoc` no puede retirar lo ya entregado: devuelve error.

- `on_error = "closed"` (defecto) trata el fallo como veto; `"open"` deja pasar con warning.

- Timeout por guardrail (2000 ms).

- El contrato del guardrail es un behaviour registrable (`:guardrail`).

## Verificación

- F10-01.
- CE-31 (semántica de guardrails de output con streaming).

- **Puertas F0 de las que depende**: ninguna
