#!/usr/bin/env bash
# G-02, G-03, G-04 · Primitivas de resiliencia de Arrea.
#
# G-02: umbrales por breaker. Cada breaker abre con su propio umbral.
# G-03: half-open con una sola sonda. Tras el timeout, N llamadas concurrentes
#       dejan pasar una sola.
# G-04: bulkhead con fallo rapido al llenarse, y rate limiter con peso.
set -euo pipefail
cd "$(dirname "$0")/.."

echo "== version de arrea fijada"
grep -o '"arrea".*' mix.lock | head -3

echo
echo "== API de Arrea.CircuitBreaker, Arrea.Bulkhead y Arrea.RateLimiter"
MIX_ENV=dev mix run -e '
  for mod <- [Arrea.CircuitBreaker, Arrea.Bulkhead, Arrea.RateLimiter] do
    case Code.ensure_loaded(mod) do
      {:module, _} ->
        IO.puts("#{inspect(mod)}: #{inspect(mod.__info__(:functions))}")

      {:error, _} ->
        IO.puts("#{inspect(mod)}: NO EXISTE")
    end
  end
' 2>/dev/null
