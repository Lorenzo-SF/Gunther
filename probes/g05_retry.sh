#!/usr/bin/env bash
# G-05 · Apero.Retry: predicado `retryable?` y `retry_after`.
#
# La puerta exige dos cosas: un predicado de reintentabilidad y el respeto
# del retraso que dicta el servicio. Se lee la API publicada de
# `Apero.Retry` y se comprueba si el retraso que devuelve el servidor
# (`retry-after`) tiene alguna via.
set -euo pipefail
cd "$(dirname "$0")/.."

echo "== version de apero fijada"
grep -o '"apero".*' mix.lock | head -3

echo
echo "== API de Apero.Retry"
MIX_ENV=dev mix run -e '
  case Code.ensure_loaded(Apero.Retry) do
    {:module, _} ->
      IO.puts("Apero.Retry exporta: #{inspect(Apero.Retry.__info__(:functions))}")

    {:error, _} ->
      IO.puts("Apero.Retry NO existe en la version instalada")
  end
' 2>&1 | grep -v "Arrea.Telemetry" || true

echo
echo "== ¿hay alguna opcion de retry_after o similar?"
MIX_ENV=dev mix run -e '
  src = Apero.Retry.__info__(:functions) |> Enum.map(&elem(&1, 0)) |> Enum.join(", ")
  IO.puts("funciones: #{src}")

  {:docs_v1, _, _, _, _, _, docs} = Code.fetch_docs(Apero.Retry)
  opts =
    docs
    |> Enum.flat_map(fn
      {{:function, _, name, arity}, _, _, _, %{"en" => text}, _} ->
        [name]

      _ ->
        []
    end)
    |> Enum.uniq()

  IO.puts("funciones documentadas: #{inspect(opts)}")

  texto =
    docs
    |> Enum.map(fn
      {_, _, _, _, %{"en" => text}, _} -> text
      _ -> ""
    end)
    |> Enum.join("\n")

  IO.puts("menciona retry_after: #{texto =~ ~r/retry[_ -]?after/i}")
  IO.puts("menciona Retry-After: #{texto =~ ~r/Retry-After/i}")
' 2>&1 | grep -v "Arrea.Telemetry" || true
