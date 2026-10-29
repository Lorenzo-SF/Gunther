#!/usr/bin/env bash
#
# La sesión del coder, y el bucle que la repite.
#
# Uso:
#   scripts/coder.sh                       # una sesión: un WP
#   scripts/coder.sh --bucle               # sesiones hasta que la cola se agote
#   scripts/coder.sh --bucle --max 5       # hasta cinco sesiones
#
# El prompt **no cambia** entre sesiones: es `PROMPT.md`, y no se toca. Lo que
# cambia es la tarea, y la tarea sale del repositorio (`scripts/next_task.sh`).
#
# ## Por que esto puede existir
#
# Porque el criterio de fin es **ejecutable**. Antes no lo era: el prompt
# decia "cuando termines, hay un fichero nuevo o un commit", pero nada
# comprobaba si eso habia pasado. Ahora `next_task.sh` dice cual es la
# siguiente tarea y, cuando la cola se agota, dice que no queda ninguna: el
# bucle puede decidir sin preguntar.
#
# ## Lo que este script NO hace
#
# - No mergea nada. El merge es del dueno.
# - No cierra fases. La firma es del dueno.
# - No decide que un AC esta cumplido: lo dice `check_ac.sh`, que ejecuta
#   los tests.
# - No reescribe el prompt. El prompt es un fichero estable.
#
# ## El fallo que este script sabe detectar
#
# El Nemotron con el prompt anterior leyo el SPEC, corrio todas las
# comprobaciones y respondio con un resumen de ocho minutos. **Cero ficheros
# escritos.** Ese fallo es silencioso: el comando sale con 0 y parece que
# todo fue bien.
#
# Aqui se detecta: antes y despues de cada sesion se mira si el repositorio
# ha cambiado (un commit o ficheros nuevos). Si no ha cambiado, la sesion no
# ha producido nada, y el bucle **para** en vez de seguir gastando.
#
# ## Requisitos
#
# - El toolchain oficial: Erlang 28.5.0.7 y Elixir 1.19.5-otp-28.
# - `mcode` en el PATH, con el provider configurado (ver
#   `docs/16-nemotron-coder.md`).
# - El repo con la puerta en verde: `mix check.all`.
#
# Variables de entorno:
#   GUNTHER_MODEL   el id completo, `custom_provider:<id>/<model-id>`
#                   (por defecto: `custom_provider:nemotron/nemotron`)
#   MCODE           el binario (por defecto: `mcode`)

set -uo pipefail

RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$RAIZ" || exit 1

if [ -f /workspace/tools/env.sh ] && [ "${GUNTHER_SKIP_ENV:-}" != "1" ]; then
  # shellcheck disable=SC1091
  . /workspace/tools/env.sh
fi

BUCLE=0
MAX=0
while [ $# -gt 0 ]; do
  case "$1" in
    --bucle) BUCLE=1; shift ;;
    --max) MAX="${2:-0}"; shift 2 ;;
    --help|-h)
      sed -n '2,30p' "${BASH_SOURCE[0]}" | sed 's/^# \?//'
      exit 0
      ;;
    *)
      echo "Opcion desconocida: $1" >&2
      exit 2
      ;;
  esac
done

MODEL="${GUNTHER_MODEL:-custom_provider:nemotron/nemotron}"
MCODE="${MCODE:-mcode}"

# Los logs de las sesiones van **fuera del repositorio**. Dentro se
# colarian en los commits: el log de una sesion es una captura del trabajo
# del modelo, no parte del repo, y el repo es publico.
LOG_DIR="${GUNTHER_LOG_DIR:-${TMPDIR:-/tmp}/gunther-coder}"
mkdir -p "$LOG_DIR"

# ---------------------------------------------------------------------
# 1. La puerta, antes de empezar.
# ---------------------------------------------------------------------

echo "== La sesion del coder =="
echo

if ! command -v "$MCODE" >/dev/null 2>&1; then
  echo "!! No encuentro '$MCODE' en el PATH."
  echo "   Este script relanza al coder con el runtime que tengas"
  echo "   instalado. Sin el, no hay sesion que relanzar."
  exit 1
fi

if ! command -v elixir >/dev/null 2>&1; then
  echo "!! No encuentro el toolchain (elixir)."
  exit 1
fi

VERSION="$(elixir --version 2>&1)"
# `elixir --version` imprime Erlang en la primera linea y Elixir en la
# segunda. Mirar solo la primera hace que el check no vea nunca la version
# que quiere comprobar.
case "$VERSION" in
  *"Elixir 1.19.5"*) ;;
  *)
    echo "!! El toolchain no es el oficial:"
    echo "$VERSION" | sed 's/^/   /'
    echo "   Tiene que ser Elixir 1.19.5-otp-28 (Erlang 28.5.0.7). Sin el,"
    echo "   lo que el coder verifique no vale, y no se pierde tiempo en un"
    echo "   run inútil."
    exit 1
    ;;
