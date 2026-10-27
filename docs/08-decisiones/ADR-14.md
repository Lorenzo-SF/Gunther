# ADR D-14 — «Agente» significa una sola cosa: el proceso; la mesa tiene voces

- **Estado**: aceptada
- **Decidida**: 2026-10-16, por el dueño.
- **Fuente**: README original de `08-decisiones` (decidido hasta 2026-10-21; `main` 398a1b9)

## Contexto
La palabra tenía dos candidatos, y por eso estaba en el relevo:

| Candidato | Qué es | Dónde está escrito |
|---|---|---|
| **El proceso** | `use Gunther.Agent, name:, goal:, tools:, max_steps:` — bucle, traza, cancelación | `lib/gunther/agent.ex`, el diseño entero de [`05-agentes`](../04-modulos/05-agentes/README.md) y la fase **10** |
| **El participante de las rondas** | un `(modelo, rol)` de la mesa, configurado desde el TOML | la decisión 2 de la ronda 7 del consejero: qué modelos participan, sus roles, si se les permite |

Es la misma trampa que `usage`, que mezclaba endpoints y capacidades: una
palabra, dos conceptos, y el que llega segundo se lee como si fuera el primero.
Se cierra dándosela al de casa, y la razón es de reloj:

| Hecho | Medición |
|---|---|
| Consumidores de `use Gunther.Agent` en `lib/` | **cero**: los dos únicos usos del repo están en tests |
| Menciones de `Gunther.Agent` que costaría renombrar hoy | 56 (6 en `lib`, 15 en tests, 35 en docs) |
| Secciones del catálogo | una palabra por concepto: `[engine.X]`, `[model.X]`, `[provider.X]`, `[consumer.X]` |
| Diseño de la mesa | **no existe**: solo las rondas del consejero |

El de casa tiene diseño completo, tests y una fase que se abre justo ahora
(F5.1, tras D-13); a la mesa le falta el diseño entero, así que su vocabulario
se escribe sin coste. Al revés —renombrar lo de hoy para que la mesa herede la
palabra— se pagaría dos veces.

**No prohíbe sumar**: si el día de mañana un participante de la mesa es un
proceso que decide paso a paso, **es** un agente de la taxonomía (un tipo 1 o 2
con el modelo pineado) y usa el vocabulario de siempre. La regla es de sentido,
no de censo: una palabra, una cosa; si la cosa se vuelve un agente, la palabra
ya la tenía.

## Decisión
**Qué**: «agente» se queda con el sentido que ya tiene `Gunther.Agent` — un
proceso que decide paso a paso, con bucle, herramientas y estado (la fase
**10**). La mesa camilla (la fase **9**) no reutiliza la palabra: sus
participantes se llaman **voces**. `[agent.X]` queda reservado para agentes de
verdad; el día que la mesa necesite catálogo será suyo (`[mesa.…]` o una lista
dentro de ella), no una segunda acepción de «agente».

## Alternativas consideradas
**Se dejó de hacer**: renombrar `Gunther.Agent` (a `Gunther.ReAct` u otro);
abrir `[agent.X]` con el sentido de «participante de las rondas»; y dejar el
nombre del behaviour `Gunther.Agents.Behaviour` —que la F5.1 va a fijar— colgando
de un diseño que aún no existe.

## Consecuencias
**La frase que resume todo**:
> «Agente» es el proceso que decide paso a paso; los que participan en la mesa
> son voces.

## Verificación
El documento original no define una verificación específica; ver las puertas F0.

- **Puertas F0 de las que depende**: ninguna
