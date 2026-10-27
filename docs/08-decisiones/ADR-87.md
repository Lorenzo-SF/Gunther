# ADR D-87 — Sección `[consumers.<id>]`

- **Estado**: propuesta (resuelta por delegación del dueño en r7)
- **Fecha**: 2026-10-26
- **Fuente**: SPEC §5.8, §14.1; resuelve J-05 y J-08 (D-09, D-15)

## Contexto
D-09 define para cada consumer tres niveles de búsqueda de modelo con `model_default` obligatorio, y D-15 una prioridad por consumer con envejecimiento. El SPEC r6 no tenía ninguna sección `[consumers.*]`.

## Decisión
Se añade `[consumers.<id>]` con `default_model` (obligatorio; alias del catálogo) y `priority` (opcional, peso del `Selector`). El envejecimiento es `peso efectivo = priority + espera_ms / selector.aging_step_ms` (división entera; `aging_step_ms` por defecto 1000, parámetro calibrado en F4). Los tres niveles de búsqueda se interpretan como: reglas del consumer, reglas globales (§6.8) y `default_model`.

## Alternativas consideradas
Consumers solo implícitos en `gateway.api_keys` (descartado: D-09 exige el modelo por defecto).

## Consecuencias
El aviso de `Doctor` sobre `rag_query` cuenta los consumers de esta sección. **Interpretación de los dos primeros niveles pendiente de confirmar (Q-15).**

## Verificación
F1 (validación), F4 (envejecimiento).

- **Puertas F0 de las que depende**: ninguna
