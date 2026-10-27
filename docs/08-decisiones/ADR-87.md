# ADR D-87 — Sección `[consumers.<id>]`

- **Estado**: aceptada (DP0, r8; Q-15)
- **Fecha**: 2026-10-26
- **Fuente**: SPEC r8 §5.8, §6.8.1, §14.1, §14.2; resuelve J-05 y J-08 (D-09, D-15)

- Nota (r8, Q-15): la interpretación de los tres niveles de D-09 queda cerrada. Nivel 1: reglas del consumer, declaradas en `[[consumers.<id>.rules]]` con la misma forma que `[[rules]]`. Nivel 2: reglas globales (`[[rules]]`). Nivel 3: `default_model` del consumer. La precedencia completa está en §6.8.1 del SPEC r8. `[[consumers.<id>.rules]]` es la sintaxis canónica; el campo `when` es opcional (sin `when`, la regla aplica siempre).

## Contexto

D-09 define para cada consumer tres niveles de búsqueda de modelo con `model_default` obligatorio, y D-15 una prioridad por consumer con envejecimiento. El SPEC r6 no tenía ninguna sección `[consumers.*]`.

## Decisión

Se añade `[consumers.<id>]` con `default_model` (obligatorio; alias del catálogo) y `priority` (opcional, peso del `Selector`). El envejecimiento es `peso efectivo = priority + espera_ms / selector.aging_step_ms` (división entera; `aging_step_ms` por defecto 1000, parámetro calibrado en F4).

**Reglas por consumer.** Cada consumer puede declarar sus propias reglas con la misma forma que las globales:

- `[[consumers.<id>.rules]]`: lista de reglas del consumer.
- Cada regla tiene `name` (único en el espacio combinado con `[[rules]]`), `when` (opcional; sin `when`, aplica siempre), `action` (`veto` | `force` | `prefer`), `target` y `weight` (solo con `prefer`).
- Las reglas de un consumer se evalúan **solo** para las peticiones de ese consumer. Las globales se aplican a todos.

**Precedencia completa**, de más fuerte a más débil:

1.  `veto` de consumer.
2.  `veto` global.
3.  `force` de consumer.
4.  `force` global.
5.  `prefer` de consumer.
6.  `prefer` global.
7.  `default_model` del consumer.

Dos `force` en el mismo nivel en desacuerdo se intersecan; si el resultado es vacío, `:no_candidates` con `details.filtered`.

**Casos borde.** Si un consumer veta su propio `default_model` y no queda otro candidato, la petición devuelve `:no_candidates` con `:consumer_veto` en `filtered` (no es `:refused_capacity`). Dos reglas con el mismo `name` en el espacio combinado son `config_error` al cargar. Un `consumer:` en la petición que no está en `[consumers.*]` es `:invalid_request` con `details.consumer`. Un `veto` de un consumer no puede vetar candidatos de otro consumer.

**Traza.** `Decision.consumer_rules_applied` y `Decision.global_rules_applied` listan los `name` de las reglas que actuaron.

**Caché.** La clave de §6.5 incluye el hash de `[[consumers.*.rules]]` a través del «hash del catálogo», que se extiende a las reglas de consumer.

## Alternativas consideradas

Consumers solo implícitos en `gateway.api_keys` (descartado: D-09 exige el modelo por defecto). Consumers sin reglas propias (descartado en Q-15: D-09 pide tres niveles explícitos).

## Consecuencias

El aviso de `Doctor` sobre `rag_query` cuenta los consumers de esta sección. Los consumidores pueden declarar sus propias reglas de privacidad, localidad o coste. La interpretación de los tres niveles queda cerrada en §6.8.1 del SPEC r8.

## Verificación

F1 (validación de `[[consumers.<id>.rules]]`), F4 (envejecimiento, precedencia y traza).

- **Puertas F0 de las que depende**: ninguna
