#!/usr/bin/env bash
#
# Gunther · F2 · recogida de datos reales
# =========================================
#
# Qué trae (son los AC que NO se pueden cerrar sin hardware):
#
#   1. La salida real de `llama-server --list-devices`  (AC F2-1)
#   2. La salida de las herramientas del sistema: nvidia-smi, rocm-smi,
#      vulkaninfo, system_profiler                        (AC F2-1, convención B)
#   3. El `kv_mib` que informa `llama-server` al cargar, con TODOS los
#      números del modelo y del contexto                    (AC F2-6)
#   4. Los valores crudos del GGUF (block_count, head_count, head_count_kv,
#      key_length, value_length, ...)                       (AC F2-6)
#
# Al final imprime un bloque `===== INICIO =====` / `===== FIN =====` con
# todo lo recogido: eso es lo que hay que pegar en el chat.
#
# Uso:
#   bash gunther-f2-datos.sh [RUTA_DEL_GGUF]
#
# Variables de entorno que se pueden fijar:
#   GUNTHER_DIR   dónde clonar el repo (por defecto ~/workspace/github/zaguan/gunther)
#   LLAMA_SERVER  ruta al binario (por defecto: `command -v llama-server`)
#   CTX_SIZE      contexto a medir (por defecto 8192)
#
# NO hace daño: no toca tus modelos, no borra nada, y el servidor que arranca
# para la medida lo para él mismo. Carga el modelo en CPU (`-ngl 0`), así que
# no te toca la VRAM.

set -uo pipefail

DIR="${GUNTHER_DIR:-$HOME/workspace/github/zaguan/gunther}"
CTX_SIZE="${CTX_SIZE:-8192}"
FECHA="$(date +%Y-%m-%d)"

mkdir -p "$DIR/probes/output" 2>/dev/null || true
LOG="$DIR/probes/output/f2-datos-$FECHA.txt"
SERVER_LOG=""
: > "$LOG"

say() { printf '%s\n' "$*" | tee -a "$LOG"; }
titulo() { say ""; say "=============================================================="; say "$*"; say "=============================================================="; }

# ---------------------------------------------------------------- 0. entorno
titulo "0 · ENTORNO"

say "fecha        : $FECHA"
say "maquina      : $(uname -srm 2>/dev/null)"
say "usuario      : $(id -un)"
say "home         : $HOME"
say "directorio   : $DIR"
if [ -r /etc/os-release ]; then say "os           : $(. /etc/os-release && echo "$PRETTY_NAME")"; fi
say "cpu          : $( (grep -m1 'model name' /proc/cpuinfo 2>/dev/null || sysctl -n machdep.cpu.brand_string 2>/dev/null || echo '?') | sed 's/^.*: *//' | cut -c1-90)"
say "ram          : $(free -g 2>/dev/null | awk '/^Mem:/{print $2" GiB"}' || sysctl -n hw.memsize 2>/dev/null | awk '{printf "%.0f GiB\n", $1/1073741824}')"

# ------------------------------------------------------- 1. el repo de Gunther
titulo "1 · EL REPO DE GUNTHER"

if [ -d "$DIR/.git" ]; then
  say "ya estaba clonado: $DIR"
  ( cd "$DIR" && git log --oneline -3 ) >> "$LOG" 2>&1
  tail -3 "$LOG" | sed 's/^/    /'
else
  say "clonando en $DIR ..."
  if git clone --depth 20 git@github.com:Lorenzo-SF/Gunther.git "$DIR" >> "$LOG" 2>&1; then
    say "clonado por SSH"
  elif git clone --depth 20 https://github.com/Lorenzo-SF/Gunther.git "$DIR" >> "$LOG" 2>&1; then
    say "clonado por HTTPS"
  else
    say "NO se pudo clonar (repo privado: necesita SSH o el PAT). Se sigue igual:"
    say "    git clone git@github.com:Lorenzo-SF/Gunther.git $DIR"
  fi
fi

# ---------------------------------------------------- 2. el binario del motor
titulo "2 · EL BINARIO DEL MOTOR"

LLAMA="${LLAMA_SERVER:-}"
if [ -z "$LLAMA" ]; then
  LLAMA="$(command -v llama-server 2>/dev/null || true)"
