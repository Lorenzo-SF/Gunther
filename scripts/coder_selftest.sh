#!/usr/bin/env bash
#
# Autocomprobacion de `scripts/coder.sh`.
#
# El bucle que relanza al coder tiene que saber distinguir dos situaciones:
#
#   1. La sesion **ha producido trabajo**: el repositorio ha cambiado y los
#      AC siguen en verde. El bucle sigue.
#   2. La sesion **no ha producido nada**: el modelo leyo, verifico y
#      resumio. El bucle **para**, en vez de seguir gastando.
#
# La segunda es la que importa. Es el fallo que ya pasó: con el prompt
# anterior, el Nemotron leyo el SPEC, corrio todas las comprobaciones y
# respondio con un resumen de ocho minutos, **sin escribir ni un fichero**.
# El comando salia con 0 y todo parecia bien. Un bucle que no distingue
# esa situacion se gastaria la GPU en sesiones que no producen nada.
#
# El selftest usa un **doble de `mcode`** (un script que simula lo que
# haria el runtime) y un repositorio de mentira. El `scripts/coder.sh` real
# se ejecuta: solo se sustituyen el runtime y el repositorio.
#
# Uso:
#   scripts/coder_selftest.sh
#
# Salida: 0 si el bucle se comporta, 1 si no.

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
# El doble de mcode: simula al runtime.
#
#   MCODE_MODE=trabaja   escribe un fichero y hace un commit
#   MCODE_MODE=resumen   no escribe nada (el fallo silencioso)
#   MCODE_MODE=roto      sale con codigo distinto de 0
# ---------------------------------------------------------------------

cat > "$TMP/mcode_doble.sh" <<'DOBLE'
#!/usr/bin/env bash
set -uo pipefail

# Los argumentos que le pasa el script real, por si hay que mirarlos.
echo "args: $*" > "${MCODE_LOG:-/dev/null}"

case "${MCODE_MODE:-trabaja}" in
  trabaja)
    echo '{"ok":true,"resultado":"hice un commit"}'
    ;;
  resumen)
    # El fallo silencioso: sale con 0, dice que todo esta bien, y no
    # escribe nada.
    echo '{"ok":true,"resultado":"todo verde, nada que hacer"}'
    ;;
  roto)
    echo '{"ok":false,"error":"el servidor no responde"}'
    exit 1
    ;;
esac
exit 0
DOBLE
chmod +x "$TMP/mcode_doble.sh"

# ---------------------------------------------------------------------
# El repositorio de mentira.
# ---------------------------------------------------------------------

ENTORNO="$TMP/repo"
mkdir -p "$ENTORNO/scripts" "$ENTORNO/docs/fases"

cp "$RAIZ/scripts/next_task.sh" "$ENTORNO/scripts/next_task.sh"
cp "$RAIZ/scripts/lib_nota.sh" "$ENTORNO/scripts/lib_nota.sh"
cp "$RAIZ/scripts/check_ac.sh" "$ENTORNO/scripts/check_ac.sh"
cp "$RAIZ/scripts/coder.sh" "$ENTORNO/scripts/coder.sh"

# El doble de check_ac: dice OK para todo, que es el estado tras una
# sesion que ha hecho su trabajo.
cat > "$ENTORNO/scripts/check_ac.sh" <<'DOBLE'
#!/usr/bin/env bash
set -uo pipefail
exit 0
DOBLE

cat > "$ENTORNO/docs/01-plan-de-desarrollo.md" <<'PLAN'
## 4. Paquetes de trabajo (WP) por fase

**Orden recomendado para una sola persona**: F0, F1, F3.

### F3 · Provider

| WP | Contenido | Pruebas |
| --- | --- | --- |
| F3-01 | Behaviour `Provider` | Contrato |
| F3-02 | `ContractTest` generico | Contrato |
PLAN

cat > "$ENTORNO/docs/13-registro-de-fases.md" <<'REGISTRO'
| Fase | Inicio | Fin | Que | Desviaciones | Notas |
| --- | --- | --- | --- | --- | --- |
| **F0** | 2026-10-27 | **2026-10-28** | Verificacion | | |
| **F1** | 2026-10-28 | **2026-10-28** | Nucleo | | |
| **F3** | pendiente | | | | |
REGISTRO

cat > "$ENTORNO/docs/fases/F3.md" <<'NOTA'
# F3 — Provider