esac

echo "  toolchain: $VERSION"
echo "  modelo:    $MODEL"
echo

# ---------------------------------------------------------------------
# 2. Una sesion.
# ---------------------------------------------------------------------

# La foto del repositorio antes de la sesion: lo que hay que mirar
# despues para saber si la sesion ha producido algo.
firma_repo() {
  local head
  head="$(git rev-parse HEAD 2>/dev/null)"
  local arbol
  arbol="$(git write-tree 2>/dev/null)"
  printf '%s %s' "$head" "$arbol"
}

# La cola, en JSON. Es la fuente de verdad de la tarea.
cola_json() {
  bash scripts/next_task.sh --json 2>/dev/null
}

# El id del WP que toca, o vacío si no queda nada.
tarea_actual() {
  local json
  json="$(cola_json)"
  printf '%s' "$json" | sed -n 's/.*"tarea": "\([^"]*\)".*/\1/p' | head -1
}

# Hay tarea si el JSON trae un "tarea" con contenido.
hay_tarea() {
  local json
  json="$(cola_json)"
  case "$json" in
    *'"tarea": null'*) return 1 ;;
    *'"tarea": "'*) return 0 ;;
  esac
  return 1
}

sesion() {
  local num="$1"
  local antes despues log json tarea

  json="$(cola_json)"

  if ! hay_tarea; then
    echo "  No queda ninguna tarea: la cola se ha agotado."
    return 2
  fi

  tarea="$(printf '%s' "$json" | sed -n 's/.*"tarea": "\([^"]*\)".*/\1/p' | head -1)"

  antes="$(firma_repo)"

  log="$LOG_DIR/sesion-$(date +%Y%m%d-%H%M%S)-$num-$tarea.json"

  echo "  Sesion $num: $tarea"
  echo "  Registro: $log"
  echo

  # El prompt es el de siempre. La tarea la lee el modelo del repositorio.
  "$MCODE" exec \
    --file PROMPT.md \
    --model "$MODEL" \
    --cwd "$RAIZ" \
    --permission full \
    --output-format json \
    "Ejecuta bash scripts/next_task.sh y haz exactamente lo que dice." \
    > "$log" 2>&1
  local rc=$?

  despues="$(firma_repo)"

  echo
  echo "  mcode sale con $rc"

  # ---- El fallo silencioso: la sesion no ha producido nada. ----
  if [ "$antes" = "$despues" ]; then
    echo "  !! El repositorio NO ha cambiado. La sesion no ha producido nada."
    echo "     Esto es el fallo silencioso: el modelo leyo, verifico y"
    echo "     resumio, y no escribio ni un fichero."
    echo "     La salida esta en: $log"
    echo "     Mira 'reasoning_content' (no esta en el contenido) y el cwd."
    return 1
  fi

  # ---- Ha producido algo: ahora, que la puerta siga en verde. ----
  echo "  El repositorio ha cambiado. Comprobando la puerta..."
  if ! bash scripts/check_ac.sh "$NOTA_FASE" "$FASE_ACTUAL" > "$LOG_DIR/ac-$num.txt" 2>&1; then
    echo "  !! Los AC de $FASE_ACTUAL no estan todos en verde."
    echo "     El detalle esta en: $LOG_DIR/ac-$num.txt"
    echo "     Puede que la sesion este a medias. Revisa antes de seguir."
    return 1
  fi

  echo "  Los AC de $FASE_ACTUAL estan en verde."
  echo
  return 0
}

# ---------------------------------------------------------------------
# 3. El bucle.
# ---------------------------------------------------------------------

# La fase y su nota, para el check de AC.
FASE_ACTUAL="$(bash scripts/next_task.sh --json 2>/dev/null | sed -n 's/.*"fase": "\([^"]*\)".*/\1/p' | head -1)"
NOTA_FASE="docs/fases/${FASE_ACTUAL}.md"

NUM=0
while : ; do
  NUM=$((NUM + 1))

  if [ "$MAX" -gt 0 ] && [ "$NUM" -gt "$MAX" ]; then
    echo "== Se ha llegado al maximo de $MAX sesiones =="
    break
  fi

  sesion "$NUM"
  rc=$?

  if [ $rc -eq 2 ]; then
    echo "== La cola se ha agotado: la fase esta hecha =="
    echo "   Ahora le toca al dueno: mirar la CI y firmarla."
    exit 0
  fi

  if [ $rc -ne 0 ]; then
    echo "== La sesion $NUM no ha terminado bien. El bucle para aqui. =="
    exit 1
  fi

  if [ "$BUCLE" -ne 1 ]; then
    echo "== Una sesion hecha. Para seguir: scripts/coder.sh --bucle =="
    exit 0
  fi
done

exit 0
