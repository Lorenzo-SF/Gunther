#!/usr/bin/env bash
#
# Autocomprobacion de `scripts/check_phase.sh`.
#
# Un checker con OK falso es peor que no tener checker. El modo de fallo de
# este repo lo es: durante el cierre de F1, tres comprobaciones usaban
# `return 1` (y una `exit 0`) dentro de un `eval`, lo que abortaba la
# funcion que las contenia. El efecto era que **una comprobacion que
# fallaba desaparecia del informe** en vez de marcarse FALLA, y el script
# salia con 0: un verde falso con el informe a medias.
#
# Este script comprueba el checker con dobles, sin correr la suite:
#
#   1. Todas las comprobaciones en verde  -> salida 0, un "OK" por
#      comprobacion y un "cumple las comprobaciones del cierre".
#   2. Una comprobacion en rojo           -> salida 1, esa comprobacion
#      aparece marcada como FALLA, las demas siguen apareciendo como OK, y
#      el motivo del fallo se imprime.
#
# El numero de comprobaciones se deriva de la salida: no se escribe aqui,
# para que anadir una comprobacion al checker no rompa esta
# autocomprobacion.
#
# El segundo caso es el que importa: si un fallo vuelve a desaparecer del
# informe, este script falla.
#
# Uso:
#   scripts/check_phase_selftest.sh
#
# Salida: 0 si el checker se comporta, 1 si no.

set -uo pipefail

RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$RAIZ" || exit 1

FALLOS=0

fallar() {
  echo "FALLO: $1" >&2
  FALLOS=$((FALLOS + 1))
}

# --- Caso 1: todo en verde -------------------------------------------------
salida_ok=$(GUNTHER_PHASE_SELFTEST=1 bash scripts/check_phase.sh F1 2>&1)
rc_ok=$?

if [ $rc_ok -ne 0 ]; then
  fallar "con todas las comprobaciones en verde el script deberia salir con 0, y salio con $rc_ok"
fi

n_ok=$(echo "$salida_ok" | grep -cE "^  OK ")

# El numero de comprobaciones se **deriva** de la salida, no se escribe
# aqui: si se anade una comprobacion al checker, este script no se rompe
# (la misma verdad en dos sitios siempre diverge).
n_total=$n_ok
if [ "$n_total" -lt 1 ]; then
  fallar "la salida en verde no tiene ninguna comprobacion"
fi

n_falla=$(echo "$salida_ok" | grep -cE "^  FALLA ")
if [ "$n_falla" -ne 0 ]; then
  fallar "no deberia haber comprobaciones en rojo, y hay $n_falla"
fi

if ! echo "$salida_ok" | grep -q "cumple las comprobaciones del cierre"; then
  fallar "falta la linea final que dice que la fase se puede cerrar"
fi

# --- Caso 2: una comprobacion en rojo --------------------------------------
# Se elige "credo sin avisos (de ninguna prioridad)" porque su nombre es
# largo y no aparece como substring de otro.
ROJA="credo sin avisos (de ninguna prioridad)"

salida_falla=$(GUNTHER_PHASE_SELFTEST=1 GUNTHER_PHASE_SELFTEST_FAIL="__todas__" bash scripts/check_phase.sh F1 2>&1)
rc_falla=$?

# En este caso TODAS fallan salvo la elegida, asi que hay que comprobar el
# caso de "una sola falla" aparte, con el doble de las demas en verde.
salida_una=$(GUNTHER_PHASE_SELFTEST=1 GUNTHER_PHASE_SELFTEST_FAIL="$ROJA" bash scripts/check_phase.sh F1 2>&1)
rc_una=$?

if [ $rc_falla -eq 0 ]; then
  fallar "con todas las comprobaciones en rojo el script deberia salir con 1, y salio con 0"
fi

n_falla_todas=$(echo "$salida_falla" | grep -cE "^  FALLA ")
if [ "$n_falla_todas" -ne "$n_total" ]; then
  fallar "con todas las comprobaciones en rojo deberian ser $n_total, y son $n_falla_todas"
fi

if [ $rc_una -eq 0 ]; then
  fallar "con una comprobacion en rojo el script deberia salir con 1, y salio con 0"
fi

if ! echo "$salida_una" | grep -qF "  FALLA $ROJA"; then
  fallar "la comprobacion en rojo no aparece marcada como FALLA en el informe"
fi

n_ok_una=$(echo "$salida_una" | grep -cE "^  OK ")
if [ "$n_ok_una" -ne $((n_total - 1)) ]; then
  fallar "con una comprobacion en rojo deberian quedar $((n_total - 1)) en verde, y quedan $n_ok_una"
fi

n_falla_una=$(echo "$salida_una" | grep -cE "^  FALLA ")
if [ "$n_falla_una" -ne 1 ]; then
  fallar "con una comprobacion en rojo deberia haber exactamente 1 en rojo, y hay $n_falla_una"
fi

if ! echo "$salida_una" | grep -q "fallo simulado de"; then
  fallar "el motivo del fallo no se imprime"
fi

if ! echo "$salida_una" | grep -q "NO se puede cerrar"; then
  fallar "falta el aviso de que la fase no se puede cerrar"
fi

# --- Caso 3: el informe se imprime entero ----------------------------------
# El fallo original hacia que el script terminara con exit 0 y **sin
# imprimir el informe**. Con el doble en verde, el informe tiene que
# tener una linea por comprobacion.
if [ "$(echo "$salida_ok" | grep -cE "^  (OK|FALLA) ")" -ne "$n_total" ]; then
  fallar "el informe no tiene las $n_total lineas de resultado"
fi

# --- Resumen ---------------------------------------------------------------
if [ $FALLOS -ne 0 ]; then
  echo "== La autocomprobacion de check_phase.sh NO pasa: $FALLOS fallo(s) =="
  exit 1
fi

echo "OK: el checker de fases registra sus comprobaciones y falla cuando debe"
exit 0
