#!/usr/bin/env bash
# G-21 · Apero.Llm: ¿existe un modulo de LLM en `apero`?
#
# La puerta evalua el solapamiento entre `Apero.Llm` y el contrato de
# proveedor de Gunther (§3.4). Se listan los modulos que publica el paquete
# instalado, leyendo el `.app` de la aplicacion ya cargada: es lo que se ve
# desde fuera, sin leer el codigo.
set -euo pipefail
cd "$(dirname "$0")/.."

echo "== version de apero fijada"
grep -o '"apero".*' mix.lock | head -3

echo
echo "== modulos que publica la aplicacion apero"
MIX_ENV=dev mix run -e '
  IO.puts("apero #{Application.spec(:apero, :vsn)}")

  Application.spec(:apero, :modules)
  |> Enum.sort()
  |> Enum.each(&IO.puts/1)
' 2>&1 | grep -v "Arrea.Telemetry" || true

echo
echo "== ¿existe Apero.Llm?"
MIX_ENV=dev mix run -e '
  for mod <- [Apero.Llm, Apero.Llm.Health, Apero.Llm.ConfigManager] do
    case Code.ensure_loaded(mod) do
      {:module, _} -> IO.puts("#{inspect(mod)} EXISTE")
      {:error, _} -> IO.puts("#{inspect(mod)} NO EXISTE")
    end
  end
' 2>&1 | grep -v "Arrea.Telemetry" || true
