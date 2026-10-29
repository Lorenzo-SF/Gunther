#!/usr/bin/env bash
#
# Autocomprobacion de `scripts/next_task.sh`.
#
# La cola de trabajo del coder **tiene que estar derivada del
# repositorio**. Si no lo esta, la lista se pudre en silencio: el modelo
# trabaja sobre una lista que ya no describe el repositorio, y nadie se
# entera hasta que el trabajo sale mal.
#
# Este script comprueba la derivacion con dobles, sin correr la suite:
#
#   1. Sin nota de fase  -> la tarea es "escribe la nota de fase".
#   2. Con nota de fase  -> la tarea es el primer WP con AC sin cumplir.
#   3. Un WP con AC en verde se salta y se da el siguiente.
#   4. Un WP cuya dependencia no esta verde se salta.
#   5. Todos los WP en verde -> no queda tarea, y el script sale con 1.
#   6. Una nota con una fila que no se reconoce -> el script falla en vez
#      de inventarse el estado (un checker con OK falso es peor que no
#      tener checker).
#
# ## El selftest ejecuta el script REAL
#
# No hay una copia de la logica aqui: se ejecuta `scripts/next_task.sh` con
# `GUNTHER_ROOT` apuntando a un repositorio de mentira y
# `GUNTHER_CHECK_AC` a un doble de `check_ac.sh`. Una copia de la logica
# se queda vieja, y el selftest acaba comprobando algo que ya no existe
# (y dando un verde falso, que es lo peor que puede pasar).
#
# Uso:
#   scripts/next_task_selftest.sh
#
# Salida: 0 si la derivacion funciona, 1 si no.

set -uo pipefail

RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

FALLOS=0

fallar() {
  echo "FALLO: $1" >&2
  FALLOS=$((FALLOS + 1))
}

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

# ---------------------------------------------------------------------
# El entorno de pruebas: un repositorio minimo con los dobles.
# ---------------------------------------------------------------------

ENTORNO="$TMP/repo"
mkdir -p "$ENTORNO/docs/fases"

# El doble de `check_ac.sh`: imprime el estado de cada AC desde un fichero
# de control. Asi el selftest decide que AC estan en verde sin tener que
# escribir tests de verdad.
cat > "$TMP/check_ac_doble.sh" <<'DOBLE'
#!/usr/bin/env bash
# Doble de check_ac.sh para el selftest: el estado de cada AC sale del
# fichero de control.
set -uo pipefail
CONTROL="${GUNTHER_SELFTEST_CONTROL:-}"
if [ -n "$CONTROL" ] && [ -f "$CONTROL" ]; then
  cat "$CONTROL"
fi
exit 0
DOBLE

# El plan: con la frase del orden recomendado, que es de donde sale la
# lista de fases.
cat > "$ENTORNO/docs/01-plan-de-desarrollo.md" <<'PLAN'
## 4. Paquetes de trabajo (WP) por fase

**Orden recomendado para una sola persona**: F0, F1, F3, F4. Motivo: prueba.

### F3 · Provider

| WP | Contenido | Pruebas |
| --- | --- | --- |
| F3-01 | Behaviour `Provider` y `Result` | Contrato |
| F3-02 | `ContractTest` generico | Contrato |
| F3-03 | Salida estructurada | Invariante |

PLAN

# El registro de fases: F0 y F1 cerradas, F3 pendiente.
cat > "$ENTORNO/docs/13-registro-de-fases.md" <<'REGISTRO'
| Fase | Inicio | Fin | Que | Desviaciones | Notas |
| --- | --- | --- | --- | --- | --- |
| **F0** | 2026-10-27 | **2026-10-28** | Verificacion | | |
| **F1** | 2026-10-28 | **2026-10-28** | Nucleo | | |
| **F3** | pendiente | | | | |
REGISTRO

correr() {
  ( cd "$ENTORNO" && \
    GUNTHER_ROOT="$ENTORNO" \
    GUNTHER_CHECK_AC="$TMP/check_ac_doble.sh" \
    GUNTHER_SELFTEST_CONTROL="${1:-}" \
    bash "$RAIZ/scripts/next_task.sh" "${2:-}" 2>&1 )
}