fi
if [ -z "$LLAMA" ] || [ ! -x "$LLAMA" ]; then
  # ropero guarda los binarios en el subrepo; se busca ahi.
  for candidato in \
      "$HOME/workspace/github/lasaca/ropero/ropero.d/llama-server" \
      "$HOME/workspace/github/lasaca/ropero/bin/llama-server" \
      "$HOME/workspace/github/lasaca/ropero/llama.cpp/build/bin/llama-server" \
      "$HOME/workspace/github/lasaca/ropero/llama.cpp/llama-server" ; do
    if [ -x "$candidato" ]; then LLAMA="$candidato"; break; fi
  done
fi

if [ -n "$LLAMA" ] && [ -x "$LLAMA" ]; then
  say "llama-server : $LLAMA"
  say "version      : $("$LLAMA" --version 2>&1 | head -1)"
else
  say "NO se encuentra llama-server."
  say "    Con LLAMA_SERVER=/ruta/a/llama-server se indica a mano."
  LLAMA=""
fi

# ------------------------------------------------- 3. los devices (AC F2-1)
titulo "3 · LOS DEVICES QUE VE EL MOTOR  (AC F2-1)"

if [ -n "$LLAMA" ]; then
  say "--- \$ llama-server --list-devices ---"
  "$LLAMA" --list-devices 2>&1 | tee -a "$LOG"
  say ""

  # El probe oficial del repo, para que la salida quede en el sitio que
  # el propio repo espera (probes/output/).
  if [ -x "$DIR/probes/g10_list_devices.sh" ]; then
    say "--- el probe del repo (probes/g10_list_devices.sh) ---"
    bash "$DIR/probes/g10_list_devices.sh" "$LLAMA" 2>&1 | head -40 | tee -a "$LOG"
    say ""
  fi
else
  say "(sin binario: no se puede listar)"
fi

# ------------------------------------- 4. las herramientas del sistema (B)
titulo "4 · LAS HERRAMIENTAS DEL SISTEMA  (convención B)"

if command -v nvidia-smi >/dev/null 2>&1; then
  say "--- nvidia-smi ---"
  nvidia-smi 2>&1 | head -20 | tee -a "$LOG"
  say "--- nvidia-smi: memoria por GPU ---"
  nvidia-smi --query-gpu=index,name,uuid,memory.total,memory.free --format=csv 2>&1 | tee -a "$LOG"
  say "--- nvidia-smi: procesos ---"
  nvidia-smi --query-compute-apps=pid,used_memory --format=csv 2>&1 | tee -a "$LOG"
  say ""
fi

if command -v rocm-smi >/dev/null 2>&1; then
  say "--- rocm-smi ---"
  rocm-smi --showproductname 2>&1 | head -20 | tee -a "$LOG"
  say "--- rocm-smi: VRAM ---"
  rocm-smi --showmeminfo vram 2>&1 | head -25 | tee -a "$LOG"
  say ""
fi

if command -v amd-smi >/dev/null 2>&1; then
  say "--- amd-smi ---"
  amd-smi metric 2>&1 | head -25 | tee -a "$LOG"
  say ""
fi

if command -v vulkaninfo >/dev/null 2>&1; then
  say "--- vulkaninfo (resumen) ---"
  vulkaninfo --summary 2>&1 | head -40 | tee -a "$LOG"
  say ""
fi

if command -v system_profiler >/dev/null 2>&1; then
  say "--- system_profiler SPDisplaysDataType (macOS) ---"
  system_profiler SPDisplaysDataType 2>&1 | head -40 | tee -a "$LOG"
  say ""
fi

if [ -e /dev/dri ]; then
  say "--- /dev/dri ---"
  ls -l /dev/dri 2>&1 | tee -a "$LOG"
  say ""
fi

# --------------------------------------------------------- 5. el modelo GGUF
titulo "5 · EL MODELO PARA MEDIR LA KV  (AC F2-6)"

GGUF="${1:-}"
if [ -z "$GGUF" ]; then
  # Se buscan GGUFs en los sitios de siempre. El mas pequeno que se encuentre
  # vale: lo que se mide es la formula de la KV, no el modelo.
  for raiz in \
      "$HOME/workspace/github/lasaca/ropero/models" \
      "$HOME/.cache/ropero" \
      "$HOME/.cache/llama.cpp" \
      "$HOME/models" \
      "$HOME/workspace" ; do
    [ -d "$raiz" ] || continue
    encontrado="$(find "$raiz" -maxdepth 6 -name '*.gguf' -type f -printf '%s\t%p\n' 2>/dev/null | sort -n | head -1 | cut -f2-)"
    if [ -n "$encontrado" ]; then GGUF="$encontrado"; break; fi
  done
