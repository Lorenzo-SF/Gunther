# AGENTS.md — Gunther

Contrato de trabajo para quien toque este repositorio: una persona o un
modelo. Lo largo está en `docs/14-planificacion-del-coder.md`; aquí está lo
que hay que hacer, cómo se comprueba y qué no se toca sin permiso.

## Qué es esto

Gunther es un **router de inferencia LLM** en Elixir. Decide qué proveedor,
qué modelo y qué nodo atienden una petición, con reglas explícitas, y lleva
la cuenta de los recursos (VRAM, KV cache) que el motor necesita. El
comportamiento está **fijado** en `SPEC-000-GUNTHER_r9.md` (SPEC vigente).

## Lo que manda, por orden

1. **`SPEC-000-GUNTHER_r9.md`** — el comportamiento. Si el código necesita algo
   que el SPEC no dice, **para y pregunta**: el SPEC se cambia con una revisión
   nueva (`r10`...), que aprueba el dueño con su tabla de cambios en el Anexo D.
2. **`docs/08-decisiones/`** — los ADR: el porqué de cada decisión.
3. **`docs/13-registro-de-fases.md`** — el estado real, con lo que se midió.
4. **`docs/fases/Fnn.md`** — la nota de la fase en curso: AC, decisiones
   locales, desviaciones.

## El ciclo: TDD estricto

```
1. Leer el AC del SPEC (§19) y la nota de fase.
2. Escribir el test que falla.  <- este paso primero, siempre
3. Implementación mínima para que pase.
4. mix format && mix test
5. Refactor con los checks en verde.
6. Los seis checks (§"Las comprobaciones").
7. Nota de fase + CHANGELOG + registro de fases.
8. Commit: feat(F3-0X): qué y por qué.
```

**Un AC sin test es un AC sin cumplir.** Un AC bloqueado o pendiente tampoco
está cumplido: se declara como tal y **no cierra la fase**.

## Las comprobaciones

```bash
mix format --check-formatted
mix compile --force --warnings-as-errors
mix credo --strict --format=oneline     # cero avisos, de ninguna prioridad
mix dialyzer
mix test
bash scripts/check_boundaries.sh
bash scripts/doc_lint.sh
bash scripts/check_ac.sh   docs/fases/F3.md F3
bash scripts/check_phase.sh F3
```

`check_phase.sh` es **la** puerta de una fase: formatea, compila, pasa Credo
con `--strict`, pasa Dialyzer, corre la suite tres veces seguidas, comprueba
las fronteras, el lint de documento, que el paquete se construye, que el SPEC
no ha cambiado sin revisión, que el registro declara la fase y que **todo
doctest del núcleo se ejecuta**.

## Las reglas que no se negocian

- **Los errores son valores**, nunca excepciones. Un código fuera de la tabla
  de §4.13 es `:internal_error`.
- **`Gunther.Command` es la única puerta de ejecución**. Ni `System.cmd`, ni
  `:os.cmd`, ni `Port.open` en ningún otro sitio (`scripts/check_boundaries.sh`
  lo vigila).
- **`Arrea`, `Apero` y `Trebejo` solo se tocan en los cinco módulos de
  frontera** que la lista de §3.6 del SPEC nombra.
- Nada de secretos en el código, la documentación, los logs ni los commits.
- Todo proceso nuevo, supervisado; toda espera, con plazo; todo buffer, con
  tope.
- El type checker de Elixir 1.19 comprueba los argumentos contra el `@spec`:
  un `new(text: "x")` entrega una keyword list, **no** un mapa.

## Lo que no se hace sin que lo pida el dueño

- Cambiar el SPEC (ni una línea) — se propone, lo aprueba el dueño.
- **Cerrar una fase** o **mergear un PR**: hace falta CI verde, y ahora la CI
  de GitHub no arranca (minutos de Actions agotados). Escribir el trabajo,
  dejarlo en una rama y abrir el PR: eso sí.
- Publicar en hex.pm, tocar el toolchain, o tocar los repos hermanos
  (`arrea`, `apero`, `trebejo`).
- Afirmar que algo está validado en hardware sin haberlo medido en hardware.

## El detective: hay trampas, y están medidas

La lista completa está en `docs/14-planificacion-del-coder.md` §6. Las que
más han costado:

- **Un doctest que no se ejecuta es un doctest muerto**: todo módulo con
  `iex>` va en `test/gunther/doctests_test.exs`, y hay un check que lo vigila.
- **Un check con OK falso es peor que no tener check**: cuenta los avisos de
  Credo **sin filtrar por prioridad**.
- **`grep` del nombre no prueba que exista el campo**: sigue el **tipo**.
- **Las dos ramas de una decisión, invertidas**, no las ve nadie: el test sí.
- Un límite calculado con un valor que puede ser negativo se rompe
  *intermitentemente*.
- Una entrada malformada **bloquea**; no revienta.
- Un doc que afirma lo contrario de lo que hace el código: gana el código, y
  se arregla el doc.

## Antes de commitear

```bash
git status --porcelain
git diff --cached --name-only
```

Staging explícito: **no** arrastrar trabajo de otros carriles. Los commits
llevan fecha entre las 20:00 y las 02:00 (Europe/Berlin) en día laborable, y
el merge es **squash**.
