# Fases de diseño (DP3)

Esta carpeta contiene **una nota de fase por cada fase de desarrollo** (`docs/fases/F01.md`, `F02.md`, ..., `F22.md`). Se rellena al abrir cada fase, antes de escribir código (DP3 en `docs/01-plan-de-desarrollo.md` §2).

## Qué contiene una nota de fase

Cada `Fnn.md` debe tener, como mínimo:

1.  **Secciones del SPEC que cubre** (con enlaces a `SPEC-000-GUNTHER_r8.md` §N).
2.  **Decisiones locales** que se toman al implementar (con justificación). Si alguna contradice el SPEC, se detiene el trabajo y se abre `rN+1` (regla 3 de `docs/01` §1).
3.  **Paquetes de trabajo** (`Fnn-01`, `Fnn-02`, ...) con objetivo, dependencias y criterios de aceptación.
4.  **Pruebas** que se van a ejecutar, separando unitarias, propiedades, contrato, integración y caos.
5.  **Riesgos locales** de la fase (los riesgos globales están en `SPEC §20`).
6.  **Checklist de cierre**: qué AC del SPEC §19 tiene que estar verde para cerrar la fase.

## Plantilla

Copia esta plantilla al abrir una fase:

```markdown
# Fnn — [nombre de la fase]

- **Inicio**: AAAA-MM-DD
- **Fin**: (pendiente)
- **SPEC**: §X, §Y, §Z
- **Decisiones aplicables**: D-nn, D-mm
- **Puertas F0 que la bloquean**: G-nn (deben estar PASA o BLOQUEADA con rama B aplicada)

## Objetivo

[Qué entrega esta fase, en una frase.]

## Paquetes de trabajo

| WP     | Contenido | Dependencias | AC  |
| ------ | --------- | ------------ | --- |
| Fnn-01 | ...       | ...          | ... |

## Decisiones locales

[Ninguna / lista de decisiones tomadas al implementar, con justificación.]

## Pruebas

[Lista de pruebas que se ejecutan en esta fase.]

## Riesgos locales

[Ninguno / lista.]

## Checklist de cierre

- [ ] AC de Fnn en `SPEC §19` ejecutados y verdes.
- [ ] Pruebas de la fase en CI.
- [ ] SPEC actualizado si hubo desviaciones.
- [ ] Fila añadida a `docs/13-registro-de-fases.md`.
- [ ] Tag `fNN-cerrada`.
```

## Estado actual

A fecha de 2026-10-26:

- **DP0** cerrado (`CIERRE-DP0.md`).
- **DP1** siguiente (por qué de D-01 a D-47 en ADRs completos).
- **DP2** pendiente (contratos en código).
- **DP3** se abre al iniciar cada Fnn; no hay notas todavía.
- **DP4** pendiente (congelación de API antes de `1.0.0`).

Las fases de desarrollo (F0 a F22) están planificadas en `docs/01-plan-de-desarrollo.md` y en `SPEC §19`. Sus notas se crean al abrirlas.
