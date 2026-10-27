# Trazabilidad: requisito → SPEC → fase → comprobación

## Peticiones del dueño

| Requisito | SPEC | Decisión | Fases | Comprobación |
| --- | --- | --- | --- | --- |
| Nada de afirmaciones, suposiciones ni estimaciones | §0.6, Anexo C | D-64 | F0 | `scripts/doc_lint.sh`; N-09; puertas con ramas |
| Mejor rendimiento, robustez, escalabilidad y seguridad | §2.5, §2.6, §15, §17 | D-51, D-60 | F5, F16 | N-01 a N-14; lista de seguridad |
| GPUs: CUDA, Vulkan, ROCm, Metal | §11.7 | D-69 | F2 | Fixtures por backend; G-10, G-11 |
| Identidad correcta de GPUs (sin doble conteo) | §11.8 | D-65 | F2 | Casos de mapeo; `free > total` |
| Gestionar un provider/modelo local de forma remota (mixto) | §18 | D-66, D-67 | F15 | Pruebas de §18.9; N-07 |
| Gestionar arranque y apagado con N modelos y uso limitado a la vez | §11.1, §11.3, §11.4, §6.9 | D-61, D-71 | F2, F6 | Ledger, `max_loaded_models`, refusal |
| Decisor del router y de la colmena basado en modelos especializados | §6.11, §6.12, §10.2 | D-68 | F4, F17 | Verificación por idioma y adversaria |
| Decisor customizable y agnóstico | §6.11 | D-72 | F4 | Contrato de `Classifier`; ningún nombre de modelo en el código |
| Decisor multilingüe y de varios tipos de decisión | §6.11, §16.4 | D-72 | F4, F10 | `required_languages` |
| Cambiar el nombre a Gunther | §0.2 | D-63 | F0 | G-16; grep del nombre antiguo |
| Windows fuera | §0.3 | D-71 | — | — |
| Gunther no descarga modelos | §3.4, §18.4 | D-71 | — | Revisión: ninguna descarga en el código |
| Licencia abierta con atribución; contribución por issues | §0.5 | D-73 | F16 | `LICENSE`, `NOTICE`, `CONTRIBUTING.md` |
| Umbrales de rendimiento aprobados | §17 | — | F4, F15 | N-01 (5 ms), N-07 (25 ms) |

## Evaluación de r5 → cierres

La tabla completa de los 20 huecos y su cierre está en el SPEC, Anexo B.1; los 24 hallazgos adicionales, en B.2.

## Cómo mantener esta tabla
Cada decisión nueva añade una fila. Una fase no se cierra si un requisito que toca no tiene comprobación ejecutada.

## Adenda de la coral

| Requisito | SPEC | Decisión | Fases | Comprobación |
| --- | --- | --- | --- | --- |
| Colmena y teamwork como base común con modalidades propias | §22.1, §22.9 | D-74 | F18, F20 | Una modalidad de terceros pasa el contrato |
| DSL que cree modalidades nuevas | §22.10 | D-75 | F20 | Equivalencia datos, TOML y DSL; G-31 |
| Roles con tareas y modelo por tarea | §22.4 | D-74 | F19 | Política de modelo por tarea |
| Workflow configurable | §22.5 | D-75, D-76 | F19 | Tipos de paso; límites |
| Comunicación entre agentes y memoria compartida | §22.6, §22.7 | D-77, D-78 | F18 | Pizarra con CAS; buzones acotados |
| Aprovechar Arrea y sugerir cambios sin cambiar su dominio | §22.15 | D-78, D-86 | F22 | G-28 |
| Retomar al cambiar de modelo sin gastar todos los tokens | §22.12 | D-81, D-82 | F21 | G-29, G-30 |
| Usables por separado e integradas | §22.1, §22.3 | D-80, D-85 | F1 a F18 | Pruebas de cada pieza sola; contexto único |

## Requisitos y puertas F0 (corrige C-18)

| Requisito | Puertas |
| --- | --- |
| GPUs: CUDA, Vulkan, ROCm, Metal | G-09, G-10, G-11, G-14 |
| Nodos remotos | G-19, G-20 |
| Decisor multilingüe y agnóstico | G-12, G-18 |
| Ledger y gestión de arranque y apagado | G-13, G-28 |
| RAG con SQLite por defecto | G-24, G-25, G-26 |
| MCP con transporte propio | G-15, G-27 |
| Coral | G-28, G-29, G-30, G-31 |
