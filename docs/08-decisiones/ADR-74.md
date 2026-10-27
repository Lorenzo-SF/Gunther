# ADR D-74 — La coral (colmena y equipo como modalidades)

- **Estado**: propuesta
- **Fecha**: 2026-10-26
- **Fuente**: SPEC §22.1, §22.2, §22.9; peticiones del dueño del 2026-10-26

- Resuelta por delegación (valores por defecto de SPEC §21, reversibles): Q-09 (la coral va después de 1.0 con los ganchos G1 a G9 en v1), Q-10 (se mantiene `:routing_vote`), Q-13 (`Gunther.Coral` sustituye a `Hive` y `Voice`), Q-13 (nombre `Gunther.Coral`).

## Contexto
El dueño plantea que la mente colmena y el modo teamwork son metodologías de trabajo de un grupo de agentes definido (objetivo, organización y enrutado distintos, esencia igual), que «mesa camilla» y «mente colmena» son el mismo concepto, y que Gunther debe ofrecer herramientas usables por separado y perfectamente integradas.

## Decisión
Se crea **la coral**: la infraestructura integrada de Gunther más una base para organizar grupos de agentes. Colmena (`:hive`) y equipo (`:teamwork`) son modalidades; el desarrollador puede crear otras. Sustituye al módulo de colmena y voces de §10.2.

## Alternativas consideradas
Mantener la colmena y un modo teamwork como módulos separados (descartado por el dueño: misma esencia).

## Consecuencias
Revisa D-30 (nombre), D-46 (contrato de voces) y D-56 (colmena a v1.1). D-14 sigue vigente: «agente = el proceso» y no prohibía que los participantes fueran agentes.

## Verificación
F18 a F20 (SPEC §22.18).

- **Puertas F0 de las que depende**: ninguna
