# ADR D-39 — Evaluación como contrato

- **Estado**: aceptada (DP0, r8)
- **Fecha**: 2026-10-25
- **Fuente**: SPEC r8 §4.11, §16.3, §6.11

## Contexto

Se decidió que la evaluación forma parte del producto, no de un proyecto aparte. Las razones:

1.  **El decisor (D-68, D-72) se activa solo si supera una evaluación.** Si la evaluación es externa, no hay forma de verificar el decisor dentro del producto.
2.  **Los informes deben ser reproducibles y auditables.** Un script ad-hoc no lo es. Un contrato con métricas definidas sí.
3.  **El corpus lo construye el operador, pero con herramientas de Gunther.** `router.capture`, `Gunther.Eval.Corpus.label/2`, `synthesize/4`, `adversarial/2`. Si la evaluación es externa, el operador no tiene herramientas.
4.  **Los umbrales no pueden ser fijos.** D-72 exige comparación con línea base e intervalo de confianza. Un contrato lo hace medible; un script ad-hoc no.

## Decisión

`Gunther.Eval.run(spec, opts)` ejecuta un corpus JSONL y devuelve un informe reproducible con:

- `top1_accuracy` (global y por `lang`).
- `top3_accuracy` (global y por `lang`).
- `abstain_rate`.
- `adversarial_drop` (diferencia de exactitud entre el corpus limpio y el adversario).
- Percentiles de latencia por **rango más próximo**.
- `recall@k`, `MRR`, `nDCG@k` para RAG.

**Reproducibilidad**: `temperature = 0`, `seed` fijo, hash del fichero del modelo y de la configuración en el informe. El informe se escribe de forma atómica en `<state_dir>/eval/<report_id>.json`.

**Verificación del decisor**: relativa a una línea base (la mayor exactitud entre `fallback` y reglas más `fallback`, medidas sobre los mismos casos) con el límite inferior del intervalo de Wilson al 95 %. Se exige para cada idioma de `eval.required_languages` y sobre el corpus adversario.

**Cualquier cambio** en el fichero del modelo, el `DecisionSpec` o las rutas invalida el informe y devuelve el estado a `:unverified`.

Es el mecanismo de verificación de los modelos de decisión (D-68, D-72).

## Alternativas consideradas

- **Evaluación como proyecto externo**: descartada porque entonces el decisor no se puede verificar dentro del producto, y D-68 exige que se active solo con informe válido.
- **Evaluación ad-hoc (scripts sin contrato)**: descartada porque no es reproducible ni auditable.
- **Umbrales fijos en vez de comparación con línea base**: descartada por D-72. Los umbrales fijos son arbitrarios y no se adaptan a corpus pequeños o idiomas con pocos casos.
- **Evaluación solo global (sin separar por idioma)**: descartada porque un decisor puede tener buen acierto global y mal acierto en un idioma requerido. D-72 exige verificar cada idioma.

## Consecuencias

- Los informes se escriben de forma atómica y se ligan al hash del modelo y de la configuración.
- El corpus se construye con herramientas de Gunther (`capture`, `label`, `synthesize`, `adversarial`).
- La verificación es relativa a una línea base con intervalo de Wilson.
- `Doctor.calibrate_router/2` y `Doctor.calibrate_rag/2` usan este harness.
- `Gunther.Eval.Corpus` es una API pública con cuatro funciones.

## Verificación

- F4-09, F10-02, F10-03.
- F4-10 (estados `:unverified` a `:active`).
- G-12, G-18 (vía D-68).

- **Puertas F0 de las que depende**: G-12, G-18 (vía D-68)
