# ADR D-35 — MCP con transporte propio

- **Estado**: aceptada (decisión P-10 del dueño; premisa pendiente de confirmar)
- **Fecha**: 2026-10-25
- **Fuente**: SPEC §9.2, §9.3, §9.5; respuesta del dueño P-10

- Resuelta en r7 (D-92): **la premisa del motivo no coincide con lo verificado el 2026-10-25.** Existe `snodo` (versión 0.2.0 en Hex), que declara protocolos `V2026_07_28`, `V2025_11_25` y `V2025_06_18` y ofrece cliente, servidor, transportes stdio y HTTP y adaptador para Plug y Bandit \[V\]. También existe `hermes_mcp` (versión 0.14.1), cuyo README no declara la revisión 2026-07-28 \[V\]. Que `snodo` sea «maduro» no está evaluado: una versión 0.2.0 no lo demuestra ni lo descarta. La decisión de transporte propio se mantiene tal como el dueño la tomó; el dueño debe confirmar si el motivo cambia (por ejemplo, a «un SDK existente no ha sido evaluado todavía»), y G-27 la contrasta con criterios objetivos (mantenimiento, licencia, cobertura de la revisión, control de SSRF y de TLS, cancelación, tamaño de dependencias).

## Contexto
Las tools de MCP entran en la misma tabla que las locales (§9.1). Gunther implementa servidor y cliente MCP sobre transportes propios: stdio mediante `Gunther.Command.spawn/3` y Streamable HTTP mediante `Finch` y `Plug`. D-54 fija la revisión 2026-07-28 con modo compatible 2025-11-25.

## Decisión
Transporte propio. **Motivo declarado por el dueño**: no hay un SDK de MCP en Elixir maduro para la revisión 2026-07-28. No se descarta usar un SDK existente.

## Alternativas consideradas
Usar un SDK existente de Elixir. No descartada en principio; queda sujeta a la puerta G-27.

## Consecuencias
Gunther mantiene el código de los transportes y de la constante de versión (`Gunther.MCP.Versions`).

## Verificación
G-15 (comportamiento de 2026-07-28), G-27 (evaluación de SDK existentes), F7-04, F7-05, F13.

- **Puertas F0 de las que depende**: G-15, G-27 (nueva)

## Cambios necesarios en el SPEC (r7)

| # | Sección | Cambio | Estado |
| --- | --- | --- | --- |
| I-26 | Anexo C | Añadir la puerta G-27 (evaluación de SDK de MCP existentes con los criterios de G-22) | aplicada en r7 |