fi

if [ -n "$GGUF" ] && [ -f "$GGUF" ]; then
  say "gguf        : $GGUF"
  say "tamaño      : $(du -h "$GGUF" 2>/dev/null | cut -f1)"
else
  say "NO se encuentra ningun GGUF."
  say "    Pasa la ruta como argumento:"
  say "        bash gunther-f2-datos.sh /ruta/al/modelo.gguf"
  say "    (o pon GGUF=... en el entorno)"
  GGUF=""
fi

# ------------------------------------------- 6. los valores crudos del GGUF
titulo "6 · LOS VALORES DEL GGUF  (lo que lee la formula de Gunther)"

if [ -n "$GGUF" ]; then
  python3 - "$GGUF" <<'PYEOF' 2>&1 | tee -a "$LOG"
import struct, sys

path = sys.argv[1]
f = open(path, "rb")

def rd(n):
    b = f.read(n)
    if len(b) != n:
        raise EOFError("fichero truncado")
    return b

TYPES = {
    0: ("B", 1), 1: ("b", 1), 2: ("H", 2), 3: ("h", 2), 4: ("I", 4), 5: ("i", 4),
    6: ("f", 4), 7: ("?", 1), 10: ("Q", 8), 11: ("q", 8), 12: ("d", 8),
}

def read_value(t):
    if t == 8:            # string
        n = struct.unpack("<Q", rd(8))[0]
        return rd(n).decode("utf-8", "replace")
    if t == 9:            # array
        et = struct.unpack("<I", rd(4))[0]
        n = struct.unpack("<Q", rd(8))[0]
        if et == 8:
            out = []
            for _ in range(n):
                ln = struct.unpack("<Q", rd(8))[0]
                out.append(rd(ln).decode("utf-8", "replace"))
            return out
        if et in TYPES:
            fmt, size = TYPES[et]
            return [struct.unpack("<" + fmt, rd(size))[0] for _ in range(n)]
        return ["<tipo %d>" % et]
    if t in TYPES:
        fmt, size = TYPES[t]
        return struct.unpack("<" + fmt, rd(size))[0]
    raise ValueError("tipo de valor desconocido: %d" % t)

magic = rd(4)
if magic != b"GGUF":
    print("NO es un GGUF (magic=%r)" % magic)
    sys.exit(0)

version = struct.unpack("<I", rd(4))[0]
n_tensors = struct.unpack("<Q", rd(8))[0]
n_kv = struct.unpack("<Q", rd(8))[0]

print("gguf version   : %d" % version)
print("tensors        : %d" % n_tensors)
print("claves         : %d" % n_kv)
print("")

meta = {}
for _ in range(n_kv):
    n = struct.unpack("<Q", rd(8))[0]
    key = rd(n).decode("utf-8", "replace")
    t = struct.unpack("<I", rd(4))[0]
    meta[key] = read_value(t)

arch = meta.get("general.architecture", "")

INTERESA = [
    "general.architecture", "general.name",
    ".context_length", ".embedding_length", ".block_count",
    ".attention.head_count", ".attention.head_count_kv",
    ".attention.key_length", ".attention.value_length",
    ".attention.sliding_window", ".attention.kv_lora_rank",
    ".rope.dimension_count", ".rope.freq_base",
    ".ssm.state_size", ".ssm.conv_kernel",
    ".expert_count", ".expert_used_count",
    ".feed_forward_length", ".feed_forward_gate_length",
]

print("--- claves de la metadata que importan ---")
for k in sorted(meta):
    if any(k.endswith(sfx) or k == sfx for sfx in INTERESA):
        v = meta[k]
        if isinstance(v, list) and len(v) > 8:
            v = v[:8] + ["..."]
        print("%-56s = %r" % (k, v))

print("")
print("--- todas las claves (para el que quiera mirarlas) ---")
for k in sorted(meta):
    v = meta[k]
    if isinstance(v, list) and len(v) > 8:
        v = v[:8] + ["..."]
    print("%-56s = %r" % (k, v))
PYEOF
  say ""
fi

# ------------------------------- 7. lo que informa llama-server al cargar
titulo "7 · LO QUE INFORMA llama-server AL CARGAR  (AC F2-6)"

