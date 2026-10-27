# ADR D-50 — Ejecución de comandos en dos modos

- **Estado**: aceptada (DP0, r8)
- **Fecha**: 2026-10-25
- **SPEC**: SPEC-000-GUNTHER r6

## Contexto
`Trebejo.SafeCommand` ejecuta con shell, devuelve al terminar y usa lista negra: no sirve como transporte duplex ni como frontera de seguridad.

## Decisión
`Gunther.Command` con modo corto (`SafeCommand`) y modo largo (proceso sin shell con ejecutable de una lista de permitidos fijada por `realpath`, inodo y `sha256`).

## Alternativas consideradas
`SafeCommand` para todo (descartado: no sirve para procesos largos). `System.cmd` libre (descartado: sin validación).

## Consecuencias
Una sola puerta de ejecución; regla de código comprobada por grep.

## Verificación
G-06, G-06b; pruebas de F1-05 y F1-06.

- **Puertas F0 de las que depende**: G-06, G-06b
