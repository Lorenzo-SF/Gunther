#!/usr/bin/env bash
#
# La siguiente tarea, deducida del estado real del repositorio.
#
# Uso:
#   scripts/next_task.sh
#   scripts/next_task.sh --json
#
# Este script es la **cola** del trabajo del coder. No hay una lista de
# tareas escrita a mano en ninguna parte: la cola sale de tres fuentes que
# ya existen y que no se pueden desincronizar entre si:
#
#   1. **Que fase toca.** El plan de desarrollo dice el orden de las fases
#      ("Orden recomendado para una sola persona") y el registro de fases
#      dice cuales estan cerradas. La primera del orden que no esta cerrada
#      es la que toca.
#
#   2. **Que WP hay en esa fase.** El plan de desarrollo, seccion 4.
#
#   3. **Que WP toca.** De los WP de esa fase, el primero cuyos AC **no
#      estan todos cumplidos**. El estado de cada AC lo dice
#      `check_ac.sh --machine`, que ejecuta los tests de verdad.
#
# El criterio de "WP terminado" es, por tanto, **ejecutable**: un WP esta
# terminado cuando sus AC pasan. No hay un "hecho" escrito a mano que se
# pueda quedar viejo.
#
# ## Por que no una lista escrita a mano
#
# Una lista de tareas escrita a mano se pudre en silencio: nadie la
# actualiza, y el modelo trabaja sobre una lista que ya no describe el
# repositorio. Aqui la lista **es** el repositorio.
#
# ## Que imprime
#
# Con `--json`, una linea con la tarea en JSON. Sin el, un informe para
# humanos. El codigo de salida es 0 si hay una tarea y 1 si no hay ninguna
# (la fase esta completa).
#
# ## Portabilidad
#
# Sin arrays asociativos: `declare -A` es de bash 4 y el bash de macOS es
# el 3.2. Los datos intermedios van a ficheros temporales.

set -uo pipefail

# La raiz del repositorio. `GUNTHER_ROOT` la cambia el selftest para correr
# **este mismo script** contra dobles: el selftest no puede tener una copia
# de la logica, porque una copia se queda vieja y el selftest acaba
# comprobando algo que no existe.
RAIZ="${GUNTHER_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
cd "$RAIZ" || exit 1

if [ -f /workspace/tools/env.sh ]; then
  # shellcheck disable=SC1091
  . /workspace/tools/env.sh
fi

JSON=0
for arg in "$@"; do
  case "$arg" in
    --json) JSON=1 ;;
  esac
done

PLAN="docs/01-plan-de-desarrollo.md"
REGISTRO="docs/13-registro-de-fases.md"

# El verificador de AC. El selftest lo sustituye por un doble.
CHECK_AC="${GUNTHER_CHECK_AC:-$(dirname "${BASH_SOURCE[0]}")/check_ac.sh}"

# shellcheck disable=SC1091
. "$(dirname "${BASH_SOURCE[0]}")/lib_nota.sh"

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

# El JSON se escapa. Un WP con comillas ("el comando `x`") rompe el JSON si
# se interpola a pelo, y el consumidor es una herramienta que lee la salida:
# un JSON roto tumba la sesion entera. Todos los `printf` de JSON pasan por
# aqui.
json_escapar() {
  local s="$1"
  s="${s//\\/\\\\}"
  s="${s//\"/\\\"}"
  s="${s//$'\t'/\\t}"
  s="${s//$'\r'/}"
  s="${s//$'\n'/\\n}"
  printf '%s' "$s"
}

# ---------------------------------------------------------------------
# 1. Que fase toca.
# ---------------------------------------------------------------------

fase_actual() {
  local orden cerradas f
  orden="$(nota_orden_fases "$PLAN")"
  [ -n "$orden" ] || return 1

  cerradas="$(nota_fases_cerradas "$REGISTRO")"

  while read -r f; do
    [ -n "$f" ] || continue
    if ! printf '%s\n' "$cerradas" | grep -qx "$f"; then
      printf '%s' "$f"
      return 0
    fi
  done <<< "$orden"

  return 1
}

FASE="$(fase_actual)"

