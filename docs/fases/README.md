# Fases de diseño (DP3)

Esta carpeta contiene **una nota de fase por cada fase de desarrollo** (`docs/fases/F0.md`, `docs/fases/F1.md`, ..., `docs/fases/F22.md`). Se rellena al abrir cada fase, antes de escribir código (DP3 en `docs/01-plan-de-desarrollo.md` §2).

## Qué contiene una nota de fase

Cada `Fnn.md` debe tener, como mínimo:

1.  **Secciones del SPEC que cubre** (con enlaces a `SPEC-000-GUNTHER_r9.md` §N).
2.  **Decisiones locales** que se toman al implementar (con justificación). Si alguna contradice el SPEC, se detiene el trabajo y se abre `rN+1` (regla 3 de `docs/01` §1).
3.  **Paquetes de trabajo** (`Fnn-01`, `Fnn-02`, ...) con objetivo, dependencias y criterios de aceptación. Los WP usan los identificadores del **plan** (`docs/01-plan-de-desarrollo.md` §4), porque el SPEC §19.2 los cita.
4.  **Pruebas** que se van a ejecutar, separando unitarias, propiedades, contrato, integración y caos.
5.  **Riesgos locales** de la fase (los riesgos globales están en `SPEC §20`).
6.  **Checklist de cierre**: qué AC del SPEC §19 tiene que estar verde para cerrar la fase.

## Las dos tablas

Una nota de fase lleva **dos tablas**, y se distinguen por **dos** cosas a la
vez: el **número de celdas** y la **forma del identificador**.

| Tabla | Celdas | Identificador | Para qué |
|---|---|---|---|
| Los WP de la fase | **3** | `Fnn-nn` (`F3-04`) | Qué WP hay, de qué depende y qué AC cierra cada uno |
| Los AC y dónde se verifican | **4** | `Fnn-ACn` (`F3-AC7`) | Qué AC hay y qué test lo verifica |

**Por qué el infijo `AC`.** Antes, el WP del plan era `F3-01` y el AC de la
nota `F3-AC1`: la misma forma con un dígito de diferencia. Un modelo que las
confundía cerraba el AC equivocado y declaraba un WP terminado sin haberlo
hecho. **Un identificador que se parece a otro es un error esperando a
pasar.** Los WP **no** se renombran (`Fnn-nn`), porque el SPEC §19.2 los cita
(`F1-01`, `F4-03`, `F4-04`) y el SPEC es la ley; los AC sí, porque son ids
locales de la nota.

Una fila cuyo identificador no tiene la forma de su tabla **hace fallar el
script**: es mejor quedarse sin saber qué hacer que decidir sobre un estado
inventado.

### La tabla de WP (3 celdas)

```markdown
| WP | Dependencias | AC que cierra |
| --- | --- | --- |
| F3-01 | — | F3-AC1, F3-AC2 |
| F3-02 | F3-01 | F3-AC3 |
```

- El **contenido** de cada WP no se repite aquí: está en el plan de
  desarrollo (`docs/01-plan-de-desarrollo.md` §4), que es su sitio. Copiarlo
  aquí es tener la misma verdad en dos sitios, y las dos se separan.
- Las **dependencias** son de WP, no de fase.
- La columna **AC que cierra** es lo que liga el WP con sus AC: un WP está
  terminado cuando **todos** sus AC están en verde.

### La tabla de AC (4 celdas)

```markdown
| # | AC | Test que lo verifica | En |
| --- | --- | --- | --- |
| F3-AC1 | Lo que el AC exige | `test/algo_test.exs` · "el nombre del test" | F3 |
| F3-AC2 | Lo que el AC exige | `test/otro_test.exs` · "el nombre del test" | BLOQUEADA |
```

- La columna **En** dice en qué fase se verifica: `Fnn`, `BLOQUEADA` (falta
  hardware) o `PENDIENTE` (el trabajo no está hecho). **Un AC bloqueado o
  pendiente no es un AC cumplido**: no cuenta, y la fase no se cierra.
