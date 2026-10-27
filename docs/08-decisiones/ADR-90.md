# ADR D-90 — Memoria con autor y versión; evento de calidad

- **Estado**: aceptada (DP0, r8)
- **Fecha**: 2026-10-26
- **Fuente**: SPEC §7.2, §13.1; resuelve J-06 y J-11 (D-12, D-22)

## Contexto
D-22 definía `meta.author` y «sustituido por»; D-12 apoyaba la salud del destino en `finish_reason` anómalo y reintentos. r6 no tenía ni lo uno ni lo otro.

## Decisión
`Memory` guarda por entrada `meta: %{author, version, superseded_by}` y acepta `if_version:` (gancho G8). Evento `[:gunther, :provider, :quality]` con `finish_reason` y reintentos; no se usa para enrutar.

## Alternativas consideradas
Memoria sin metadatos (descartado: impide la pizarra y el «sustituido por» de D-22).

## Consecuencias
Mantiene el espacio de nombres por consumer de r6.

## Verificación
F8 (memoria), F3 (evento).

- **Puertas F0 de las que depende**: ninguna
