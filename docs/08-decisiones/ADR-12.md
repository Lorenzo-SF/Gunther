# ADR D-12 — Gunther manda la pregunta; la respuesta no es suya

- **Estado**: aceptada
- **Decidida**: 2026-10-14, por el dueño.
- **Fuente**: README original de `08-decisiones` (decidido hasta 2026-10-21; `main` 398a1b9)

- Resuelta en r7 (D-90, J-06). Choque original: D-12 apoya la vigilancia de la salud del destino en `Telemetry.Quality` (`finish_reason` anómalo, reintentos); el SPEC r6 §13.1 no define esos eventos.

## Contexto
#### Por qué está escrito, porque es lo contrario de lo que parece

Medido el 2026-10-14 sobre los GGUF de esta máquina, con una pregunta de
aritmética y `temperature 0`:

| modelo | `reasoning_content` | respuesta |
|---|---|---|
| `gpt-oss-20b` | 639 bytes | «10 patas en total.» |
| `Qwen3.8-27B` | 1996 bytes | «10. En total hay 10 patas.» |
| `DeepCoder-14B` | 558 bytes | |
| `Qwen3-Coder-30B` | ausente | |
| `Ministral-3-14B` | ausente | **«18 patas (3×2 + 2×2)»** ✗ |
| `Devstral-Small-2-24B` | ausente | **«Hay 14 patas»** ✗ |

`Devstral` es el `coder_lite` del catálogo y **se equivoca**, y no falla de
ninguna forma técnica: devuelve un 200 con texto equivocado, con `temperature
0`, que es el caso más fácil que hay.

Si Gunther juzgara la respuesta, ¿con qué? No tiene la verdad terrena. Y un
motor que finge saber si una respuesta es buena es peor que uno que no lo
sabe, porque sus decisiones dejan de ser auditables.

## Decisión
**Qué**: Gunther **enruta**. No sabe si una respuesta es correcta y no debe
intentar saberlo. La respuesta la evalúa **quien ha hecho la pregunta**: el
usuario de la línea de comandos, o el consumidor del gateway.

## Alternativas consideradas
#### Lo que esto NO significa

| | |
|---|---|
| **El enrutado no se evalúa** | sí se: el tribunal de `DISENO-MOTOR` §10 mide si la **capa decide bien**, que es otra pregunta |
| **La calidad no se vigila** | `Gunther.Telemetry.Quality` mide la **salud del destino**: un `finish_reason` anómalo dice que se quedó corto, un reintento dice que algo falló. Ninguna de las dos mira si la respuesta es *cierta* |
| **El razonamiento se tira** | se expone en `response().reasoning` para quien pidió, y **no se usa para enrutar** |

## Consecuencias
#### Por qué importa para lo que viene

La fase `:llm` del router no sería «un modelo que juzga respuestas», sería
**una capa más para decidir a quién mandar**. Si alguien propone que el LLM
evalúe la respuesta, esta decisión está escrita y hay que cambiarla a
propósito, no de paso.

Es también lo que hace que el 16.7% del tribunal **no sea una alarma**: mide
la capacidad de decisión del motor estático, no si los modelos saben contar
patas. Son dos preguntas, y la que le importa a Gunther es la primera.

## Verificación
El documento original no define una verificación específica; ver las puertas F0.

- **Puertas F0 de las que depende**: ninguna
