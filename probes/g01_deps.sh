#!/usr/bin/env bash
# G-01 · Dependencias sin ciclos.
#
# Procedimiento: `mix deps.tree` sobre el proyecto real (no un proyecto
# vacío: las versiones fijadas en mix.lock son las que se publican) y
# `mix hex.outdated` para detectar conflictos entre las hermanas.
#
# Criterio de paso (docs/04-f0-puertas.md): resuelve sin ciclos ni conflictos.
set -euo pipefail
cd "$(dirname "$0")/.."

echo "== mix deps.tree"
mix deps.tree

echo
echo "== mix deps.get --check-locked"
mix deps.get --check-locked

echo
echo "== mix hex.outdated (conflictos entre hermanas)"
mix hex.outdated || true