# --- Caso 1: sin nota de fase ---------------------------------------------

salida="$(correr "")"
rc=$?

if [ $rc -ne 0 ]; then
  fallar "sin nota de fase el script deberia salir con 0, y salio con $rc"
fi

if ! echo "$salida" | grep -q "docs/fases/F3.md"; then
  fallar "sin nota de fase deberia decir que nota hay que escribir, y salio: $salida"
fi

if ! echo "$salida" | grep -q "WP:"; then
  fallar "el informe deberia tener la linea del WP, y salio: $salida"
fi

# --- Caso 2: con nota de fase ---------------------------------------------

cat > "$ENTORNO/docs/fases/F3.md" <<'NOTA'
# F3 — Provider

## Los WP de la fase

| WP | Dependencias | AC que cierra |
| --- | --- | --- |
| F3-01 | — | F3-AC1 |
| F3-02 | F3-01 | F3-AC2 |
| F3-03 | F3-01 | F3-AC3 |

## Los AC y donde se verifican

| # | AC | Test que lo verifica | En |
| --- | --- | --- | --- |
| F3-AC1 | El behaviour | `test/a.exs` · "uno" | F3 |
| F3-AC2 | El contrato | `test/b.exs` · "dos" | F3 |
| F3-AC3 | La estructura | `test/c.exs` · "tres" | F3 |
NOTA

# El doble: ningun AC en verde todavia.
cat > "$TMP/control.tsv" <<'CONTROL'
F3-AC1	PENDIENTE	test/a.exs	uno
F3-AC2	PENDIENTE	test/b.exs	dos
F3-AC3	PENDIENTE	test/c.exs	tres
CONTROL

salida="$(correr "$TMP/control.tsv")"
rc=$?

if [ $rc -ne 0 ]; then
  fallar "con AC pendientes el script deberia salir con 0, y salio con $rc"
fi

if ! echo "$salida" | grep -q "WP:           F3-01"; then
  fallar "la primera tarea deberia ser F3-01, y salio: $salida"
fi

if ! echo "$salida" | grep -q "Behaviour"; then
  fallar "la tarea deberia decir que hay que hacer, y salio: $salida"
fi

# --- Caso 3: el primer WP en verde se salta -------------------------------

cat > "$TMP/control.tsv" <<'CONTROL'
F3-AC1	OK	test/a.exs	uno
F3-AC2	PENDIENTE	test/b.exs	dos
F3-AC3	PENDIENTE	test/c.exs	tres
CONTROL

salida="$(correr "$TMP/control.tsv")"

if ! echo "$salida" | grep -q "WP:           F3-02"; then
  fallar "con F3-01 en verde la tarea deberia pasar a F3-02, y salio: $salida"
fi

# --- Caso 4: una dependencia sin cumplir se salta -------------------------

cat > "$TMP/control.tsv" <<'CONTROL'
F3-AC1	PENDIENTE	test/a.exs	uno
F3-AC2	PENDIENTE	test/b.exs	dos
F3-AC3	OK	test/c.exs	tres
CONTROL

salida="$(correr "$TMP/control.tsv")"

if ! echo "$salida" | grep -q "WP:           F3-01"; then
  fallar "con F3-01 pendiente la tarea deberia ser F3-01, y salio: $salida"
fi

# --- Caso 5: todo en verde, no queda tarea --------------------------------

cat > "$TMP/control.tsv" <<'CONTROL'
F3-AC1	OK	test/a.exs	uno
F3-AC2	OK	test/b.exs	dos
F3-AC3	OK	test/c.exs	tres
CONTROL

salida="$(correr "$TMP/control.tsv")"
rc=$?

if [ $rc -eq 0 ]; then
  fallar "sin tareas deberia salir con 1, y salio con 0"
fi

if ! echo "$salida" | grep -q "No queda ninguna tarea"; then
  fallar "sin tareas deberia decirlo, y salio: $salida"
fi

