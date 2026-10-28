#!/usr/bin/env bash
#
# Puerta G-10/G-11: los devices que ve el motor.
#
# Graba la salida de `llama-server --list-devices` y, si hay, la de las
# herramientas del sistema (`nvidia-smi`, `rocm-smi`, `vulkaninfo`,
# `system_profiler`), que son la **convencion B** (la del sistema).
#
# El AC de F2 pide las salidas **grabadas** de CUDA, Vulkan, ROCm y Metal.
# Eso solo se puede hacer en una maquina con esos dispositivos: este
# script es el que las recoge. Sin el binario, lo dice y no inventa nada.
#
# Uso:
#   probes/g10_list_devices.sh [RUTA_DEL_BINARIO]
#
# Salida: 0 si se ha grabado la salida del motor, 1 si no.

set -uo pipefail

RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$RAIZ" || exit 1

BINARIO="${1:-${LLAMA_SERVER:-}}"
FECHA="$(date +%Y-%m-%d)"
SALIDA="probes/output/g10-${FECHA}.txt"

if [ -z "$BINARIO" ]; then
  BINARY=$(command -v llama-server 2>/dev/null || true)
fi

{
  echo "# G-10 · devices del motor"
  echo "# fecha: ${FECHA}"
  echo "# binario: ${BINARIO:-<no encontrado>}"
  echo
} > "$SALIDA"

if [ -z "$BINARIO" ] || [ ! -x "$BINARIO" ]; then
  {
    echo "NO HAY BINARIO: no se puede grabar la salida de --list-devices."
    echo
    echo "Pasalo como argumento:"
    echo "    probes/g10_list_devices.sh /ruta/a/llama-server"
    echo
    echo "Lo que se necesita para cerrar el AC de F2:"
    echo "  - la salida de --list-devices de un equipo con CUDA"
    echo "  - la de uno con Vulkan"
    echo "  - la de uno con ROCm"
    echo "  - la de uno con Metal"
  } >> "$SALIDA"

  cat "$SALIDA"
  echo
  echo "FALLA: sin binario de llama-server no hay salida que grabar."
  exit 1
fi

{
  echo "## \$ ${BINARIO} --list-devices"
  echo '```'
} >> "$SALIDA"

"$BINARIO" --list-devices >> "$SALIDA" 2>&1
CODIGO=$?

{
  echo '```'
  echo
  echo "(codigo de salida: ${CODIGO})"
} >> "$SALIDA"

# La convencion B: la del sistema. Es otra herramienta, y el emparejamiento
# entre su identificador y el nombre del motor tiene que ser inequivoco
# (G-11).
for herramienta in nvidia-smi rocm-smi vulkaninfo system_profiler; do
  if command -v "$herramienta" >/dev/null 2>&1; then
    {
      echo "## \$ ${herramienta}"
      echo '```'
    } >> "$SALIDA"

    case "$herramienta" in
      nvidia-smi) nvidia-smi --query-gpu=index,name,memory.total,memory.free --format=csv >> "$SALIDA" 2>&1 ;;
      rocm-smi)   rocm-smi --showproductname --showmeminfo vram >> "$SALIDA" 2>&1 ;;
      *)          "$herramienta" >> "$SALIDA" 2>&1 ;;
    esac

    {
      echo '```'
      echo
    } >> "$SALIDA"
  fi
done

cat "$SALIDA"
echo
echo "OK: salida grabada en ${SALIDA}"
exit 0
