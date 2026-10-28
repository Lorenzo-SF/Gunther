#!/usr/bin/env bash
#
# El cierre de una fase (SPEC §19, D-10, principio 2 del plan de desarrollo).
#
# Una fase **no** se da por cerrada porque el codigo compile y los tests
# passen. Se da por cerrada cuando las diez comprobaciones de este script
# estan en verde. El script es la definition ejecutable del "estado optimo":
# lo que el script no comprueba, no se puede afirmar.
#
# Uso:
#   scripts/check_phase.sh F1
#
# Salida: 0 si la fase puede cerrarse, 1 si no. Cada comprobacion dice su
# resultado; el motivo del fallo esta en la salida, no en un "OK" generico.
#
# Cada comprobacion es una FUNCION, no un predicado en una cadena. La
# diferencia no es de estilo: un `return` o un `exit` dentro de un `eval`
# dentro de una funcion aborta la funcion que lo contiene, y el resultado de
# esa comprobacion se pierde. Una comprobacion que falla desapareciendo del
# informe es peor que no tenerla: el script sale con 0 y con el informe a
# medias, y eso se lee como un verde. Las funciones de abajo devuelven su
# codigo de salida y nada mas.
#
# `scripts/check_phase_selftest.sh` comprueba este mismo script con dobles:
# que un fallo se registre como FALLA y que el script salga con 1.

set -uo pipefail

FASE="${1:-}"
RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$RAIZ" || exit 1

# . /workspace/tools/env.sh pone el toolchain en el PATH.
if [ -f /workspace/tools/env.sh ]; then
  # shellcheck disable=SC1091
  . /workspace/tools/env.sh
fi

# Modo autocomprobacion: las comprobaciones no se ejecutan de verdad, la
# funcion que las hace es sustituida por un doble. Lo usa
# `scripts/check_phase_selftest.sh`.
SELFTEST="${GUNTHER_PHASE_SELFTEST:-}"

FALLOS=0
AVISO=""

# Las comprobaciones que se han hecho, con su resultado.
declare -a RESULTADOS=()

# El doble de una comprobacion en modo autocomprobacion.
#
#   GUNTHER_PHASE_SELFTEST_FAIL  nombres de las comprobaciones que fallan,
#                                 separados por "|". Vacio = todas pasan.
#                                 El valor "__todas__" = todas fallan.
selftest_double() {
  local fallan="${GUNTHER_PHASE_SELFTEST_FAIL:-}"
  if [ -z "$fallan" ]; then
    return 0
  fi
  if [ "$fallan" = "__todas__" ]; then
    echo "fallo simulado de: $1"
    return 1
  fi
  case "|${fallan}|" in
    *"|$1|"*)
      echo "fallo simulado de: $1"
      return 1
      ;;
  esac
  return 0
}

comprobar() {
  local nombre="$1"
  shift
  local salida
  local rc

  if [ -n "$SELFTEST" ]; then
    salida="$(selftest_double "$nombre" 2>&1)"
    rc=$?
  else
    salida="$("$@" 2>&1)"
    rc=$?
  fi

  if [ $rc -eq 0 ]; then
    RESULTADOS+=("OK    $nombre")
  else
    RESULTADOS+=("FALLA $nombre")
    FALLOS=$((FALLOS + 1))
    AVISO="${AVISO}${salida}"$'\n\n'
  fi
}

# ---------------------------------------------------------------
# 1. La suite completa pasa, y **el resumen se ve**.
# ---------------------------------------------------------------
# El detalle importa: un `mix test` cuyo formateador revienta (por ejemplo,
# un assert sobre 100.000 caracteres) termina con codigo 1 pero **sin
# imprimir el resumen**. Un script que solo mirase el codigo de salida
# distinguiria ese caso; uno que exige el resumen con "0 failures" no.
comp_suite() {
  local out rc
  out=$(mix test 2>&1)
  rc=$?
  if [ $rc -ne 0 ]; then
    echo "mix test devolvio $rc"
    echo "$out" | tail -30
    return 1
  fi
  if ! echo "$out" | grep -qE "[0-9]+ tests?, 0 failures"; then
    echo "la salida de mix test no tiene el resumen con 0 fallos"
    echo "$out" | tail -30
    return 1
  fi
  return 0
}