if [ -z "$FASE" ]; then
  if [ "$JSON" = "1" ]; then
    echo '{"tarea": null, "motivo": "todas las fases del plan estan cerradas"}'
  else
    echo "No queda ninguna fase abierta en el plan."
  fi
  exit 1
fi

NOTA="docs/fases/${FASE}.md"

# ---------------------------------------------------------------------
# 2. La nota de fase es el primer trabajo: sin ella no hay AC que
#    verificar ni WP que cerrar.
# ---------------------------------------------------------------------

if [ ! -f "$NOTA" ]; then
  if [ "$JSON" = "1" ]; then
    printf '{"tarea": "nota-de-fase", "fase": "%s", "nota": "%s"}\n' "$(json_escapar "$FASE")" "$(json_escapar "$NOTA")"
  else
    echo "== La siguiente tarea =="
    echo
    echo "  Fase:  $FASE"
    echo "  WP:    (ninguno todavia)"
    echo
    echo "  Escribe la nota de fase: $NOTA"
    echo
    echo "  Todavia no existe, y sin ella no hay AC que verificar ni WP que"
    echo "  cerrar. La nota lleva:"
    echo
    echo "    - los AC de la fase (SPEC §19) con el test que cierra cada uno;"
    echo "    - los WP de la fase y los AC que cierra cada uno;"
    echo "    - las decisiones locales y lo que se difiere a otra fase."
    echo
    echo "  La plantilla esta en docs/fases/README.md."
    echo
    echo "  Cuando la nota exista, esta tabla de WP es la que este script"
    echo "  lee para saber que toca:"
    echo
    echo "    | WP | Dependencias | AC que cierra |"
    echo "    | F3-01 | — | F3-AC1, F3-AC2 |"
    echo
    echo "  Y el AC cierra con:"
    echo
    echo "    | # | AC | Test que lo verifica | En |"
    echo "    | F3-AC1 | ... | \`test/...exs\` · \"nombre del test\" | F3 |"
  fi
  exit 0
fi

# ---------------------------------------------------------------------
# 3. Los AC de la fase y su estado, ejecutado.
# ---------------------------------------------------------------------

ESTADO="$TMP/estado_ac.tsv"
bash "$CHECK_AC" "$NOTA" "$FASE" --machine > "$ESTADO"

# Una nota con filas que no se reconocen no se interpreta: se avisa y se
# sale. Un AC que no se ve, no se comprueba, y la cola decidiria sobre un
# estado inventado.
if ! nota_validar_filas "$NOTA"; then
  if [ "$JSON" = "1" ]; then
    printf '{"tarea": null, "fase": "%s", "motivo": "la nota de fase tiene filas que no se reconocen"}\n' "$(json_escapar "$FASE")"
  else
    echo
    echo "== La nota de fase $NOTA tiene filas que no se reconocen =="
    echo "   Sin la nota bien escrita no se puede saber que tarea toca."
  fi
  exit 1
fi

estado_de_ac() {
  cut -f1,2 "$ESTADO" | grep "^$1	" | head -1 | cut -f2
}

nombre_de_ac() {
  cut -f1,4 "$ESTADO" | grep "^$1	" | head -1 | cut -f2
}

ruta_de_ac() {
  cut -f1,3 "$ESTADO" | grep "^$1	" | head -1 | cut -f2
}

# Los WP de la fase: del plan el contenido, de la nota los AC que cierra.
WPS="$TMP/wps.tsv"
nota_wps_del_plan "$PLAN" "$FASE" > "$WPS"

# La tabla de WP de la nota, en un fichero aparte para poder consultarla
# por WP sin arrays.
WP_NOTA="$TMP/wp_nota.tsv"
nota_filas_wp "$NOTA" > "$WP_NOTA"

acs_de_wp() {
  cut -f1,3 "$WP_NOTA" | grep "^$1	" | head -1 | cut -f2
}

deps_de_wp() {
  cut -f1,2 "$WP_NOTA" | grep "^$1	" | head -1 | cut -f2
}

contenido_de_wp() {
  cut -f1,2 "$WPS" | grep "^$1	" | head -1 | cut -f2
}