## Los WP de la fase

| WP | Dependencias | AC que cierra |
| --- | --- | --- |
| F3-01 | — | F3-1 |
| F3-02 | F3-01 | F3-2 |

## Los AC y donde se verifican

| # | AC | Test que lo verifica | En |
| --- | --- | --- | --- |
| F3-1 | El behaviour | `test/a.exs` · "uno" | F3 |
| F3-2 | El contrato | `test/b.exs` · "dos" | F3 |
NOTA

# El doble de la cola: devuelve la tarea, y va cambiando segun cuantas
# veces se le pregunte, para que el bucle pueda avanzar.
cat > "$ENTORNO/scripts/next_task.sh" <<'DOBLE'
#!/usr/bin/env bash
set -uo pipefail
CONT="${GUNTHER_COLA_CONTROL:-}"
[ -n "$CONT" ] && [ -f "$CONT" ] && cat "$CONT"
exit 0
DOBLE

# El repo tiene que ser un repo git, para que la firma del repositorio
# (HEAD + arbol) se pueda calcular.
( cd "$ENTORNO" && git init -q && git config user.email "t@t" && git config user.name "t" \
  && git add -A && git commit -qm "inicio" ) || {
  echo "no se pudo preparar el repo de prueba" >&2
  exit 1
}

# ---------------------------------------------------------------------
# Correr el script real con los dobles.
# ---------------------------------------------------------------------

# Cada invocacion tiene un plazo. Un script que se cuelga **no** es un
# selftest que falla: es un selftest que no acaba nunca, y el que espera
# se queda sin saber si el codigo esta bien. Con el plazo, un bucle
# infinito sale por tiempo y el fallo se ve.
correr_coder() {
  local modo="$1"
  shift
  ( cd "$ENTORNO" && \
    MCODE="$TMP/mcode_doble.sh" \
    MCODE_MODE="$modo" \
    MCODE_LOG="$TMP/mcode-args.txt" \
    GUNTHER_MODEL="custom_provider:nemotron/prueba" \
    GUNTHER_LOG_DIR="$TMP/logs" \
    PATH="/usr/bin:/bin:$PATH" \
    timeout 120 bash scripts/coder.sh "$@" 2>&1 )
  return $?
}

# La cola: primero F3-01, luego F3-02, luego nada.
cola_con() {
  local primera="$1"
  case "$primera" in
    1)
      cat > "$TMP/cola.tsv" <<'C'
{"tarea": "F3-01", "fase": "F3", "contenido": "Behaviour", "pruebas": "Contrato", "dependencias": "—", "ac_pendientes": "F3-1", "ac_bloqueados": ""}
C
      ;;
    2)
      cat > "$TMP/cola.tsv" <<'C'
{"tarea": "F3-02", "fase": "F3", "contenido": "ContractTest", "pruebas": "Contrato", "dependencias": "F3-01", "ac_pendientes": "F3-2", "ac_bloqueados": ""}
C
      ;;
    *)
      cat > "$TMP/cola.tsv" <<'C'
{"tarea": null, "fase": "F3", "motivo": "no queda trabajo del coder en esta fase"}
C
      ;;
  esac
}

export GUNTHER_COLA_CONTROL="$TMP/cola.tsv"

# --- Caso 1: la sesion produce trabajo ------------------------------------

cola_con 1
# El modo "trabaja" no cambia el repo, asi que el script debe verlo. Para
# que el caso tenga sentido, el doble escribe un fichero antes de salir.
cat > "$TMP/mcode_doble.sh" <<'DOBLE'
#!/usr/bin/env bash
set -uo pipefail
echo "args: $*" > "${MCODE_LOG:-/dev/null}"
if [ "${MCODE_MODE:-trabaja}" = "trabaja" ]; then
  echo "un cambio" > "cambio-del-coder.txt"
  git add -A >/dev/null 2>&1
  git -c user.email=t@t -c user.name=t commit -qm "feat(F3-01): el behaviour" >/dev/null 2>&1
  echo '{"ok":true}'
elif [ "${MCODE_MODE:-trabaja}" = "resumen" ]; then
  echo '{"ok":true,"resultado":"todo verde"}'
else
  echo '{"ok":false}'
  exit 1
fi
exit 0
DOBLE
chmod +x "$TMP/mcode_doble.sh"

salida="$(correr_coder trabaja)"
rc=$?

