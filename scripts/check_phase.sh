#!/usr/bin/env bash
#
# El cierre de una fase (SPEC §19, D-10, principio 2 del plan de desarrollo).
#
# Una fase **no** se da por cerrada porque el codigo compile y los tests
# passen. Se da por cerrada cuando las nueve comprobaciones de este script
# estan en verde. El script es la definition ejecutable del "estado optimo":
# lo que el script no comprueba, no se puede afirmar.
#
# Uso:
#   scripts/check_phase.sh F1
#
# Salida: 0 si la fase puede cerrarse, 1 si no. Cada comprobacion dice su
# resultado; el motivo del fallo esta en la salida, no en un "OK" generico.

set -uo pipefail

FASE="${1:-}"
RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$RAIZ" || exit 1

# . /workspace/tools/env.sh pone el toolchain en el PATH.
if [ -f /workspace/tools/env.sh ]; then
  # shellcheck disable=SC1091
  . /workspace/tools/env.sh
fi

FALLOS=0
AVISO=""

# Las comprobaciones que se han hecho, con su resultado.
declare -a RESULTADOS=()

comprobar() {
  local nombre="$1"
  shift
  local salida
  salida="$("$@" 2>&1)"
  local rc=$?

  if [ $rc -eq 0 ]; then
    RESULTADOS+=("OK    $nombre")
  else
    RESULTADOS+=("FALLA $nombre")
    FALLOS=$((FALLOS + 1))
    AVISO="${AVISO}${salida}"$'\n\n'
  fi
}

# Comprobaciones que no son un comando: se evaluan con un predicado.
comprobar_predicado() {
  local nombre="$1"
  local predicado="$2"
  shift 2

  if eval "$predicado"; then
    RESULTADOS+=("OK    $nombre")
  else
    RESULTADOS+=("FALLA $nombre")
    FALLOS=$((FALLOS + 1))
  fi
}

echo "== Cierre de la fase ${FASE:-?} =="
echo

# ---------------------------------------------------------------
# 1. La suite completa pasa, y **el resumen se ve**.
# ---------------------------------------------------------------
# El detalle importa: un `mix test` cuyo formateador revienta (por ejemplo,
# un assert sobre 100.000 caracteres) termina con codigo 1 pero **sin
# imprimir el resumen**. Un script que solo mirase el codigo de salida
# distinguiria ese caso; uno que exige el resumen con "0 failures" no.
comprobar_predicado "la suite completa pasa (0 fallos, con el resumen visible)" \
  'out=$(mix test 2>&1); rc=$?; [ $rc -eq 0 ] && echo "$out" | grep -qE "[0-9]+ tests?, 0 failures"'

# ---------------------------------------------------------------
# 2. No hay fallos intermitentes.
# ---------------------------------------------------------------
# Un test que falla una vez de cada diez es un fallo inesperado, y el
# criterio de la fase es cero fallos inesperados. Tres corridas seguidas.
comprobar_predicado "no hay tests intermitentes (3 corridas seguidas)" \
  'for i in 1 2 3; do out=$(mix test 2>&1) || return 1; echo "$out" | grep -qE "[0-9]+ tests?, 0 failures" || return 1; done'

# ---------------------------------------------------------------
# 3. Credo sin avisos, de NINGUNA prioridad.
# ---------------------------------------------------------------
# Contar los avisos filtrados por prioridad se traga los de prioridad baja:
# es lo que dejo la CI en rojo durante quince runs. Aqui se cuenta todo.
comprobar_predicado "credo sin avisos (de ninguna prioridad)" \
  'n=$(mix credo --format=oneline 2>&1 | grep -cE "^\["); [ "$n" -eq 0 ]'

# ---------------------------------------------------------------
# 4. Dialyzer sin errores.
# ---------------------------------------------------------------
comprobar "dialyzer sin errores" mix dialyzer

# ---------------------------------------------------------------
# 5. Compilacion sin warnings, con los warnings como errores.
# ---------------------------------------------------------------
comprobar_predicado "compila sin warnings" \
  'out=$(mix compile --force --warnings-as-errors 2>&1); [ $? -eq 0 ] && ! echo "$out" | grep -q "warning:"'

# ---------------------------------------------------------------
# 6. Las puertas de la CI: fronteras del nucleo y lint de documento.
# ---------------------------------------------------------------
comprobar "fronteras del nucleo respetadas" bash scripts/check_boundaries.sh
comprobar "lint de documento" bash scripts/doc_lint.sh

# ---------------------------------------------------------------
# 7. El paquete se construye y no lleva ficheros de desarrollo.
# ---------------------------------------------------------------
comprobar_predicado "el paquete se construye y esta limpio" \
  'rm -rf build gunther-*.tar && mix hex.build --unpack -o build >/dev/null 2>&1 && for f in probes _build deps .github erl_crash.dump credo-debug-log.html; do [ -e "build/$f" ] && return 1; done; rm -rf build gunther-*.tar'

# ---------------------------------------------------------------
# 8. No se ha cambiado nada de lo especificado.
# ---------------------------------------------------------------
# El SPEC manda (principio 3 del plan). Hay dos formas de que el SPEC
# cambie, y solo una es legitima:
#
#   a) No cambia: el codigo no se ha desviado de lo especificado.
#   b) Cambia **con una revision nueva** (rN+1) que tenga su tabla de
#      cambios en el Anexo D, aprobada por el dueno.
#
# Un cambio del SPEC sin revision nueva es una desviacion silenciosa: el
# codigo hace algo que el documento no dice, y nadie se entera.
comprobar_predicado "el SPEC no ha cambiado sin revision nueva" \
  'spec_vigente=$(ls SPEC-000-GUNTHER_r*.md 2>/dev/null | sort -V | tail -1);
   [ -n "$spec_vigente" ] || return 1;
   if git diff --quiet origin/main -- "$spec_vigente" 2>/dev/null; then
     # No ha cambiado: nada que revisar.
     exit 0;
   fi;
   # Ha cambiado: tiene que existir una revision mas nueva que la de main,
   # y su Anexo D tiene que tener la tabla de cambios.
   spec_main=$(git show origin/main:"$(git ls-tree --name-only origin/main | grep -E "^SPEC-000-GUNTHER_r[0-9]+\\.md$" | sort -V | tail -1)" 2>/dev/null | head -1);
   [ -n "$spec_main" ] || return 1;
   [ "$spec_vigente" != "$spec_main" ] || return 1;
   grep -qE "Cambios de r[0-9]+ a r[0-9]+" "$spec_vigente" || return 1;
   grep -q "Anexo D" "$spec_vigente" || return 1'

# ---------------------------------------------------------------
# 9. El registro de fases tiene la fase con sus AC.
# ---------------------------------------------------------------
comprobar_predicado "el registro de fases declara la fase" \
  "grep -qE '^\\| \\*\\*${FASE}\\*\\*' docs/13-registro-de-fases.md"

# ---------------------------------------------------------------
echo
for linea in "${RESULTADOS[@]}"; do
  echo "  $linea"
done
echo

if [ $FALLOS -ne 0 ]; then
  echo "== La fase ${FASE} NO se puede cerrar: $FALLOS comprobacion(es) en rojo =="
  if [ -n "$AVISO" ]; then
    echo
    echo "---- detalle ----"
    echo "$AVISO"
  fi
  exit 1
fi

echo "== La fase ${FASE} cumple las comprobaciones del cierre =="
echo "   Queda registrar la fase en docs/13-registro-de-fases.md y abrir el PR."
