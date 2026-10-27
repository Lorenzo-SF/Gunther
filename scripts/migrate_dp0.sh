#!/usr/bin/env bash
# migrate_dp0.sh — v2 (portable, sin backups, idempotente)
#
# Cambia el estado de los ADRs que siguen en "propuesta" a "aceptada (DP0, r8)".
# Portable: funciona en GNU sed (Linux) y BSD sed (macOS).
# No crea backups.
# Idempotente: se puede ejecutar varias veces sin efectos adversos.
#
# Ejecutar desde la raíz del repositorio:
#     bash scripts/migrate_dp0.sh
#
# Verificación manual posterior:
#     grep -l '^- \*\*Estado\*\*: propuesta' docs/08-decisiones/ADR-*.md
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
  if grep -q '^- \*\*Estado\*\*: propuesta' "$f"; then
    tmp="$(mktemp "${f}.XXXXXX")"
    sed 's/^- \*\*Estado\*\*: propuesta.*$/- **Estado**: aceptada (DP0, r8)/' "$f" > "$tmp"
    mv "$tmp" "$f"
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
if grep -l '^- \*\*Estado\*\*: propuesta' "$DIR"/ADR-*.md 2>/dev/null; then
  echo "FALLO: los archivos anteriores siguen en 'propuesta'." >&2
  exit 1
else
  echo "  Ningún ADR sigue en 'propuesta'. OK."
fi