# Cambios

Formato: [Keep a Changelog](https://keepachangelog.com/es-ES/1.1.0/). Versionado: SemVer (SPEC §4.14).

## [Sin publicar]

### SPEC-000-GUNTHER r8 — 2026-10-26

Cierre de DP0 y apertura de F0. Cambios acotados respecto a r7 (M-01 a M-11 y CE-34).

**Añadido**

- `[[consumers.<id>.rules]]`: reglas por consumer con la misma forma que `[[rules]]` (M-01, Q-15).
- Nueva §6.8.1 en el SPEC: precedencia completa de reglas (consumer → global → `default_model`).
- Nueva §1.7 en el SPEC: estado de las decisiones por bloque.
- Nueva §22.1 con `Gunther.Coral` como nombre definitivo (M-03, Q-13).
- `CE-34`: cierre de especificación de D-09 y D-87 (sintaxis y precedencia de reglas de consumer).
- Anexo D del SPEC: cambios de r7 a r8.
- `CIERRE-DP0.md` en la raíz: registro histórico del cierre de DP0.

**Cambiado**

- D-48 a D-92: estado `propuesta` → `aceptada` (DP0 cerrado).
- D-30, D-46, D-56: sustituidas por D-74 en lo relativo a «colmena / mesa camilla / voz» (M-03).
- D-48 y D-91: nota de Q-14 (ledger propio en v1; `Arrea.Resource` existe y está publicado).
- §1.3: tabla de conceptos renombrada (coral, miembro, plan, pizarra).
- §1.4 y §1.5: notas a D-30, D-46, D-48, D-56, D-91.
- §3.2: fila `Arrea.Resource` actualizada con Q-14.
- §4.9: API de la coral (`Gunther.Coral.run/2`, `await/2`, `status/1`, `events/1`, `resume/2`, `cancel/1`, `register_mode/3`, `list_modes/0`).
- §5: introducción con los cuatro behaviours nuevos de la coral (`:coral_mode`, `:consensus`, `:step`, `:run_store`).
- §6.5: hash del catálogo incluye reglas de consumer.
- §6.10: tres filas nuevas (consumer con `default_model` vetado; consumer no declarado; nombre de regla duplicado).
- §15.2 T-15: las reglas de consumer no pueden vetar candidatos de otro consumer.
- §17 N-15: valor fijado a 50 ms p99 (M-02, Q-09).
- §19 F4: AC ampliados con precedencia de reglas de consumer.
- §21: Q-01 a Q-16 cerradas con las respuestas del dueño.
- §22.1: estado «aprobada»; coral como modalidad de la infraestructura integrada.
- §22.19: sin pendientes del dueño.

**Documentación**

- `README.md`: estado actualizado a «en diseño — DP0 cerrado, F0 en ejecución».
- `docs/00-indice.md`: referencia a r8; añadido `CIERRE-DP0.md`; nota sobre el gap intencional de `docs/14-*.md`.
- `docs/01-plan-de-desarrollo.md`: DP0 marcado como completado el 2026-10-26; DP1 pasa a siguiente.
- `docs/02-proceso-de-desarrollo.md`: §5 aclara que DP0 se cerró con `CIERRE-DP0.md`, no con ADRs individuales.
- `docs/03-estrategia-de-pruebas.md`: nuevo caso obligatorio para reglas de consumer con veto del `default_model`.
- `docs/04-f0-puertas.md`: nueva sección de política de ejecución (`PASA` / `FALLA` / `BLOQUEADA con rama B provisional`).
- `docs/05-estructura-del-repositorio.md`: `CIERRE-DP0.md` añadido al árbol.
- `docs/06-guia-de-operacion.md`: nueva §10 «Reglas por consumer».
- `docs/07-seguridad-checklist.md`: punto 13 ampliado con el aislamiento de reglas entre consumers.
- `docs/08-decisiones/README.md`: D-48 a D-92 a `aceptada`; notas de renombrado.
- `docs/09-trazabilidad.md`: nuevas filas (reglas por consumer; N-15 = 50 ms p99).
- `docs/12-roadmap.md`: coral marcada «aprobada, v1.1+, con G1–G9 en v1».
- `docs/13-registro-de-fases.md`: fila DP0 completa.
- `docs/15-matriz-de-puertas.md`: nota sobre G-28 y Q-14.
- ADRs D-02, D-30, D-46, D-48, D-56, D-87, D-91: notas de ratificación y renombrado.
- `examples/gunther.example.toml`: sección de ejemplo `[[consumers.<id>.rules]]`.

### SPEC-000-GUNTHER r7 — 2026-10-26

**Añadido**

- §22 completa: la coral (colmena y equipo como modalidades), DSL, pizarra, mensajería, consenso, contexto portable, evoluciones propuestas para Arrea.
- §18 completa: nodos remotos.
- §12 a §17: gateway, telemetría, configuración, modelo de amenazas, guardrails y evaluación, requisitos no funcionales.
- §19, §20, §21: fases con AC, riesgos y deuda, preguntas abiertas.
- Anexos A, B, C: cambios, cierres y hallazgos, verificaciones y puertas.
- ADRs D-74 a D-86 (adenda de la coral) y D-87 a D-92 (resoluciones por delegación del dueño).

**Cambiado**

- §8: RAG completo con siete piezas, `rag_query` como tool, `store_backend`, SQLite por defecto, `calibrate_rag/2`.
- §11: convenciones A y B de medida, estados de la reserva, reintento en otro device, capas enteras, presupuesto jerárquico.
- §12.2: límite del gateway con adjuntos.
- §12.3: subconjunto de la API de chat.
- §14.1: `[consumers.*]`, `[[rules]]`, `[[decision_models]]`, `[rag]`, `[coral]`, `[context]`.
- §15.2: T-25 añadido.
- §18.3.1: cuerpos de la API de nodo.

### SPEC-000-GUNTHER r6 — 2026-10-25

**Añadido**

- §0.6: regla de no-suposición y lint de documento.
- §3.4: contrato `Spawner`, lista de permitidos con `realpath` e inodo, `ArgsBuilder` sin líneas libres.
- §4.2.1: salida estructurada con fallback.
- §6.11 y §6.12: modelos de decisión especializados y seguridad del router.
- §9: MCP en la revisión 2026-07-28 con modo compatible 2025-11-25; SSRF; permisos y confirmación.
- §11.7 y §11.8: backends GPU y matriz de capacidades; identidad física, memoria unificada, coherencia.
- §18: nodos remotos.
- §22: la coral.
- ADRs D-63 a D-73.

**Cambiado**

- Renombrado completo Candil → Gunther (D-63).
- Fórmula de KV corregida por tipo de atención (CE-24).
- `foreign` redefinido (CE-23).
- Coste de entrada incluido en el presupuesto (CE-25).
- Modo compatible de MCP con sesiones y tope (CE-H15).
- Sección de seguridad: clave desconocida es error (CE-H11).

### SPEC-000-GUNTHER r5 — histórico

Primera versión completa del SPEC. No se mantiene en este CHANGELOG; el detalle está en `SPEC-000-GUNTHER_r7.md`, Anexo A.

### r4 y anteriores — histórico

Renombrado desde Candil. Ver `docs/08-decisiones/` para el histórico de decisiones.
