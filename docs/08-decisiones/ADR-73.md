# ADR D-73 — Publicación y contribución

- **Estado**: propuesta
- **Fecha**: 2026-10-25
- **SPEC**: SPEC-000-GUNTHER r6

## Contexto
Decisión del dueño sobre publicación.

## Decisión
Paquete `gunther` en Hex. Licencia Apache-2.0 (abierta, con atribución obligatoria mediante `NOTICE`). Contribución: no se aceptan cambios directos; se propone mediante issues y el autor decide.

## Alternativas consideradas
Licencia propia que restrinja las modificaciones ajenas (descartada: no es de código abierto y frenaría la adopción; no verificado con Hex).

## Consecuencias
Cualquiera puede mantener su propia bifurcación bajo Apache-2.0; la política de contribución gobierna el repositorio oficial.

## Verificación
G-16.

- **Puertas F0 de las que depende**: G-16
