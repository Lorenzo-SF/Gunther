#!/usr/bin/env bash
#
# Gunther · F3 · `Provider.LlamaCpp` contra un llama-server REAL
# ==============================================================
#
# Qué trae (el AC que NO se puede cerrar sin hardware):
#
#   AC F3-14 — `Provider.LlamaCpp` en modo `external` contra un
#   `llama-server` que ya está corriendo.
#
# El modo `external` es el que **no gestiona** el engine: Gunther no lo
# arranca, no lo para y no lo recarga. Solo le habla por HTTP. Este probe
# arranca un `llama-server` real, le hace las tres peticiones que el
# provider de referencia hace (`/v1/chat/completions`, `/v1/models` y
# `/v1/completions`), y recoge lo que responde.
#
# Al final imprime un bloque `===== INICIO =====` / `===== FIN =====` con
# todo lo recogido: eso es lo que hay que pegar en el chat, junto con la
# salida del test.
#
# Uso:
#   bash probes/f3_llama_cpp.sh [RUTA_DEL_GGUF]
#
# Variables de entorno que se pueden fijar:
#   GUNTHER_DIR   dónde clonar el repo (por defecto: el repositorio actual)
#   LLAMA_SERVER  ruta al binario (por defecto: `command -v llama-server`)
#   PORT          puerto del servidor (por defecto 18081)
#   CTX_SIZE      contexto a pedir (por defecto 4096)
#   API_KEY       clave que espera el servidor (por defecto: ninguna)
#
# NO hace daño: no toca tus modelos, no borra nada, y el servidor que
# arranca para la medida lo para él mismo. Carga el modelo en CPU
# (`-ngl 0`), así que no te toca la VRAM.

set -uo pipefail

DIR="${GUNTHER_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
PORT="${PORT:-18081}"
CTX_SIZE="${CTX_SIZE:-4096}"
API_KEY="${API_KEY:-}"
GGUF="${1:-}"
FECHA="$(date +%Y-%m-%d)"

mkdir -p "$DIR/probes/output" 2>/dev/null || true
LOG="$DIR/probes/output/f3-llama-cpp-$FECHA.txt"
SERVER_LOG="$DIR/probes/output/f3-llama-cpp-server-$FECHA.log"

# El log de la corrida **se crea cuando la carrera empieza de verdad**. Un
# fichero de salida de una corrida que no midio nada no es evidencia: es
# ruido que parece una medicion. Aqui solo se deja un marcador en el
# terminal.
: > "$SERVER_LOG"

SERVER_PID=""

say() { printf '%s\n' "$*"; }

# A partir de aqui, la salida va tambien al fichero.
say_log() { printf '%s\n' "$*" | tee -a "$LOG"; }

titulo() { say ""; say "=============================================================="; say "$*"; say "=============================================================="; }

# ---------------------------------------------------------------- 0. entorno
titulo "0 · ENTORNO"

say "fecha        : $FECHA"
say "maquina      : $(uname -srm 2>/dev/null)"
say "usuario      : $(id -un)"
say "directorio   : $DIR"
say "puerto       : $PORT"
say "contexto     : $CTX_SIZE"

if [ -r /etc/os-release ]; then
  say "os           : $(. /etc/os-release && echo "$PRETTY_NAME")"
fi

LLAMA_SERVER_BIN="${LLAMA_SERVER:-$(command -v llama-server 2>/dev/null)}"

if [ -z "$LLAMA_SERVER_BIN" ] || [ ! -x "$LLAMA_SERVER_BIN" ]; then
  say ""
  say "!! No hay llama-server. Este probe necesita el motor."
  say "   Instalalo, o fija LLAMA_SERVER con la ruta al binario."
  say ""
  say "No se deja ninguna salida en probes/output/: una corrida que no midio"
  say "nada no es evidencia."
  exit 1
fi

say "llama-server : $LLAMA_SERVER_BIN"
say "version      : $("$LLAMA_SERVER_BIN" --version 2>&1 | head -1)"

if [ -z "$GGUF" ]; then
  say ""
  say "!! Sin GGUF no se puede arrancar el servidor."
  say "   Uso: bash probes/f3_llama_cpp.sh /ruta/al/modelo.gguf"
  say ""
  say "No se deja ninguna salida en probes/output/: una corrida que no midio"
  say "nada no es evidencia."
  exit 1
fi

if [ ! -f "$GGUF" ]; then
  say ""
  say "!! El GGUF no existe: $GGUF"
  say ""
  say "No se deja ninguna salida en probes/output/: una corrida que no midio"
  say "nada no es evidencia."
  exit 1
fi

# A partir de aqui la corrida es real: la salida va al fichero.
say() { say_log "$@"; }

say "gguf         : $GGUF"
say "tamano       : $(du -h "$GGUF" 2>/dev/null | cut -f1)"

# --------------------------------------------------- 1. arrancar el servidor
titulo "1 · EL SERVIDOR EN MODO EXTERNAL"

# El modo `external` de Gunther **no gestiona** el engine. Este probe lo
# arranca a mano, justamente para que el provider no lo haga: lo que se
# comprueba es que Gunther habla con un servidor que ya existe.
say "Se arranca el servidor a mano: el modo external no lo gestiona."