# --- Caso 5b: un AC bloqueado por hardware no es trabajo del coder --------

# F3-AC3 esta BLOQUEADA (depende del hardware). El WP F3-03 que lo cierra
# esta hecho en cuanto lo que el coder puede hacer esta hecho: si no, el
# coder recibiria la misma tarea una sesion tras otra, para siempre.
cat > "$TMP/control.tsv" <<'CONTROL'
F3-AC1	OK	test/a.exs	uno
F3-AC2	OK	test/b.exs	dos
F3-AC3	BLOQUEADA	test/c.exs	tres
CONTROL

salida="$(correr "$TMP/control.tsv")"
rc=$?

if [ $rc -eq 0 ]; then
  fallar "con un AC bloqueado por hardware deberia salir con 1 (no queda trabajo del coder), y salio con 0"
fi

if ! echo "$salida" | grep -q "F3-AC3"; then
  fallar "el AC bloqueado deberia nombrarse, y salio: $salida"
fi

if ! echo "$salida" | grep -q "hardware"; then
  fallar "deberia decir que lo que falta depende del hardware, y salio: $salida"
fi

# --- Caso 5c: un WP con un AC pendiente si es trabajo del coder ------------

cat > "$TMP/control.tsv" <<'CONTROL'
F3-AC1	OK	test/a.exs	uno
F3-AC2	OK	test/b.exs	dos
F3-AC3	PENDIENTE	test/c.exs	tres
CONTROL

salida="$(correr "$TMP/control.tsv")"
rc=$?

if [ $rc -ne 0 ]; then
  fallar "con un AC pendiente deberia salir con 0 (hay trabajo), y salio con $rc"
fi

if ! echo "$salida" | grep -q "WP:           F3-03"; then
  fallar "con F3-03 pendiente la tarea deberia ser F3-03, y salio: $salida"
fi

# --- Caso 5d: un WP del plan que la nota no declara -----------------------

# Si la nota no declara un WP del plan, ese WP no lo hace nadie: se pierde
# en silencio. El script tiene que decirlo, no saltarselo.
cat > "$ENTORNO/docs/fases/F3.md" <<'NOTA'
# F3 — Provider

## Los WP de la fase

| WP | Dependencias | AC que cierra |
| --- | --- | --- |
| F3-01 | — | F3-AC1 |
| F3-02 | F3-01 | F3-AC2 |

## Los AC y donde se verifican

| # | AC | Test que lo verifica | En |
| --- | --- | --- | --- |
| F3-AC1 | El behaviour | `test/a.exs` · "uno" | F3 |
| F3-AC2 | El contrato | `test/b.exs` · "dos" | F3 |
NOTA

cat > "$TMP/control.tsv" <<'CONTROL'
F3-AC1	OK	test/a.exs	uno
F3-AC2	OK	test/b.exs	dos
CONTROL

salida="$(correr "$TMP/control.tsv")"
rc=$?

if [ $rc -eq 0 ]; then
  fallar "con un WP sin declarar deberia salir con 1, y salio con 0"
fi

if ! echo "$salida" | grep -q "F3-03"; then
  fallar "deberia nombrar el WP que la nota no declara, y salio: $salida"
fi

# --- Caso 6: una nota con una fila que no se reconoce ---------------------

cat > "$ENTORNO/docs/fases/F3.md" <<'NOTA'
# F3 — Provider

## Los WP de la fase

| WP | Dependencias | AC que cierra |
| --- | --- | --- |
| F3-01 | — | F3-AC1 |
| F3-02 | — | F3-AC1 | algo de mas |

## Los AC y donde se verifican

| # | AC | Test que lo verifica | En |
| --- | --- | --- | --- |
| F3-AC1 | El behaviour | `test/a.exs` · "uno" | F3 |
NOTA

cat > "$TMP/control.tsv" <<'CONTROL'
F3-AC1	PENDIENTE	test/a.exs	uno
CONTROL

salida="$(correr "$TMP/control.tsv")"
rc=$?

if [ $rc -eq 0 ]; then
  fallar "con una fila que no se reconoce deberia salir con 1, y salio con 0"
