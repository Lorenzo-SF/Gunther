#!/usr/bin/env bash
#
# Los AC de una fase, ejecutados (SPEC §19, D-10).
#
# Un AC esta cerrado cuando **un test lo verifica**. Este script lee la
# tabla de AC de la nota de fase (`docs/fases/Fnn.md`) y ejecuta cada test.
# Si un test no existe, o falla, el AC no esta cumplido y la fase no se
# cierra.
#
# Uso:
#   scripts/check_ac.sh docs/fases/F1.md
#
# Formato de la tabla (columnas): | # | AC | test/fichero.exs · "nombre del test" | fase |
# La cuarta columna dice en que fase se verifica: si no es la fase que se
# esta cerrando, el AC esta **diferido** y se avisa, pero no se cuenta como
# cumplido ni como fallido: se cuenta como diferido, y el script lo dice.

set -uo pipefail

FICHERO="${1:-}"
RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$RAIZ" || exit 1

if [ -f /workspace/tools/env.sh ]; then
  # shellcheck disable=SC1091
  . /workspace/tools/env.sh
fi

if [ ! -f "$FICHERO" ]; then
  echo "No existe el fichero de fase: $FICHERO"
  exit 1
fi

FASE="${2:-$(basename "$FICHERO" .md)}"

CUMPLIDOS=0
FALLIDOS=0
DIFERIDOS=0
declare -a DETALLE=()

# Las filas de la tabla de AC. Se leen por el separador `|`.
while IFS= read -r linea; do
  case "$linea" in
    "| F"*) ;;
    *) continue ;;
  esac

  # | # | AC | test · "nombre" | fase |
  cuerpo="${linea#|}"
  cuerpo="${cuerpo%|}"
  IFS='|' read -r _id _ac _test _fase <<< "$cuerpo"

  # El test viene como  ruta · "nombre"
  test_="${_test##*·}"
  test_="$(echo "$test_" | sed 's/^ *//; s/ *$//')"
  ruta="${_test%%·*}"
  # El markdown usa comillas invertidas: se quitan.
  ruta="$(echo "$ruta" | sed 's/^ *//; s/ *$//; s/^`//; s/`$//')"
  nombre="${test_#*\"}"
  nombre="${nombre%\"*}"
  fase_ac="$(echo "$_fase" | sed 's/^ *//; s/ *$//')"

  if [ -z "$nombre" ] || [ -z "$ruta" ]; then
    continue
  fi

  if [ "$fase_ac" != "$FASE" ]; then
    DIFERIDOS=$((DIFERIDOS + 1))
    DETALLE+=("DIFERIDO  $_id ($fase_ac): $nombre")
    continue
  fi

  if [ ! -f "$ruta" ]; then
    FALLIDOS=$((FALLIDOS + 1))
    DETALLE+=("FALLA     $_id: no existe el fichero $ruta")
    continue
  fi

  # `</dev/null` es necesario: `mix test` lee stdin y se comeria el resto
  # del fichero de fase, que es justo la entrada del bucle.
  # El AC se cumple si **el test existe** con ese nombre y **el fichero
  # entero pasa**. Se ejecuta el fichero entero y no solo ese test: es mas
  # estricto, y esquiva el detalle de que `--only` compara con el nombre
  # completo (describe incluido) y no con el nombre del test.
  # Un AC puede estar cubierto por un `property` (ExUnitProperties) y no
  # por un `test`: los dos son verificacion por ejecucion.
  if ! grep -qF "test \"$nombre\"" "$ruta" && ! grep -qF "property \"$nombre\"" "$ruta"; then
    FALLIDOS=$((FALLIDOS + 1))
    DETALLE+=("FALLA     $_id: no hay ningun test \"$nombre\" en $ruta")
    continue
  fi

  salida="$(mix test "$ruta" 2>&1 </dev/null)"
  rc=$?

  if [ $rc -ne 0 ]; then
    FALLIDOS=$((FALLIDOS + 1))
    DETALLE+=("FALLA     $_id: el fichero de $ruta no pasa entero")
    echo "$salida" | grep -A12 -E "^\s+[0-9]+\) test" | head -20
  else
    CUMPLIDOS=$((CUMPLIDOS + 1))
    DETALLE+=("OK        $_id: $nombre")
  fi
done < "$FICHERO"

echo
echo "== AC de $FASE =="
echo
for linea in "${DETALLE[@]}"; do
  echo "  $linea"
done
echo
echo "  cumplidos: $CUMPLIDOS · fallidos: $FALLIDOS · diferidos a otra fase: $DIFERIDOS"
echo

if [ $FALLIDOS -ne 0 ]; then
  echo "== La fase $FASE NO cumple sus AC: $FALLIDOS sin cumplir =="
  exit 1
fi

echo "== Todos los AC de $FASE que aplican a esta fase estan cumplidos =="
if [ $DIFERIDOS -ne 0 ]; then
  echo "   $DIFERIDOS AC estan diferidos a otra fase (estan escritos en la nota de fase)."
fi
