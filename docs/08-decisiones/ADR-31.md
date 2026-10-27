# ADR D-31 — Framework sin CLI

- **Estado**: propuesta
- **Fecha**: 2026-10-25
- **Fuente**: SPEC §1.1, §4.12

## Contexto
Toda capacidad operativa se ofrece como función de Elixir.

## Decisión
Gunther es un framework y no tiene CLI. `Gunther.Doctor` es una función, no un comando (§4.12). `Gunther.Gateway` y `Gunther.MCP.Server` no están en el árbol: los arranca la aplicación del usuario (§2.3).

## Alternativas consideradas
El SPEC r6 no recoge alternativas descartadas para esta decisión; no se inventan.

## Consecuencias
Quien quiera una línea de comandos la construye sobre la API. El diagnóstico se invoca desde la aplicación anfitriona.

## Verificación
F1-10 (Doctor).

- **Puertas F0 de las que depende**: ninguna
