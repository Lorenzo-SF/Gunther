# ADR D-62 — `chat/2` y `tell/2` en lugar de `send/2`

- **Estado**: propuesta
- **Fecha**: 2026-10-25
- **SPEC**: SPEC-000-GUNTHER r6

## Contexto
Una función `send/2` en un módulo choca con `Kernel.send/2`.

## Decisión
`Provider.chat/2` y `Hive.tell/2` (con `{:error, :not_found}` si la voz no existe).

## Alternativas consideradas
Mantener `send/2` con `import Kernel, except:` (descartado: tropiezo para todo implementador).

## Consecuencias
Cambio de nombre en API pública antes de 1.0.

## Verificación
Contrato de `Provider`.

- **Puertas F0 de las que depende**: ninguna: es una decisión de contrato
