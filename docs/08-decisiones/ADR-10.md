# ADR D-10 — Una fase no se cierra por el CLI, ni por los tests, ni por un verde

- **Estado**: aceptada
- **Decidida**: en vigor desde el principio, y **reforzado tres veces** esta semana.
- **Fuente**: README original de `08-decisiones` (decidido hasta 2026-10-21; `main` 398a1b9)

## Contexto
La forma concreta que se ha repetido:

| | |
|---|---|
| Los 800 tests en verde y el refusal inexistente | fase 0 |
| 4 tests de cmake que **solo existen si hay cmake** | compara "0 fallos" con dos suites distintas |
| La cola al revés y un test llamado *"la prioridad manda"* **que no comprobaba la prioridad** | 4 fallos locales, 0 en CI |
| La suite escribiendo en el `~/.gunther` del developer | 4 rojos en CI, 0 en local |

**La regla que sale de las cuatro**: un verde que no se puede reproducir **es peor
que un rojo**, porque un rojo por lo menos señala un fichero.

## Decisión
**Qué**: una fase se cierra cuando el criterio se ha **ejecutado de verdad**.

## Alternativas consideradas
El documento original no recoge alternativas descartadas para esta decisión.

## Consecuencias
El documento original no recoge consecuencias adicionales.

## Verificación
El documento original no define una verificación específica; ver las puertas F0.

- **Puertas F0 de las que depende**: ninguna
