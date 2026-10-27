# ADR D-34 — Multimodal passthrough y límite de adjuntos

- **Estado**: aceptada (propuesta P-9 del dueño)
- **Fecha**: 2026-10-25
- **Fuente**: SPEC §4.2, §5.1, §6.10; respuesta del dueño P-9

## Contexto
Los mensajes admiten partes `:text`, `:image` y `:audio`; cada modelo declara `modalities`; sin candidato con la modalidad pedida, `:no_candidates` con `filtered: :no_vision`. El SPEC r6 no definía qué hace Gunther con el contenido.

## Decisión
**Gunther no procesa imágenes ni audio**: no los redimensiona, no los convierte y no valida su formato. Los envía tal cual al provider. Se añade `model.max_attachment_bytes`, con defecto de **20 MiB para imágenes y 50 MiB para audio**; un adjunto que lo supere es `{:error, :invalid_request}` con `details.attachment_too_large`. El límite se mide sobre los bytes de `data`; un adjunto dado por `url` no se descarga ni se mide (lo resuelve el provider).

## Alternativas consideradas
El SPEC r6 no recoge alternativas descartadas. Queda excluido por la decisión: cualquier transformación del contenido por parte de Gunther.

## Consecuencias
El formato y las dimensiones aceptables los decide cada provider. Un adjunto grande puede chocar con el límite de cuerpo del gateway (ver r7, I-20).

## Verificación
Contrato de `Provider.modalities/1`; prueba de límite por tipo en F3.

- **Puertas F0 de las que depende**: ninguna

## Cambios necesarios en el SPEC (r7)

| # | Sección r6 | Cambio | Estado |
| --- | --- | --- | --- |
| I-19 | §4.2, §4.13, §14.1 `[[models]]` | Añadir `max_attachment_bytes` (la forma de la clave con dos defectos por tipo, imagen y audio, la fija el SPEC), el detalle `attachment_too_large` y la regla de medida sobre `data` | aplicada en r7 |
| I-20 | §12.2 `gateway.max_body_bytes` (1 MiB) | Un adjunto de 20 o 50 MiB no cabe en un cuerpo de 1 MiB; además, un adjunto en base64 ocupa más bytes que el original. Hay que reconciliar ambos límites (por ejemplo, un límite de cuerpo distinto para las rutas con adjuntos) | resuelta por D-92 |