if [ -n "$LLAMA" ] && [ -n "$GGUF" ]; then
  SERVER_LOG="$DIR/probes/output/llama-server-kv-$FECHA.log"
  PORT=$(( 20000 + (RANDOM % 10000) ))

  say "arrancando: $LLAMA -m $GGUF --ctx-size $CTX_SIZE --parallel 1 -ngl 0 --port $PORT"
  say "log         : $SERVER_LOG"

  "$LLAMA" \
    -m "$GGUF" \
    --ctx-size "$CTX_SIZE" \
    --parallel 1 \
    --cache-type-k f16 \
    --cache-type-v f16 \
    -ngl 0 \
    --no-warmup \
    --host 127.0.0.1 \
    --port "$PORT" \
    --log-file "$SERVER_LOG" \
    > /dev/null 2>&1 &
  PID_SERVER=$!

  # Se espera a que la KV este reservada (o a que se agote el plazo).
  ESPERA=0
  HAYO="no"
  while [ "$ESPERA" -lt 300 ]; do
    if [ -f "$SERVER_LOG" ] && grep -q "KV buffer size" "$SERVER_LOG" 2>/dev/null; then
      HAYO="si"; break
    fi
    if ! kill -0 "$PID_SERVER" 2>/dev/null; then break; fi
    sleep 1
    ESPERA=$((ESPERA + 1))
  done

  say "espera       : ${ESPERA}s (KV encontrada: $HAYO)"

  kill "$PID_SERVER" 2>/dev/null || true
  sleep 1
  kill -9 "$PID_SERVER" 2>/dev/null || true

  if [ -f "$SERVER_LOG" ]; then
    say ""
    say "--- el modelo ---"
    grep -E "n_embd |n_embd  |n_embd=|n_layer|n_head|n_embd_head|n_embd_k_gqa|n_embd_v_gqa|n_gqa|arch  |n_ctx_train|n_swa|sw_full" "$SERVER_LOG" | head -30 | tee -a "$LOG"
    say ""
    say "--- el contexto ---"
    grep -E "n_ctx|n_seq_max|kv_unified|n_batch" "$SERVER_LOG" | head -12 | tee -a "$LOG"
    say ""
    say "--- la KV  <<<<<< ESTE ES EL DATO QUE BUSCO ---"
    grep -E "KV buffer size|kv_self_size|KV self" "$SERVER_LOG" | tee -a "$LOG"
    say ""
    say "--- tipos de la KV y de la cache ---"
    grep -E "type_k|type_v|cache_type|KV.*type" "$SERVER_LOG" | head -8 | tee -a "$LOG"
    say ""
    say "(log completo en $SERVER_LOG)"
  else
    say "no se ha podido leer el log del servidor"
  fi
else
  say "(sin binario o sin GGUF: no se mide la KV)"
fi


# ----------------------- 7b. la formula de Gunther, si se puede compilar
titulo "7b · LA FORMULA DE GUNTHER  (la mitad que si puedo calcular aqui)"

if [ -n "$SERVER_LOG" ] && [ -f "$SERVER_LOG" ] && [ -n "$GGUF" ]; then
  N_CTX_REAL="$(grep -E "n_ctx_seq +=" "$SERVER_LOG" | head -1 | sed 's/.*= *//' | tr -d ' ')"
  [ -z "$N_CTX_REAL" ] && N_CTX_REAL="$CTX_SIZE"
  say "n_ctx efectivo (el que usa el motor): $N_CTX_REAL"
  say ""

  MIX_BIN="$(command -v mix 2>/dev/null || true)"
  if [ -z "$MIX_BIN" ]; then
    for candidato in "$HOME/.asdf/shims/mix" "$HOME/.asdf/bin/mix" "/usr/local/bin/mix" "/opt/elixir/bin/mix"; do
      if [ -x "$candidato" ]; then MIX_BIN="$candidato"; break; fi
    done
  fi

  if [ -z "$MIX_BIN" ]; then
    say "no hay mix (Elixir) en esta maquina: la formula se calcula aparte."
  elif [ ! -f "$DIR/mix.exs" ]; then
    say "el repo no esta clonado en $DIR: la formula se calcula aparte."
  else
    say "compilando el repo (puede tardar la primera vez) ..."
    if ( cd "$DIR" && timeout 600 "$MIX_BIN" deps.get >/dev/null 2>&1 && timeout 600 "$MIX_BIN" compile >/dev/null 2>&1 ); then
      EXS="$(mktemp /tmp/gunther-formula-XXXXXX.exs)"
      cat > "$EXS" <<'EOF'
