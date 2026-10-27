# ADR D-22 — La memoria común: un mapa clave→valor, no historial

- **Estado**: aceptada
- **Decidida**: 2026-10-19, por el dueño.
- **Fuente**: README original de `08-decisiones` (decidido hasta 2026-10-21; `main` 398a1b9)

- Resuelta en r7 (D-90, J-11). Choque original: D-22 define `meta.author`, `superseded_by` y un mapa común con prefijo `mem:*`; el SPEC r6 §7.2 usa espacio de nombres por consumer (`mem:<consumer>:<key>`, con `consumer: :global` como ámbito compartido) y no define `meta.author` ni `superseded_by`.

## Contexto
**No depende del RAG ni de un embedder**: una memoria que se busca por clave
(`mem:proyecto_42`) es un `get`, no un vector. Los embeddings solo harían
falta si se busca por significado («¿qué sabemos del proyecto 42?» sin decir
el 42). Atarla al RAG le ponía un prerrequisito que no necesita.

## Decisión
**Qué**: la memoria común (F2.4, fase 9) es un **mapa clave→valor compartido**
que todos los consumers leen y escriben, con su propia clave (`mem:*`). No es
historial: responde a «qué sabemos», no «qué hemos dicho». Cuatro respuestas:

1. **¿Qué es?** Un mapa clave→valor compartido, con prefijo propio `mem:*`.
   No es historial: es un producto distinto porque responde a otra pregunta.
2. **¿Quién escribe?** Todos, con marca de autor (`meta.author`). Con varios
   consumers escribiendo a la vez hace falta `put_new/2` o compare-and-swap.
3. **¿Se puede desmentir?** Sí, y tiene que poder. Sin desmentir, la memoria
   miente cada vez más fuerte. Se desmiente creando una nueva entrada con
   `superseded_by`, o borrando y volviendo a escribir.
4. **¿Se resume?** No. Se poda por antigüedad y caducidad (`expires_at` por
   entrada). Resumir una memoria compartida produce una memoria que nadie
   reconoce.

## Alternativas consideradas
El documento original no recoge alternativas descartadas para esta decisión.

## Consecuencias
**Desbloquea**: F2.4 (SharedMemory), F2.7 (voces / mesa camilla).

## Verificación
El documento original no define una verificación específica; ver las puertas F0.

- **Puertas F0 de las que depende**: ninguna
