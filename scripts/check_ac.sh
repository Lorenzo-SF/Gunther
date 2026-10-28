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
#   scripts/check_ac.sh docs/fases/F3.md F3
#   scripts/check_ac.sh docs/fases/F3.md F3 --machine
#
# Formato de la tabla (columnas): | # | AC | test/fichero.exs · "nombre del test" | fase |
# La cuarta columna dice en que fase se verifica:
#
#   * `Fnn`    — se verifica en esa fase: se ejecuta el test.
#   * `BLOQUEADA` — no se puede verificar aqui (falta el hardware). **No es un
#     AC cumplido**: se cuenta como pendiente y la fase no se cierra.
#   * `PENDIENTE` — el trabajo no esta hecho. Tampoco es un AC cumplido.
#   * otra fase — el AC esta **diferido**: se avisa, pero no se cuenta como
#     cumplido ni como fallido.
#
# ## El modo `--machine`
#
# Imprime una linea por AC, separada por tabuladores, y **nada mas**: ni
# informe, ni resumen, ni los extractos de los fallos. Es lo que consume
# `scripts/next_task.sh`, que necesita el estado de cada AC para saber que
# tarea toca, y que no debe reimplementar la verificacion.
#
#     id <TAB> estado <TAB> ruta <TAB> nombre
#
# El estado es uno de: `OK`, `FALLA`, `PENDIENTE`, `BLOQUEADA`, `DIFERIDO`.
#
# `PENDIENTE` y `BLOQUEADA` cuentan igual en el informe (los dos son AC sin
# cumplir), pero aqui se distinguen: `BLOQUEADA` depende del hardware y no
# es trabajo del coder; `PENDIENTE` es trabajo que no esta hecho.
#
# Con `--machine` el codigo de salida es **0 siempre**: no es una puerta,
# es un informe. Quien decide si algo esta en verde es el modo normal, que
# sale con 1 si hay AC sin cumplir. Un modo que sale con 1 y otro que sale
# con 0 sobre lo mismo es un modo del que no se puede fiar: por eso son dos
# modos y no uno con dos salidas.

set -uo pipefail

FICHERO=""
FASE=""
MACHINE=0

# Los argumentos van en cualquier orden: `--machine` es una bandera y los
# otros dos son posicionales. Aceptarlos solo en un orden fijo es una
# forma de fallar en silencio (el script leeria un `--machine` como nombre
# de fichero).
for arg in "$@"; do
  case "$arg" in
    --machine) MACHINE=1 ;;
    -*) ;;
    *)
      if [ -z "$FICHERO" ]; then
        FICHERO="$arg"
      elif [ -z "$FASE" ]; then
        FASE="$arg"
      fi
      ;;
  esac
done

if [ -z "$FASE" ]; then
  FASE="$(basename "$FICHERO" .md)"
fi

RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$RAIZ" || exit 1

if [ -f /workspace/tools/env.sh ]; then
  # shellcheck disable=SC1091
  . /workspace/tools/env.sh
fi

if [ ! -f "$FICHERO" ]; then
  if [ "$MACHINE" = "1" ]; then
    exit 0
  fi
  echo "No existe el fichero de fase: $FICHERO"
  exit 1
fi

# La tabla de AC la lee **solo** este script. `next_task.sh` pide el estado
# con el modo `--machine` en vez de parsear la tabla por su cuenta: dos
# lectores de la misma tabla divergen, y el que diverge se equivoca sin
# que se note.
# shellcheck disable=SC1091
. "$(dirname "${BASH_SOURCE[0]}")/lib_nota.sh"

# Toda fila `| F<num>-` de la nota tiene que ser reconocible: una fila de
# AC (cuatro celdas) o una fila de WP (tres). Si no lo es, el script para.
# Un AC que no se ve, no se comprueba, y una fase con AC sin comprobar se
# cierra igual: eso es un OK falso.
if ! nota_validar_filas "$FICHERO"; then
  if [ "$MACHINE" = "1" ]; then
    exit 0
  fi
  echo
  echo "== La nota de fase tiene filas que no se reconocen =="
  exit 1
fi

CUMPLIDOS=0
FALLIDOS=0
DIFERIDOS=0
PENDIENTES=0
declare -a DETALLE=()

