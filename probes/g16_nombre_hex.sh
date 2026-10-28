#!/usr/bin/env bash
# G-16 · Disponibilidad del nombre `gunther` en Hex.
#
# Procedimiento: consulta de la API de Hex. Un paquete con status 404 no
# existe y el nombre esta libre; un 200 significa que el nombre esta ocupado.
set -euo pipefail

STATUS=$(curl -sS -o /dev/null -w "%{http_code}" https://hex.pm/api/packages/gunther)
echo "HTTP $STATUS en https://hex.pm/api/packages/gunther"

if [ "$STATUS" = "404" ]; then
  echo "RESULTADO: PASA - el nombre gunther esta libre en Hex."
  exit 0
else
  echo "RESULTADO: FALLA - el nombre gunther ya esta ocupado."
  exit 1
fi