pruebas_de_wp() {
  cut -f1,3 "$WPS" | grep "^$1	" | head -1 | cut -f2
}

# ---------------------------------------------------------------------
# 4. El primer WP sin terminar.
# ---------------------------------------------------------------------

# Un WP esta **hecho** cuando todos sus AC estan en OK, o estan BLOQUEADA.
#
# La diferencia importa: un AC BLOQUEADA depende del hardware y no es
# trabajo del coder. Si se contara como pendiente, el WP que lo cierra no
# terminaria nunca, y el coder recibiria la misma tarea una sesion tras
# otra. Un AC PENDIENTE, en cambio, si es trabajo suyo.
wp_hecho() {
  local wp="$1"
  local acs ac estado

  acs="$(acs_de_wp "$wp")"
  [ -n "$acs" ] || return 1

  for ac in $(printf '%s' "$acs" | tr ',' ' '); do
    ac="$(nota_trim "$ac")"
    [ -n "$ac" ] || continue
    estado="$(estado_de_ac "$ac")"
    case "$estado" in
      OK|BLOQUEADA) ;;
      *) return 1 ;;
    esac
  done

  return 0
}

# Un WP cuyas dependencias siguen sin terminar no se puede empezar: se
# salta, pero se dice por que.
wp_bloqueado_por() {
  local wp="$1"
  local dep acs

  for dep in $(printf '%s' "$(deps_de_wp "$wp")" | tr ',' ' '); do
    dep="$(nota_trim "$dep")"
    [ -n "$dep" ] || continue
    case "$dep" in
      -|*"—"*) continue ;;
    esac
    acs="$(acs_de_wp "$dep")"
    [ -n "$acs" ] || continue
    if ! wp_hecho "$dep"; then
      printf '%s' "$dep"
      return 0
    fi
  done

  return 1
}

# La nota de fase tiene que cubrir **todos** los WP del plan. Si no, hay un
# WP que nadie tiene asignado, y se pierde en silencio: el coder nunca lo
# hara y la fase no se podra cerrar. Es un error de la nota, no algo que se
# salte.
faltan_wp=""
while IFS=$'\t' read -r wp _ _; do
  [ -n "$wp" ] || continue
  if [ -z "$(acs_de_wp "$wp")" ]; then
    faltan_wp="$faltan_wp $wp"
  fi
done < "$WPS"

if [ -n "$faltan_wp" ]; then
  if [ "$JSON" = "1" ]; then
    printf '{"tarea": null, "fase": "%s", "motivo": "la nota de fase no declara estos WP: %s"}\n' \
      "$(json_escapar "$FASE")" "$(json_escapar "$(nota_trim "$faltan_wp")")"
  else
    echo
    echo "== La nota de fase $NOTA no declara estos WP de la fase: =="
    echo "  $(nota_trim "$faltan_wp")"
    echo
    echo "   Cada WP del plan tiene que decir que AC cierra. Sin eso, el WP"
    echo "   no lo hace nadie y la fase no se puede cerrar."
  fi
  exit 1
fi

SIGUIENTE=""
BLOQUEADO_POR=""

# El orden de verdad es el del plan: se recorren los WP en el orden en que
# el plan los lista.
while IFS=$'\t' read -r wp _ _; do
  [ -n "$wp" ] || continue
  [ -n "$(acs_de_wp "$wp")" ] || continue

  if wp_hecho "$wp"; then
    continue
  fi

  bloqueado="$(wp_bloqueado_por "$wp")"
  if [ -n "$bloqueado" ]; then
    if [ -z "$SIGUIENTE" ]; then
      BLOQUEADO_POR="$bloqueado"
      SIGUIENTE="$wp"
    fi
    continue
  fi

  SIGUIENTE="$wp"
  BLOQUEADO_POR=""
  break
done < "$WPS"