# ---------------------------------------------------------------
# 2. No hay fallos intermitentes.
# ---------------------------------------------------------------
# Un test que falla una vez de cada diez es un fallo inesperado, y el
# criterio de la fase es cero fallos inesperados. Tres corridas seguidas.
comp_suite_estable() {
  local i out
  for i in 1 2 3; do
    out=$(mix test 2>&1)
    if [ $? -ne 0 ]; then
      echo "la corrida $i de mix test fallo"
      echo "$out" | tail -30
      return 1
    fi
    if ! echo "$out" | grep -qE "[0-9]+ tests?, 0 failures"; then
      echo "la corrida $i de mix test no imprime el resumen"
      return 1
    fi
  done
  return 0
}

# ---------------------------------------------------------------
# 3. Credo sin avisos, de NINGUNA prioridad.
# ---------------------------------------------------------------
# Contar los avisos filtrados por prioridad se traga los de prioridad baja:
# es lo que dejo la CI en rojo durante quince runs. Aqui se cuenta todo.
comp_credo() {
  local n
  # El `--strict` va **junto** con `--format=oneline`: sin el primero se
  # cuentan solo los avisos de la configuracion por defecto, y sin el
  # segundo las lineas no empiezan por `[` y el recuento sale 0 siempre
  # (un check que no puede fallar no es un check).
  n=$(mix credo --strict --format=oneline 2>&1 | grep -cE "^\[")
  if [ "$n" -ne 0 ]; then
    echo "$n aviso(s) de Credo"
    mix credo --strict --format=oneline 2>&1 | grep -E "^\[" | head -20
    return 1
  fi
  return 0
}

# ---------------------------------------------------------------
# 4. Dialyzer sin errores.
# ---------------------------------------------------------------
# (usado como `comprobar ... mix dialyzer`)

# ---------------------------------------------------------------
# 5. Compilacion sin warnings, con los warnings como errores.
# ---------------------------------------------------------------
comp_compila() {
  local out rc
  out=$(mix compile --force --warnings-as-errors 2>&1)
  rc=$?
  if [ $rc -ne 0 ]; then
    echo "$out" | tail -30
    return 1
  fi
  if echo "$out" | grep -q "warning:"; then
    echo "$out" | tail -30
    return 1
  fi
  return 0
}

# ---------------------------------------------------------------
# 6. Las puertas de la CI: fronteras del nucleo y lint de documento.
# ---------------------------------------------------------------
# (usadas como `comprobar ... bash scripts/check_boundaries.sh` y
#  `comprobar ... bash scripts/doc_lint.sh`)

# ---------------------------------------------------------------
# 7. El paquete se construye y no lleva ficheros de desarrollo.
# ---------------------------------------------------------------
comp_paquete() {
  local f
  rm -rf build gunther-*.tar
  if ! mix hex.build --unpack -o build >/dev/null 2>&1; then
    echo "mix hex.build fallo"
    rm -rf build gunther-*.tar
    return 1
  fi
  for f in probes _build deps .github erl_crash.dump credo-debug-log.html; do
    if [ -e "build/$f" ]; then
      echo "el paquete lleva $f, y no deberia"
      rm -rf build gunther-*.tar
      return 1
    fi
  done
  rm -rf build gunther-*.tar
  return 0
}

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
comp_spec() {
  local spec_vigente spec_main
  spec_vigente=$(ls SPEC-000-GUNTHER_r*.md 2>/dev/null | sort -V | tail -1)
  if [ -z "$spec_vigente" ]; then
    echo "no hay ningun SPEC-000-GUNTHER_rN.md en el repositorio"
    return 1
  fi

  if git diff --quiet origin/main -- "$spec_vigente" 2>/dev/null; then
    # No ha cambiado: nada que revisar.
    return 0
  fi

  # Ha cambiado: tiene que existir una revision mas nueva que la de main,
  # y su Anexo D tiene que tener la tabla de cambios.
  spec_main=$(git show "origin/main:$(git ls-tree --name-only origin/main | grep -E '^SPEC-000-GUNTHER_r[0-9]+\.md$' | sort -V | tail -1)" 2>/dev/null | head -1)
  if [ -z "$spec_main" ]; then
    echo "no hay SPEC en origin/main"
    return 1
  fi
  if [ "$spec_vigente" = "$spec_main" ]; then
    echo "el SPEC ha cambiado respecto a origin/main sin revision nueva"
    return 1
  fi
  if ! grep -qE "Cambios de r[0-9]+ a r[0-9]+" "$spec_vigente"; then
    echo "el Anexo D del SPEC no tiene la tabla de cambios"
    return 1
  fi
  if ! grep -q "Anexo D" "$spec_vigente"; then
    echo "el SPEC no tiene Anexo D"
    return 1
  fi
  return 0
}

