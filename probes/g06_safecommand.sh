#!/usr/bin/env bash
# G-06 · Trebejo.SafeCommand: reglas destructivas y comandos de solo lectura.
#
# La firma es `execute(cmd_name, args, opts)`: el nombre del comando y los
# argumentos van SEPARADOS. Con `execute("ls -la", [])` el nombre entero
# ("ls -la") no pasa el validador de caracteres seguros y sale
# `:unsafe_command_name`: no es que el comando sea peligroso, es que la
# firma espera el nombre solo.
#
# (a) Latencia de un comando corto con y sin las opciones de shell.
# (b) `rm -rf /` se bloquea; `nvidia-smi --query-gpu=memory.free --format=csv`
#     se permite.
set -euo pipefail
cd "$(dirname "$0")/.."

echo "== version de trebejo fijada"
grep -o '"trebejo".*' mix.lock | head -3

echo
echo "== API de Trebejo.SafeCommand"
MIX_ENV=dev mix run -e '
  IO.puts("Trebejo.SafeCommand: #{inspect(Trebejo.SafeCommand.__info__(:functions))}")
' 2>/dev/null | grep -v "Arrea.Telemetry"

echo
echo "== (a) latencia con y sin las opciones de shell"
MIX_ENV=dev mix run -e '
  {us, _} = :timer.tc(fn -> Trebejo.SafeCommand.execute("echo", ["hola"]) end)
  IO.puts("sin opciones de shell: #{us} us")
' 2>/dev/null | grep -v "Arrea.Telemetry"

echo
echo "== (b) rm -rf / debe quedar bloqueado"
MIX_ENV=dev mix run -e '
  IO.inspect(Trebejo.SafeCommand.execute("rm", ["-rf", "/"]), label: "rm -rf /")
' 2>/dev/null | grep -v "Arrea.Telemetry"

echo
echo "== (b) nvidia-smi de solo lectura debe permitirse"
MIX_ENV=dev mix run -e '
  IO.inspect(
    Trebejo.SafeCommand.execute("nvidia-smi", ["--query-gpu=memory.free", "--format=csv"]),
    label: "nvidia-smi"
  )
' 2>/dev/null | grep -v "Arrea.Telemetry"

echo
echo "== (c) el comando se ejecuta a traves de un shell que carga la config del shell"
MIX_ENV=dev mix run -e '
  {:ok, res} = Trebejo.SafeCommand.execute("echo", ["hola"])
  IO.puts("stdout: #{inspect(res.stdout)}")
' 2>/dev/null | grep -v "Arrea.Telemetry"
