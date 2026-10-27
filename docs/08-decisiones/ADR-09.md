# ADR D-09 — El refusal se configura, no se decide de una vez

- **Estado**: aceptada
- **Decidida**: 2026-10-11, por el dueño.
- **Fuente**: README original de `08-decisiones` (decidido hasta 2026-10-21; `main` 398a1b9)

- Resuelta en r7 (D-88, J-04). Choque original: D-09 y D-11 (punto 1) dicen que el defecto del refusal no está puesto; el ejemplo de SPEC §14.1 fija `[refusal] policy = "wait"`.
- Resuelta en r7 (D-87, J-05). Choque original: D-09 describe `Router.Consumer` con tres niveles de búsqueda y `model_default` obligatorio en `[consumer.X]`; el SPEC r6 no tiene secciones `[consumer.X]` en §14.1 (los consumers aparecen solo en `gateway.api_keys` y en `opts.consumer`).

## Contexto
**La pregunta que yo tenía mal planteada**: *"¿qué pasa si no hay candidato?"*.
Eso **ya estaba resuelto** desde antes: `Router.Consumer` tiene tres niveles de
búsqueda y el tercero es `model_default`, y **el schema lo exige** — un
`[consumer.X]` sin él no valida y el TOML falla al arrancar.

La pregunta de verdad es la del destino **ocupado**, que no tiene default: el
default es un modelo, y lo que falta es el sitio.

## Decisión
**Qué**: cuando el destino está ocupado y no cabe, `fail` · `wait` · `degrade`,
**configurable**, y las tres son válidas.

**Dos reglas que el valor no puede cambiar**, escritas:

1. **Ninguna devuelve un modelo vetado.** Es seguridad, no política.
2. **`fail` nunca miente con números**: o sale el motivo con
   `requested`/`available`/`capacity`, o sale *que no se sabe*. Un `-1` que
   significa "no lo sé" y un `0` que significa "no hay" son el mismo bug (D-04).

## Alternativas consideradas
El documento original no recoge alternativas descartadas para esta decisión.

## Consecuencias
El documento original no recoge consecuencias adicionales.

## Verificación
El documento original no define una verificación específica; ver las puertas F0.

- **Puertas F0 de las que depende**: ninguna
