# Índice de la documentación de Gunther

| Documento                          | Para qué                                                             |
| ---------------------------------- | -------------------------------------------------------------------- |
| `../SPEC-000-GUNTHER_r9.md`        | Especificación completa vigente: qué se construye                    |
| `../SPEC-000-GUNTHER_r7.md`        | Revisión anterior; se conserva como histórico                        |
| `../CIERRE-DP0.md`                 | Registro de las decisiones del dueño que cierran DP0 y abren F0      |
| `01-plan-de-desarrollo.md`         | Fases de diseño y desarrollo, paquetes de trabajo y dependencias     |
| `02-proceso-de-desarrollo.md`      | Cómo se trabaja: ramas, CI, versionado, revisión, cierre de fase     |
| `03-estrategia-de-pruebas.md`      | Qué se prueba y cómo, incluido el hardware                           |
| `04-f0-puertas.md`                 | Procedimiento de las puertas de verificación y política de ejecución |
| `05-estructura-del-repositorio.md` | Dónde va cada cosa y qué fronteras se comprueban                     |
| `06-guia-de-operacion.md`          | Cómo configurar y operar Gunther                                     |
| `07-seguridad-checklist.md`        | Lista de seguridad antes de cada versión                             |
| `08-decisiones/`                   | ADRs de D-01 a D-92; D-48 a D-92 aceptadas en DP0                    |
| `09-trazabilidad.md`               | Requisito → SPEC → fase → comprobación                               |
| `10-recomendaciones.md`            | Recomendaciones no vinculantes de decisores                          |
| `11-glosario.md`                   | Términos                                                             |
| `12-roadmap.md`                    | Posterior a 1.0                                                      |
| `13-registro-de-fases.md`          | Registro vivo de fases y puertas                                     |
| `14-planificacion-del-coder.md` | Plan de traspaso al modelo *coder*: estado, método, cola, trampas y criterios de revisión |
| `16-nemotron-coder.md` | Cómo se sirve el Nemotron 3.5 Lightning para que sea el *coder*: modo de razonamiento y configuración corregida |
| `17-prompt-del-coder.md` | El prompt que se le pasa al modelo: rol, mapa de la documentación, método, trampas y límites |
| `15-matriz-de-puertas.md`          | Resumen de las puertas F0 y sus ramas                                |

**Nota sobre `docs/14`.** El hueco estaba reservado para documentos que no encajen en las categorías anteriores; lo ocupa la planificación del relevo al modelo *coder*, que es exactamente eso.

## Orden de lectura sugerido

1. `../README.md`.
2. `../CIERRE-DP0.md`.
3. `../SPEC-000-GUNTHER_r9.md` §1 y §21.
4. `01-plan-de-desarrollo.md`.
5. `08-decisiones/README.md`.
6. `04-f0-puertas.md`.
7. `../AGENTS.md` — el contrato de trabajo de quien toque el repositorio.
8. `14-planificacion-del-coder.md` — el plan del relevo, si vienes a continuar.
9. `17-prompt-del-coder.md` — el prompt, si lo que quieres es poner al día a un modelo.
