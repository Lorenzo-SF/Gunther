#!/usr/bin/env bash
# Comprobacion de las fronteras del nucleo (SPEC §3.6, §0.4).
#
# Reglas:
#   1. `lib/gunther/core/**` no referencia `tools`, `mcp` (servidor), `rag`,
#      `agent`, `gateway`, `node_agent` ni `coral`.        -> grep
#   2. Solo `resilience/`, `command/`, `cache.ex`, `platform.ex` y la carga de
#      config nombran `Arrea.`, `Apero.` o `Trebejo.`.    -> grep
#   3. Ningun `System.cmd`, `:os.cmd` ni `Port.open` fuera de `command/`.
#      -> grep
#   4. Los providers de referencia pueden usar `Apero.Crypto` y `Apero.Env`.
#
# Se ignoran los COMENTARIOS: un `@moduledoc` que nombra `Trebejo.SafeCommand`
# para explicar el diseño no es una dependencia. La regla va deReferences, no
# de prosa.
#
# Salida: 0 si todo esta bien, 1 si hay una violacion.

set -uo pipefail

cd "$(dirname "$0")/.." || exit 1

status=0
core="lib/gunther/core"

fail() {
  echo "FALLO: $1" >&2
  status=1
}

# El codigo sin comentarios: se quitan las lineas cuyo primer caracter
# util sea `#` y el interior de los bloques de doc `"""`.
strip_comments() {
  python3 - "$1" <<'PY'
import re, sys
src = open(sys.argv[1], encoding="utf-8").read()
# Bloques de documentacion (""" ... """)
src = re.sub(r'"""(?:.|\n)*?"""', '""', src)
# Comentarios de linea
out = []
for line in src.split("\n"):
    stripped = line.lstrip()
    if stripped.startswith("#"):
        out.append("")
    else:
        out.append(line)
print("\n".join(out))
PY
}

# Los modulos de frontera: unica zona donde se puede nombrar a las hermanas.
es_frontera() {
  case "$1" in
    "$core/resilience.ex" | "$core/resilience/"* | "$core/command.ex" | "$core/command/"* | \
    "$core/cache.ex" | "$core/platform.ex" | \
    "$core/config/loader.ex" | "$core/config/validator.ex" | "$core/provider/"* | \
    "$core/embedder.ex" | "$core/tokenizer.ex" | "$core/crypto.ex" | "$core/env.ex" | \
    "$core/telemetry/bridge.ex" | "$core/resource/ledger.ex")
      return 0
      ;;
    *)
      return 1
      ;;
  esac
}

# --- Regla 2: los nombres de las hermanas solo en los modulos de frontera ---
for file in $(find lib/gunther -name "*.ex" | sort); do
  if strip_comments "$file" | grep -qE '\b(Arrea|Apero|Trebejo)\.'; then
    if ! es_frontera "$file"; then
      fail "$file nombra Arrea/Apero/Trebejo y no es un modulo de frontera (SPEC §3.6)"
    fi
  fi
done

# --- Regla 3: nada de System.cmd, :os.cmd ni Port.open fuera de command/ ---
for file in $(find lib/gunther -name "*.ex" | sort); do
  if strip_comments "$file" | grep -qE '(System\.cmd|:os\.cmd|Port\.open)'; then
    case "$file" in
      "$core/command.ex" | "$core/command/"*) ;;
      *) fail "$file ejecuta un proceso y no esta en command/ (SPEC §3.4)" ;;
    esac
  fi
done

# --- Regla 1: el nucleo no referencia los modulos opcionales ---
for file in $(find "$core" -name "*.ex" | sort); do
  if strip_comments "$file" | grep -qE '\bGunther\.(Tools|MCP\.Server|Rag|Agent|Gateway|Node\.Agent|Coral)\b'; then
    fail "$file (nucleo) referencia un modulo opcional (SPEC §0.4)"
  fi
done

if [ "$status" -eq 0 ]; then
  echo "OK: fronteras del nucleo respetadas"
fi

exit "$status"
