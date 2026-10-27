# ADR D-92 — Resoluciones del RAG y de los adjuntos

- **Estado**: propuesta (resuelta por delegación del dueño en r7)
- **Fecha**: 2026-10-26
- **Fuente**: SPEC §8, §12.2; resuelve I-12, I-14, I-15 e I-20 (y corrige el motivo de D-35)

## Contexto
Cuatro puntos del ADR de D-36 y de D-34 quedaron sin respuesta del dueño, y el motivo de D-35 no coincidía con lo verificado.

## Decisión
(1) El store SQLite pasa a F11 (es el defecto de uso real). (2) La puerta 3 del RAG inyecta el contexto en el paso 2 del flujo, antes de decidir. (3) `router.embedding.min_similarity` tiene defecto `0.0`; la capa no actúa hasta estar verificada, y `calibrate_router` elige el valor. (4) `gateway.max_attachment_body_bytes` = `ceil(max_attachment_bytes máximo × 4 / 3) + gateway.max_body_bytes` (base64 ocupa 4/3 del original). (5) D-35 mantiene el transporte propio y su motivo pasa a «sin evaluar un SDK existente» hasta G-27.

## Alternativas consideradas
Dejarlo abierto (descartado: bloquea la especificación).

## Consecuencias
Todos reversibles.

## Verificación
G-24, G-26, G-27.

- **Puertas F0 de las que depende**: G-24, G-26, G-27
