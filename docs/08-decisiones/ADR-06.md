# ADR D-06 — Sin clasificador ni embedder por defecto

- **Estado**: aceptada
- **Decidida**: decisión del dueño, 2026-10-11.
- **Fuente**: README original de `08-decisiones` (decidido hasta 2026-10-21; `main` 398a1b9)

## Contexto
**El motivo, textual**: *«no podemos poner llm ni embeddings modelos por defecto
porque implica que el proyecto los lance. Y si el usuario no los usa?»*

Es más fuerte que el argumento que había en el `@doc` del clasificador
—*«tomarlo por omisión es tomarlo sin querer»*—, porque añade la consecuencia
práctica: **un default que arranca un LLM por su cuenta consume GPU sin que nadie
lo haya pedido**.

## Decisión
**Qué**: las capas `:llm` y `:embedding` quedan **inertes** hasta que se registre
un clasificador o un embedder.

## Alternativas consideradas
El documento original no recoge alternativas descartadas para esta decisión.

## Consecuencias
**Consecuencia medible**: con `exclusive = false` y sin capas registradas, el
camino caliente **no arranca ninguna cola y no emite ningún evento**.

## Verificación
El documento original no define una verificación específica; ver las puertas F0.

- **Puertas F0 de las que depende**: ninguna