fi

if ! echo "$salida" | grep -qi "no se reconoc"; then
  fallar "una fila con un numero de celdas raro deberia avisar, y salio: $salida"
fi

# --- Caso 7: la fase se toma del orden del plan ---------------------------

# Con F3 cerrada en el registro, la fase siguiente es F4 (y no existe su
# nota): la tarea vuelve a ser "escribe la nota de fase", pero de F4.
cat > "$ENTORNO/docs/13-registro-de-fases.md" <<'REGISTRO'
| Fase | Inicio | Fin | Que | Desviaciones | Notas |
| --- | --- | --- | --- | --- | --- |
| **F0** | 2026-10-27 | **2026-10-28** | Verificacion | | |
| **F1** | 2026-10-28 | **2026-10-28** | Nucleo | | |
| **F3** | 2026-10-29 | **2026-10-29** | Provider | | |
| **F4** | pendiente | | | | |
REGISTRO

rm -f "$ENTORNO/docs/fases/F3.md"

salida="$(correr "")"

if ! echo "$salida" | grep -q "docs/fases/F4.md"; then
  fallar "con F3 cerrada la nota que toca deberia ser la de F4, y salio: $salida"
fi

# --- Caso 8: el JSON aguanta comillas y saltos de linea --------------------

# El consumidor de `--json` es una herramienta que lee la salida. Si un WP
# lleva comillas (y los llevan: "el comando `x`"), un JSON roto tumba la
# sesion entera. El escaping no es cosmetico.
#
# El registro se restaura: el caso anterior dejo F3 cerrada.
cat > "$ENTORNO/docs/13-registro-de-fases.md" <<'REGISTRO'
| Fase | Inicio | Fin | Que | Desviaciones | Notas |
| --- | --- | --- | --- | --- | --- |
| **F0** | 2026-10-27 | **2026-10-28** | Verificacion | | |
| **F1** | 2026-10-28 | **2026-10-28** | Nucleo | | |
| **F3** | pendiente | | | | |
REGISTRO

cat > "$ENTORNO/docs/01-plan-de-desarrollo.md" <<'PLAN'
## 4. Paquetes de trabajo (WP) por fase

**Orden recomendado para una sola persona**: F0, F1, F3.

### F3 · Provider

| WP | Contenido | Pruebas |
| --- | --- | --- |
| F3-01 | Behaviour "Provider" con `opts.require`, y "comillas" | Contrato |
| F3-02 | Con "comilla" | Contrato |
PLAN

cat > "$ENTORNO/docs/fases/F3.md" <<'NOTA'
# F3 — Provider

## Los WP de la fase

| WP | Dependencias | AC que cierra |
| --- | --- | --- |
| F3-01 | — | F3-AC1 |
| F3-02 | F3-01 | F3-AC2 |

## Los AC y donde se verifican

| # | AC | Test que lo verifica | En |
| --- | --- | --- | --- |
| F3-AC1 | El behaviour | `test/a.exs` · "uno" | F3 |
| F3-AC2 | El contrato | `test/b.exs` · "dos" | F3 |
NOTA

cat > "$TMP/control.tsv" <<'CONTROL'
F3-AC1	PENDIENTE	test/a.exs	uno
F3-AC2	PENDIENTE	test/b.exs	dos
CONTROL

salida="$(correr "$TMP/control.tsv" --json)"

if ! echo "$salida" | python3 -c "
import json, sys
json.loads(sys.stdin.read())
" 2>/dev/null; then
  fallar "la salida --json tiene que ser JSON valido, y no lo es: $salida"
fi

if ! echo "$salida" | grep -q 'Behaviour \\"Provider\\"'; then
  fallar "las comillas del contenido tienen que estar escapadas, y salio: $salida"
fi

# --- Resumen ---------------------------------------------------------------

if [ $FALLOS -ne 0 ]; then
  echo "== La autocomprobacion de next_task.sh NO pasa: $FALLOS fallo(s) =="
  exit 1
fi

echo "OK: la cola se deriva del repositorio y no de una lista escrita a mano"
exit 0