- La columna del test es la que ejecuta `scripts/check_ac.sh`: si el test no
  existe, o el fichero no pasa entero, el AC **no** está cumplido.
- Los AC que se difieren a otra fase van en esta misma tabla con esa fase en
  la columna **En**. No hay una segunda tabla de AC: dos tablas de AC las
  leen dos scripts y divergen.

## Plantilla

Copia esta plantilla al abrir una fase:

```markdown
# Fnn — [nombre de la fase]

> Nota de fase (principio 2 del plan de desarrollo). El cierre de la fase se
> ejecuta con `scripts/check_phase.sh Fnn` y `scripts/check_ac.sh docs/fases/Fnn.md Fnn`.

**Base**: `SPEC-000-GUNTHER_r9.md` §N (los AC de la fase), §N ...

**Estado: EN CURSO.** Esta nota dice **qué está hecho y qué falta**, no da la
fase por cerrada.

## Objetivo

[Qué entrega esta fase, en una frase.]

## Lo que ya está

| Pieza | Fichero | Qué resuelve |
| --- | --- | --- |
| ... | `lib/...` | ... |

## Los WP de la fase

| WP | Dependencias | AC que cierra |
| --- | --- | --- |
| Fnn-01 | — | Fnn-AC1 |
| Fnn-02 | Fnn-01 | Fnn-AC2, Fnn-AC3 |

## Los AC y donde se verifican

Un AC esta cerrado cuando **un test lo verifica**. La columna del test es la
que `scripts/check_ac.sh` ejecuta: si el test no existe, la fase no se cierra.

| # | AC (SPEC §19, Fnn) | Test que lo verifica | En |
| --- | --- | --- | --- |
| Fnn-AC1 | ... | `test/..._test.exs` · "..." | Fnn |
| Fnn-AC2 | ... | `test/..._test.exs` · "..." | BLOQUEADA |

## Decisiones locales

[Ninguna / lista de decisiones tomadas al implementar, con justificación.]

## Pruebas

[Lista de pruebas que se ejecutan en esta fase.]

## Riesgos locales

[Ninguno / lista.]

## Checklist de cierre

- [ ] AC de Fnn en `SPEC §19` ejecutados y verdes (`scripts/check_ac.sh docs/fases/Fnn.md Fnn`).
- [ ] Pruebas de la fase en CI.
- [ ] `mix check.all` en verde.
- [ ] SPEC actualizado si hubo desviaciones.
- [ ] Fila añadida a `docs/13-registro-de-fases.md`.
- [ ] Tag `fNN-cerrada`.
```

## La cola de trabajo sale de aquí

`scripts/next_task.sh` **deriva** la siguiente tarea de estas tablas y del
estado real:

- la fase que toca es la primera del *orden recomendado* del plan que no
  está cerrada en `docs/13-registro-de-fases.md`;
- el WP que toca es el primero de esa fase cuyos AC **no** están todos en
  verde, según `scripts/check_ac.sh --machine`, que ejecuta los tests de
  verdad.

Por eso la nota de fase tiene que estar **escrita y con las dos tablas**: sin
la tabla de WP, la cola no sabe qué hacer; sin la tabla de AC, no sabe qué
comprobar.

Una fila que no se reconoce (un número de celdas que no es 3 ni 4, o un
identificador con la forma de la otra tabla) hace **fallar** el script: es
mejor que se quede sin saber qué hacer a que decida sobre un estado
inventado.

## Estado actual

A fecha de 2026-10-29:

- **DP0** cerrado (`CIERRE-DP0.md`).
- **DP1** siguiente (por qué de D-01 a D-47 en ADRs completos).
- **DP2** pendiente (contratos en código).
- **DP3** se abre al iniciar cada Fnn. Hay notas de F1, F2 y F3.
- **DP4** pendiente (congelación de API antes de `1.0.0`).

Las fases de desarrollo (F0 a F22) están planificadas en `docs/01-plan-de-desarrollo.md` y en `SPEC §19`. Sus notas se crean al abrirlas.