if [ -z "$SIGUIENTE" ]; then
  # Todos los WP estan hechos: los que solo tienen AC en OK, y los que solo
  # tienen AC bloqueados por hardware. Lo que queda no es trabajo del coder.
  if [ "$JSON" = "1" ]; then
    printf '{"tarea": null, "fase": "%s", "motivo": "no queda trabajo del coder en esta fase"}\n' "$(json_escapar "$FASE")"
  else
    echo "== No queda ninguna tarea en $FASE =="
    echo
    echo "  Todos los WP de la fase estan hechos, o su lo que falta depende"
    echo "  del hardware."
    echo
    bloqueados="$(awk -F'\t' '$2 == "BLOQUEADA" {printf " %s", $1}' "$ESTADO")"
    otros="$(awk -F'\t' '$2 != "OK" && $2 != "BLOQUEADA" {printf " %s", $1}' "$ESTADO")"
    if [ -n "$bloqueados" ]; then
      echo "  Los AC bloqueados por hardware (no son trabajo del coder) son:$bloqueados"
    fi
    if [ -n "$otros" ]; then
      echo "  Los AC que no estan en OK y no estan bloqueados son:$otros"
    fi
    if [ -n "$bloqueados" ]; then
      echo
      echo "  La fase se cierra con la firma del dueno, y con el probe que"
      echo "  recoge las salidas reales."
    fi
  fi
  exit 1
fi

# ---------------------------------------------------------------------
# 5. La tarea.
# ---------------------------------------------------------------------

AC_PENDIENTES=""
AC_BLOQUEADOS=""
for ac in $(printf '%s' "$(acs_de_wp "$SIGUIENTE")" | tr ',' ' '); do
  ac="$(nota_trim "$ac")"
  [ -n "$ac" ] || continue
  case "$(estado_de_ac "$ac")" in
    OK) ;;
    BLOQUEADA) AC_BLOQUEADOS="$AC_BLOQUEADOS $ac" ;;
    *) AC_PENDIENTES="$AC_PENDIENTES $ac" ;;
  esac
done

if [ "$JSON" = "1" ]; then
  printf '{"tarea": "%s", "fase": "%s", "contenido": "%s", "pruebas": "%s", "dependencias": "%s", "ac_pendientes": "%s", "ac_bloqueados": "%s"}\n' \
    "$(json_escapar "$SIGUIENTE")" \
    "$(json_escapar "$FASE")" \
    "$(json_escapar "$(contenido_de_wp "$SIGUIENTE")")" \
    "$(json_escapar "$(pruebas_de_wp "$SIGUIENTE")")" \
    "$(json_escapar "$(deps_de_wp "$SIGUIENTE")")" \
    "$(json_escapar "$(nota_trim "$AC_PENDIENTES")")" \
    "$(json_escapar "$(nota_trim "$AC_BLOQUEADOS")")"
  exit 0
fi

echo "== La siguiente tarea =="
echo
echo "  Fase:         $FASE"
echo "  WP:           $SIGUIENTE"
echo
echo "  Que hay que hacer:"
echo "    $(contenido_de_wp "$SIGUIENTE")"
echo
echo "  Pruebas minimas:"
echo "    $(pruebas_de_wp "$SIGUIENTE")"
echo
if [ -n "$(deps_de_wp "$SIGUIENTE")" ] && [ "$(deps_de_wp "$SIGUIENTE")" != "-" ]; then
  echo "  Depende de:   $(deps_de_wp "$SIGUIENTE")"
  if [ -n "$BLOQUEADO_POR" ]; then
    echo "               (bloqueado: $BLOQUEADO_POR todavia no esta en verde)"
  fi
  echo
fi
echo "  AC que faltan:"
for ac in $AC_PENDIENTES; do
  echo "    $ac  $(nombre_de_ac "$ac")"
  echo "        $(ruta_de_ac "$ac")"
done
if [ -n "$AC_BLOQUEADOS" ]; then
  echo
  echo "  AC bloqueados por hardware (no son trabajo tuyo, pero el WP no"
  echo "  se puede dar por cerrado sin ellos):"
  for ac in $AC_BLOQUEADOS; do
    echo "    $ac  $(nombre_de_ac "$ac")"
  done
fi
echo
echo "  Termina cuando:"
echo "    - el test de cada AC de arriba existe y su fichero pasa entero;"
echo "    - mix check.all esta en verde;"
echo "    - hay un commit con el prefijo del WP."
echo
echo "  Para el estado de los AC:"
echo "    bash scripts/check_ac.sh $NOTA $FASE"
