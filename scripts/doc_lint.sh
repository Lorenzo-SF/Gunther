#!/usr/bin/env bash
# Lint de documento (SPEC §0.6, regla 4). Falla si el texto normativo contiene cadenas prohibidas.
# Ignora bloques de código. Las coincidencias legítimas (la propia definición de la regla, nombres de
# código, citas del historial) se declaran en scripts/doc_lint_allow.txt, una expresión por línea.
set -euo pipefail
FILES=("$@"); [ ${#FILES[@]} -eq 0 ] && FILES=(SPEC-000-GUNTHER_r*.md docs/*.md)
PATTERN='supon|estim|aproximad|probablement|razonable|unos cientos|creo que|~ ?[0-9]'
ALLOW="$(dirname "$0")/doc_lint_allow.txt"
fail=0
for f in "${FILES[@]}"; do
  [ -f "$f" ] || continue
  hits=$(awk '/^```/{c=!c;next} !c{print NR": "$0}' "$f" | grep -n -i -E "$PATTERN" || true)
  if [ -n "$hits" ] && [ -f "$ALLOW" ]; then hits=$(echo "$hits" | grep -v -E -f "$ALLOW" || true); fi
  if [ -n "$hits" ]; then echo "== $f"; echo "$hits"; fail=1; fi
done
exit $fail