[gguf_path, n_ctx] = System.argv()
n_ctx = String.to_integer(n_ctx)

{:ok, gguf} = Gunther.Gguf.parse(File.read!(gguf_path))

{:ok, resultado} =
  Gunther.Resource.Weight.calculate(gguf,
    n_ctx: n_ctx,
    compute_buffer_mib: 0,
    offloaded_bytes: 0,
    type_k: :f16,
    type_v: :f16
  )

IO.puts("kv_mib  de la formula : #{resultado.kv_mib}")
IO.puts("kv_bytes de la formula: #{resultado.kv_bytes}")
IO.puts("n_layer / n_head_kv   : #{resultado.n_layer} / #{resultado.n_head_kv}")
IO.puts("key_length/value_len  : #{resultado.key_length} / #{resultado.value_length}")
IO.puts("type_k / type_v       : #{resultado.type_k} / #{resultado.type_v}")
EOF

      FORMULA="$( cd "$DIR" && timeout 300 "$MIX_BIN" run "$EXS" "$GGUF" "$N_CTX_REAL" 2>&1 | grep -v "Arrea.Telemetry" )"
      echo "$FORMULA" | tee -a "$LOG"
      say ""

      # Si la KV se reparte entre CPU y GPU, el total es la suma.
      KV_REAL="$(grep -E "KV buffer size" "$SERVER_LOG" | sed 's/.*= *//' | awk '{s+=$1} END{printf "%.2f", s}')"
      KV_FORMULA="$(echo "$FORMULA" | grep 'kv_mib  de la formula' | sed 's/.*: *//')"
      if [ -n "$KV_REAL" ] && [ -n "$KV_FORMULA" ]; then
        say "COMPARACION"
        say "  llama-server : $KV_REAL MiB"
        say "  formula      : $KV_FORMULA MiB"
        if awk "BEGIN{exit !($KV_REAL == $KV_FORMULA)}" 2>/dev/null; then
          say "  --> COINCIDEN"
        else
          say "  --> NO COINCIDEN (esta es exactamente la diferencia que hay que entender)"
        fi
      fi
    else
      say "no se pudo compilar el repo (deps o mix): la formula se calcula aparte."
    fi
  fi
  say ""
fi

# ------------------------------------------------------------- 8. resumen
titulo "8 · RESUMEN PARA PEGAR"

say "## Entorno"
say "- maquina   : $(uname -srm) / $( . /etc/os-release 2>/dev/null && echo "$PRETTY_NAME" )"
say "- gpu       : $( (command -v nvidia-smi >/dev/null 2>&1 && nvidia-smi --query-gpu=name,memory.total --format=csv,noheader 2>/dev/null | head -1) || echo 'nvidia-smi no disponible')"
say "- llama     : ${LLAMA:-<no encontrado>}"
say "- gguf      : ${GGUF:-<no encontrado>}"
say ""

say "## Devices que ve el motor"
if [ -n "$LLAMA" ]; then
  "$LLAMA" --list-devices 2>&1 | sed 's/^/    /' | tee -a "$LOG"
else
  say "    (sin binario)"
fi
say ""

say "## La KV que informa llama-server"
if [ -n "$LLAMA" ] && [ -n "$GGUF" ] && [ -n "$SERVER_LOG" ] && [ -f "$SERVER_LOG" ]; then
  grep -E "KV buffer size" "$SERVER_LOG" | sed 's/^/    /' | tee -a "$LOG"
  grep -E "n_ctx  |n_ctx_seq|n_seq_max|kv_unified" "$SERVER_LOG" | sed 's/^/    /' | tee -a "$LOG"
else
  say "    (no medido)"
fi
say ""

say "## La comparacion (si se pudo hacer)"
if [ -n "${KV_REAL:-}" ] && [ -n "${KV_FORMULA:-}" ]; then
  say "    llama-server : $KV_REAL MiB"
  say "    formula      : $KV_FORMULA MiB"
else
  say "    (no se pudo comparar en la maquina)"
fi
say ""

say "## Lo que hay que pegar"
say "1. este bloque entero,"
say "2. el log del servidor si lo quieres entero: ${SERVER_LOG:-<no se midio>}"

say ""
# El bloque que hay que pegar va con `echo` a secas: si usara `say`, la
# linea de inicio se anadiria al log y saldria duplicada.
echo "===== INICIO DEL BLOQUE ====="
cat "$LOG"
echo "===== FIN DEL BLOQUE ====="