# ---------------------------------------------------------------
# 9. El registro de fases tiene la fase con sus AC.
# ---------------------------------------------------------------
comp_registro() {
  if ! grep -qE "^\| \*\*${FASE}\*\*" docs/13-registro-de-fases.md; then
    echo "el registro de fases no declara la fase ${FASE}"
    return 1
  fi
  return 0
}

# Un doctest que no se ejecuta es un doctest muerto: parece documentacion
# verificada y no lo es. Este modulo del nucleo tiene doctests declarados
# en `test/gunther/doctests_test.exs`, y todo modulo de `lib/` con un
# `iex>` tiene que estar ahi. Si se anade un doctest y no se declara, la
# comprobacion falla.
comp_doctests() {
  local declarados
  declarados=$(grep -oE "^  doctest [A-Za-z0-9_.]+" test/gunther/doctests_test.exs | awk '{print $2}' | sort -u)

  local modulos
  modulos=$(for fichero in $(find lib -name "*.ex"); do
    if grep -q "iex>" "$fichero"; then
      grep -m1 -oE "^defmodule [A-Za-z0-9_.]+" "$fichero" | awk '{print $2}'
    fi
  done | sort -u)

  local faltan
  faltan=$(comm -23 <(echo "$modulos") <(echo "$declarados"))

  if [ -n "$faltan" ]; then
    echo "modulos con doctests sin declarar en test/gunther/doctests_test.exs:"
    echo "$faltan"
    return 1
  fi
  return 0
}

# ---------------------------------------------------------------
# 10. La nota de fase es coherente y la cola se puede derivar.
# ---------------------------------------------------------------
# La nota de fase es lo que convierte "la fase F3" en "el WP F3-04". Si sus
# filas no se reconocen, `next_task.sh` no sabe que hacer. Y si la cola no
# sale, el coder se queda sin tarea: eso es un trabajo parado.
comp_cola() {
  local out rc
  out=$(bash scripts/next_task.sh --json 2>&1)
  rc=$?

  # 0 = hay una tarea; 1 = la fase esta completa. Los dos son validos.
  # Cualquier otro codigo, o una salida que no se puede leer, no lo son.
  if [ $rc -ne 0 ] && [ $rc -ne 1 ]; then
    echo "next_task.sh salio con $rc"
    echo "$out" | tail -20
    return 1
  fi

  if ! echo "$out" | grep -q '"tarea"'; then
    echo "next_task.sh no devolvio una tarea legible"
    echo "$out" | tail -20
    return 1
  fi
  return 0
}

# ---------------------------------------------------------------
echo
echo "== Cierre de la fase ${FASE:-?} =="
echo

comprobar "la suite completa pasa (0 fallos, con el resumen visible)" comp_suite
comprobar "no hay tests intermitentes (3 corridas seguidas)" comp_suite_estable
comprobar "credo sin avisos (de ninguna prioridad)" comp_credo
comprobar "dialyzer sin errores" mix dialyzer
comprobar "compila sin warnings" comp_compila
comprobar "fronteras del nucleo respetadas" bash scripts/check_boundaries.sh
comprobar "lint de documento" bash scripts/doc_lint.sh
comprobar "el paquete se construye y esta limpio" comp_paquete
comprobar "el SPEC no ha cambiado sin revision nueva" comp_spec
comprobar "el registro de fases declara la fase" comp_registro
comprobar "todo doctest del nucleo se ejecuta" comp_doctests
comprobar "la cola de trabajo se puede derivar del repositorio" comp_cola

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