# Las filas de la tabla de AC. Se leen por el separador `|`.
while IFS= read -r linea || [ -n "$linea" ]; do
  # Solo las filas de AC: el identificador es `F<numero>-<numero>`.
  # Con un prefijo mas laxo ("F"), se colaban filas de otras tablas.
  case "$linea" in
    "| F"[0-9]"-"*) ;;
    *) continue ;;
  esac

  # | # | AC | test · "nombre" | fase |
  cuerpo="${linea#|}"
  cuerpo="${cuerpo%|}"

  # Solo las filas de la tabla de AC, que tiene **cuatro** celdas:
  # | # | AC | test · "nombre" | fase |
  #
  # La nota de fase lleva ademas la tabla de WP, que tiene **tres**:
  # | WP | Dependencias | AC que cierra |
  #
  # El discriminante es el numero de celdas, no el nombre del
  # identificador: un AC y un WP pueden llamarse igual (`F4-12`), y leer
  # una fila de WP como si fuera de AC contaria AC que no existen.
  if [ "$(nota_num_celdas "$cuerpo")" != "4" ]; then
    continue
  fi

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

  # El identificador sin espacios: en la salida `--machine` es un dato, y
  # un dato con un espacio delante se compara mal.
  id="$(echo "$_id" | sed 's/^ *//; s/ *$//')"

  if [ "$fase_ac" = "BLOQUEADA" ] || [ "$fase_ac" = "PENDIENTE" ]; then
    # Un AC bloqueado o sin trabajo hecho **no es un AC cumplido**.
    #
    # Los dos cuentan igual en el informe (los dos son AC sin cumplir), pero
    # en la salida `--machine` se distinguen, porque el que decide la cola
    # necesita saber cual de los dos es: un AC BLOQUEADA depende del
    # hardware y no es trabajo del coder; un AC PENDIENTE sí lo es.
    PENDIENTES=$((PENDIENTES + 1))
    DETALLE+=("PENDIENTE $_id ($fase_ac): $nombre")
    if [ "$MACHINE" = "1" ]; then
      printf '%s\t%s\t%s\t%s\n' "$id" "$fase_ac" "$ruta" "$nombre"
    fi
    continue
  fi

  if [ "$fase_ac" != "$FASE" ]; then
    DIFERIDOS=$((DIFERIDOS + 1))
    DETALLE+=("DIFERIDO  $_id ($fase_ac): $nombre")
    if [ "$MACHINE" = "1" ]; then
      printf '%s\tDIFERIDO\t%s\t%s\n' "$id" "$ruta" "$nombre"
    fi
    continue
  fi

  if [ ! -f "$ruta" ]; then
    FALLIDOS=$((FALLIDOS + 1))
    DETALLE+=("FALLA     $_id: no existe el fichero $ruta")
    if [ "$MACHINE" = "1" ]; then
      printf '%s\tFALLA\t%s\t%s\n' "$id" "$ruta" "$nombre"
    fi
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
    if [ "$MACHINE" = "1" ]; then
      printf '%s\tFALLA\t%s\t%s\n' "$id" "$ruta" "$nombre"
    fi
    continue
  fi

  salida="$(mix test "$ruta" 2>&1 </dev/null)"
  rc=$?

  if [ $rc -ne 0 ]; then
    FALLIDOS=$((FALLIDOS + 1))
    DETALLE+=("FALLA     $_id: el fichero de $ruta no pasa entero")
    if [ "$MACHINE" = "1" ]; then
      printf '%s\tFALLA\t%s\t%s\n' "$id" "$ruta" "$nombre"
    else
      echo "$salida" | grep -A12 -E "^\s+[0-9]+\) test" | head -20
    fi
  else
    CUMPLIDOS=$((CUMPLIDOS + 1))
    DETALLE+=("OK        $_id: $nombre")
    if [ "$MACHINE" = "1" ]; then
      printf '%s\tOK\t%s\t%s\n' "$id" "$ruta" "$nombre"
    fi
  fi
done < "$FICHERO"

# El modo `--machine` es un informe: sale con 0 y no imprime nada mas.
if [ "$MACHINE" = "1" ]; then
  exit 0
fi

echo
echo "== AC de $FASE =="
echo
for linea in "${DETALLE[@]}"; do
  echo "  $linea"
done
echo
echo "  cumplidos: $CUMPLIDOS · fallidos: $FALLIDOS · pendientes: $PENDIENTES · diferidos a otra fase: $DIFERIDOS"
echo

if [ $FALLIDOS -ne 0 ]; then
  echo "== La fase $FASE NO cumple sus AC: $FALLIDOS sin cumplir =="
  exit 1
fi

if [ $PENDIENTES -ne 0 ]; then
  echo "== La fase $FASE NO cumple sus AC: $PENDIENTES sin cumplir =="
  echo "   Un AC bloqueado o pendiente no es un AC cumplido."
  exit 1
fi

echo "== Todos los AC de $FASE que aplican a esta fase estan cumplidos =="
if [ $DIFERIDOS -ne 0 ]; then
  echo "   $DIFERIDOS AC estan diferidos a otra fase (estan escritos en la nota de fase)."
fi
