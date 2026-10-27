#!/usr/bin/env bash
# G-17 · Versiones reales publicadas de arrea frente a la insignia del README.
#
# Procedimiento: se listan las versiones publicadas en Hex y se contrasta con
# la insignia que declara el README de arrea en el repositorio.
#
# Criterio de paso: la insignia coincide con la version real publicada, o la
# desviacion queda registrada y se fija la version en mix.lock.
set -euo pipefail
cd "$(dirname "$0")/.."

echo "== versiones publicadas de arrea en Hex"
curl -sS https://hex.pm/api/packages/arrea | tr ',' '\n' | grep -E '"version"' | head -20

echo
echo "== version fijada en mix.lock"
grep -o '"arrea".*' mix.lock | head -3

echo
echo "== insignia declarada en el README de arrea"
grep -n "hex.pm/packages/arrea\|badge\|shields.io" ../arrea/README.md | head -10
