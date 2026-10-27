#!/usr/bin/env bash
# G-07 · TOML en Apero.Conf.
#
# Cargar el ejemplo completo (tablas anidadas y arrays de tablas) y
# comprobar que el resultado coincide con el esperado.
set -euo pipefail
cd "$(dirname "$0")/.."

echo "== version de apero fijada"
grep -o '"apero".*' mix.lock | head -3

echo
echo "== carga del ejemplo completo con Apero.Conf"
MIX_ENV=dev mix run -e '
  case Code.ensure_loaded(Apero.Conf) do
    {:module, _} ->
      IO.puts("Apero.Conf: #{inspect(Apero.Conf.__info__(:functions))}")
      path = "examples/gunther.example.toml"

      if File.exists?(path) do
        IO.inspect(Apero.Conf.load(path), label: "cargado", limit: :infinity)
      else
        IO.puts("NO EXISTE #{path}")
      end

    {:error, _} ->
      IO.puts("Apero.Conf NO existe")
  end
' 2>/dev/null
