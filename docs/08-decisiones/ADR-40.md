# ADR D-40 — Guardrails

- **Estado**: propuesta
- **Fecha**: 2026-10-25
- **Fuente**: SPEC §5.10, §16.1, §16.2

## Contexto
Se necesita un punto de extensión para vetar o modificar contenido de entrada y salida.

## Decisión
`Gunther.Guardrail.check(kind, content, ctx) :: :ok | {:veto, _} | {:modify, _}`. Input antes de añadir contexto; output antes de devolver. Con streaming y guardrails de output, `guardrails.stream_mode` es obligatorio (`buffered` o `post_hoc`). Límites de ejecución y política `on_error`.

## Alternativas consideradas
El SPEC r6 no recoge alternativas descartadas para esta decisión; no se inventan.

## Consecuencias
Un veto `post_hoc` no puede retirar lo ya entregado.

## Verificación
F10-01.

- **Puertas F0 de las que depende**: ninguna
