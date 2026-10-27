# Matriz de puertas (resumen del Anexo C.2)

| Puerta      | Tema                                  | Fase que depende | Rama B                                      |
| ----------- | ------------------------------------- | ---------------- | ------------------------------------------- |
| G-01 a G-07 | Hermanas de Lorenzo-SF                | F1, F5           | Envoltorios propios                         |
| G-08        | `Spawner`                             | F1, F6, F13      | Línea base `Port`                           |
| G-09 a G-14 | llama.cpp, GPUs, GGUF                 | F2, F6           | Detectores de fabricante, `vram_mb`         |
| G-15        | MCP 2026-07-28                        | F7, F13          | `tools/list` como liveness                  |
| G-16, G-17  | Nombre y versiones                    | F0               | Otro nombre; fijar versión                  |
| G-18        | Plantilla del decisor                 | F4               | Plantilla propia                            |
| G-19, G-20  | mTLS y proxy                          | F15              | `verify_fun`; TLS del engine                |
| G-21 a G-23 | `Apero.Llm`, clientes HTTP, auditoría | F3, F16          | Cliente propio                              |
| G-24 a G-26 | SQLite, Postgres, FTS5                | F11, F12         | Vectores en proceso; BM25 en proceso        |
| G-27        | SDK de MCP                            | F7, F13          | Transporte propio                           |
| G-28        | Código de Arrea y `Arrea.Resource`    | F22, F2          | Implementación propia                       |
| G-29 a G-31 | Caché de prompt, continuidad, DSL     | F20, F21         | `affinity` off, `resend`, solo datos y TOML |

**Nota (r8, Q-14) sobre G-28.** `Arrea.Resource` existe y está publicado (D-13). G-28 ya no comprueba su existencia; comprueba si, con su API pública actual, permite implementar `foreign` y `available` de §11.3 sin duplicar medidas ni introducir acoplamiento. Si cumple, el ledger propio (`Gunther.Resource.Ledger`) puede pasar a fachada en una fase posterior. G-28 **no bloquea F1**.

**Puertas que bloquean F1.** G-01, G-05, G-07, G-16, G-17, G-21 y G-23 (`CIERRE-DP0.md` §3.4). Deben estar `PASA` o `BLOQUEADA con rama B aplicada` para abrir F1.

**Política de ejecución.** La política completa (`PASA` / `FALLA` / `BLOQUEADA con rama B provisional`; formato de registro; regla de no reabrir sin evidencia) está en `docs/04-f0-puertas.md` §«Política de ejecución» y en `CIERRE-DP0.md` §3.