SERVER_ARGS=(--host 127.0.0.1 --port "$PORT" -ngl 0 -c "$CTX_SIZE" --no-webui)
if [ -n "$API_KEY" ]; then
  SERVER_ARGS+=(--api-key "$API_KEY")
fi

"$LLAMA_SERVER_BIN" "${SERVER_ARGS[@]}" --model "$GGUF" > "$SERVER_LOG" 2>&1 &
SERVER_PID=$!

say "pid          : $SERVER_PID"
say "log          : $SERVER_LOG"

limpiar() {
  if [ -n "$SERVER_PID" ] && kill -0 "$SERVER_PID" 2>/dev/null; then
    kill "$SERVER_PID" 2>/dev/null
    wait "$SERVER_PID" 2>/dev/null
  fi
}
trap limpiar EXIT

# ------------------------------------------------------------ 2. esperar
titulo "2 · ESPERAR A QUE RESPONDA"

BASE="http://127.0.0.1:$PORT"
LISTO=0
for i in $(seq 1 120); do
  if curl -fsS "$BASE/health" >/dev/null 2>&1; then
    LISTO=1
    say "El servidor respondio tras $i s."
    break
  fi
  if ! kill -0 "$SERVER_PID" 2>/dev/null; then
    say "El servidor murio. Log:"
    tail -30 "$SERVER_LOG" | tee -a "$LOG"
    say ""
    say "===== INICIO ====="
    say "el servidor no arranco"
    say "===== FIN ====="
    exit 1
  fi
  sleep 1
done

if [ "$LISTO" -ne 1 ]; then
  say "El servidor no respondio en 120 s. Log:"
  tail -30 "$SERVER_LOG" | tee -a "$LOG"
  say ""
  say "===== INICIO ====="
  say "el servidor no respondio"
  say "===== FIN ====="
  exit 1
fi

# ------------------------------------------------------ 3. las peticiones
titulo "3 · LAS PETICIONES QUE HACE EL PROVIDER"

# Los mismos cuatro puntos que el provider de referencia: el listado de
# modelos, un chat con contenido, un chat con formato estructurado y una
# completion. Lo que se busca no es que la respuesta sea bonita: es que
# el provider de Gunther **entiende** la respuesta real del motor.

peticion() {
  local titulo="$1" url="$2" cuerpo="$3"
  say ""
  say "--- $titulo"
  say "url: $url"
  if [ -n "$cuerpo" ]; then
    say "cuerpo:"
    printf '%s\n' "$cuerpo" | tee -a "$LOG"
  fi
  say "respuesta:"
  if [ -n "$API_KEY" ]; then
    curl -fsS -X POST "$url" \
      -H "Content-Type: application/json" \
      -H "Authorization: Bearer $API_KEY" \
      -d "$cuerpo" 2>&1 | tee -a "$LOG"
  else
    curl -fsS -X POST "$url" \
      -H "Content-Type: application/json" \
      -d "$cuerpo" 2>&1 | tee -a "$LOG"
  fi
}

say ""
say "--- GET /v1/models"
curl -fsS "$BASE/v1/models" 2>&1 | tee -a "$LOG"

peticion "POST /v1/chat/completions (texto)" \
  "$BASE/v1/chat/completions" \
  '{"messages":[{"role":"user","content":"Di exactamente: hola"}],"max_tokens":32,"temperature":0}'

peticion "POST /v1/chat/completions (salida estructurada)" \
  "$BASE/v1/chat/completions" \
  '{"messages":[{"role":"user","content":"Devuelve un objeto JSON con la clave \"ciudad\" y el valor \"Madrid\""}],"max_tokens":64,"temperature":0,"response_format":{"type":"json_object"}}'

peticion "POST /v1/completions" \
  "$BASE/v1/completions" \
  '{"prompt":"Di exactamente: hola","max_tokens":32,"temperature":0}'

# ------------------------------------------------------------ 4. resumen
titulo "4 · LO QUE HACE GUNTHER CON ESTO"

say "La prueba de aceptacion de F3-14 es que el provider de Gunther, en"
say "modo external, habla con ESTE servidor. Para verlo:"
say ""
say "  1. Con el servidor arrancado como lo de arriba (sin pararlo),"
say "  2. arranca Gunther contra el, con el provider LlamaCpp en external:"
say ""
say "       el provider se registra con la URL http://127.0.0.1:$PORT"
say ""
say "  3. y se ejecuta el test de F3-9 con la URL real."
say ""
say "El test que hay que ejecutar es:"
say ""
say "  test/gunther/core/provider/llama_cpp_test.exs"
say ""
say "y lo que se pega en la nota de fase es la salida de ese test JUNTO"
say "con lo de este probe."

# ------------------------------------------------------------ 5. salida
titulo "5 · LO RECOGIDO"

say ""
say "===== INICIO ====="
say ""
say "fecha        : $FECHA"
say "llama-server : $("$LLAMA_SERVER_BIN" --version 2>&1 | head -1)"
say "gguf         : $GGUF"
say "puerto       : $PORT"
say "contexto     : $CTX_SIZE"
say ""
say "--- salida del servidor (ultimas lineas)"
tail -20 "$SERVER_LOG"
say ""
say "===== FIN ====="
say ""
say "Pega este bloque en el chat, junto con la salida del test de F3-9."