if [ $rc -ne 0 ]; then
  fallar "con una sesion que trabaja el script deberia salir con 0, y salio con $rc: $salida"
fi

if ! echo "$salida" | grep -q "El repositorio ha cambiado"; then
  fallar "el script deberia decir que el repositorio ha cambiado, y salio: $salida"
fi

if ! echo "$salida" | grep -qi "los AC de F3 estan en verde"; then
  fallar "el script deberia comprobar los AC despues de la sesion, y salio: $salida"
fi

# El prompt se pasa tal cual: el fichero entero, sin reescribirlo.
if ! grep -q -- "--file PROMPT.md" "$TMP/mcode-args.txt"; then
  fallar "la sesion tiene que pasar PROMPT.md entero, y los argumentos fueron: $(cat "$TMP/mcode-args.txt")"
fi

if ! grep -q -- "--model custom_provider:nemotron/prueba" "$TMP/mcode-args.txt"; then
  fallar "la sesion tiene que pasar el modelo con su ruta, y los argumentos fueron: $(cat "$TMP/mcode-args.txt")"
fi

# --- Caso 2: la sesion NO produce nada (el fallo silencioso) ---------------

cola_con 1
salida="$(correr_coder resumen)"
rc=$?

if [ $rc -eq 0 ]; then
  fallar "con una sesion que no produce nada el script deberia salir con 1, y salio con 0"
fi

if ! echo "$salida" | grep -q "NO ha cambiado"; then
  fallar "el script deberia avisar de que la sesion no ha producido nada, y salio: $salida"
fi

if ! echo "$salida" | grep -q "reasoning_content"; then
  fallar "el aviso deberia decir donde mirar (reasoning_content), y salio: $salida"
fi

# --- Caso 3: el bucle para, no sigue ---------------------------------------

cola_con 1
salida="$(correr_coder resumen --bucle --max 3)"
rc=$?

if [ $rc -eq 0 ]; then
  fallar "con una sesion que no produce nada el bucle deberia salir con 1, y salio con 0"
fi

# Un solo intento: el bucle no debe reintentar en bucle cuando la sesion
# no ha producido nada (eso se gastaria la GPU sin hacer nada).
n_sesiones="$(echo "$salida" | grep -c "Sesion ")"
if [ "$n_sesiones" -ne 1 ]; then
  fallar "con una sesion fallida el bucle deberia parar tras 1 intento, y hizo $n_sesiones"
fi

# --- Caso 4: la cola agotada ----------------------------------------------

cola_con 3
salida="$(correr_coder trabaja)"
rc=$?

if [ $rc -ne 0 ]; then
  fallar "con la cola agotada el script deberia salir con 0 (no hay trabajo, no hay error), y salio con $rc: $salida"
fi

if ! echo "$salida" | grep -q "cola se ha agotado"; then
  fallar "con la cola agotada el script deberia decirlo, y salio: $salida"
fi

# --- Caso 5: el toolchain equivocado --------------------------------------

cola_con 1
# Un `elixir` de mentira en un PATH delante, que dice otra version.
mkdir -p "$TMP/fakebin"
cat > "$TMP/fakebin/elixir" <<'FAKE'
#!/usr/bin/env bash
echo "Erlang/OTP 27.3  Elixir 1.19.1-otp-27"
FAKE
chmod +x "$TMP/fakebin/elixir"

salida="$( cd "$ENTORNO" && \
  MCODE="$TMP/mcode_doble.sh" \
  MCODE_MODE="trabaja" \
  GUNTHER_SKIP_ENV=1 \
  PATH="$TMP/fakebin:/usr/bin:/bin" \
  GUNTHER_LOG_DIR="$TMP/logs" \
  timeout 120 bash scripts/coder.sh 2>&1 )"
rc=$?

if [ $rc -eq 0 ]; then
  fallar "con un toolchain que no es el oficial el script deberia salir con 1, y salio con 0"
fi

if ! echo "$salida" | grep -q "toolchain no es el oficial"; then
  fallar "el script deberia avisar del toolchain, y salio: $salida"
fi

# --- Resumen ---------------------------------------------------------------

if [ $FALLOS -ne 0 ]; then
  echo "== La autocomprobacion de coder.sh NO pasa: $FALLOS fallo(s) =="
  exit 1
fi

echo "OK: el bucle distingue el trabajo del resumen, y para cuando no hay trabajo"
exit 0
