# ADR D-20 — El breaker de crashes: ETS persistente + `restart: :transient`

- **Estado**: aceptada
- **Decidida**: 2026-10-18, por el dueño (recomendación del agente, aceptada).
- **Fuente**: README original de `08-decisiones` (decidido hasta 2026-10-21; `main` 398a1b9)

- **Sustituida por D-47 y por SPEC §3.2**: ahora es `Arrea.CircuitBreaker`, con single-flight. Se conserva el texto original.
- Resuelta en r7 (D-91, J-10). Choque original: D-20 hace que un agente con circuito abierto deje de reiniciarse (`restart: :transient` más `Agents.Breakers`); el SPEC r6 §10.1 retira expresamente esa regla («el breaker es por provider y el agente por tarea»).

## Contexto
**Por qué**: es consistente con la arquitectura ya establecida (ETS en el árbol
de la aplicación, por nombre, como `Snapshots` y `Breakers`). No requiere
rediseñar el supervisor.

## Decisión
**Qué**: la mitad restante del §8.3 se cierra con **`restart: :transient`** para
los agentes cuyo circuito esté abierto, combinado con el estado del breaker en
ETS (ya implementado en `Gunther.Agents.Breakers`). Un agente que revienta en
bucle deja de reiniciarse cuando su circuito está abierto; los agentes sin
nombre se quedan con la intensidad global del supervisor (10/5 s), que es la
única defensa disponible sin identidad.

## Alternativas consideradas
**Se dejó de hacer**: un presupuesto de crashes por agente en el supervisor
(ya implementado en tanda 3 para los nombrados), y el diseño de supervisor
completo para los sin nombre.

## Consecuencias
El documento original no recoge consecuencias adicionales.

## Verificación
El documento original no define una verificación específica; ver las puertas F0.

- **Puertas F0 de las que depende**: G-02, G-03
