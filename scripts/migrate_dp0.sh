#!/usr/bin/env bash
# migrate_dp0.sh — Migración DP0 (2026-10-26)
#
# Cambia el estado de los ADRs que siguen en "propuesta" a "aceptada (DP0, r8)".
# No toca los que ya están aceptados, sustituidos o rechazados.
# No toca las notas internas del ADR: solo la línea "**Estado**:" de la cabecera.
#
# Ejecutar UNA VEZ desde la raíz del repositorio:
#     bash scripts/migrate_dp0.sh
#
# Después:
#     grep -rE '^\*\*Estado\*\*: propuesta' docs/08-decisiones/ADR-*.md
# debe devolver cero líneas.

set -euo pipefail

DIR="docs/08-decisiones"
if [ ! -d "$DIR" ]; then
  echo "Error: no existe $DIR. Ejecuta desde la raíz del repositorio." >&2
  exit 1
fi

changed=0
skipped=0

for f in "$DIR"/ADR-*.md; do
  [ -f "$f" ] || continue
  if head -10 "$f" | grep -qE '^\- \*\*Estado\*\*: (propuesta( \(resuelta por delegación del dueño en r7\))?)$'; then
    sed -i -E \
      's/^\- \*\*Estado\*\*: propuesta( \(resuelta por delegación del dueño en r7\))?$/- **Estado**: aceptada (DP0, r8)/' \
      "$f"
    echo "Actualizado: $f"
    changed=$((changed + 1))
  else
    skipped=$((skipped + 1))
  fi
done

echo
echo "Archivos actualizados: $changed"
echo "Archivos sin cambio (ya aceptados, sustituidos o rechazados): $skipped"
echo
echo "Verificación:"
grep -rE '^\*\*Estado\*\*: propuesta' "$DIR"/ADR-*.md 2>/dev/null || echo "  Ningún ADR sigue en 'propuesta'. OK."