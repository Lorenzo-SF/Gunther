# Matriz de puertas (resumen del Anexo C.2)

| Puerta | Tema | Fase que depende | Rama B |
| --- | --- | --- | --- |
| G-01 a G-07 | Hermanas de Lorenzo-SF | F1, F5 | Envoltorios propios |
| G-08 | `Spawner` | F1, F6, F13 | Línea base `Port` |
| G-09 a G-14 | llama.cpp, GPUs, GGUF | F2, F6 | Detectores de fabricante, `vram_mb` |
| G-15 | MCP 2026-07-28 | F7, F13 | `tools/list` como liveness |
| G-16, G-17 | Nombre y versiones | F0 | Otro nombre; fijar versión |
| G-18 | Plantilla del decisor | F4 | Plantilla propia |
| G-19, G-20 | mTLS y proxy | F15 | `verify_fun`; TLS del engine |
| G-21 a G-23 | `Apero.Llm`, clientes HTTP, auditoría | F3, F16 | Cliente propio |
| G-24 a G-26 | SQLite, Postgres, FTS5 | F11, F12 | Vectores en proceso; BM25 en proceso |
| G-27 | SDK de MCP | F7, F13 | Transporte propio |
| G-28 | Código de Arrea y `Arrea.Resource` | F22, F2 | Implementación propia |
| G-29 a G-31 | Caché de prompt, continuidad, DSL | F20, F21 | `affinity` off, `resend`, solo datos y TOML |
