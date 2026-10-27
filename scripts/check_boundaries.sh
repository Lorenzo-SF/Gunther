#!/usr/bin/env bash
# Fronteras de código (SPEC §0.4, §3.4, §3.6). Ejecutar desde la raíz del repositorio.
set -uo pipefail
fail=0
CORE=lib/gunther/core
BOUNDARY='lib/gunther/core/(resilience|command)/|lib/gunther/core/(cache|platform)\.ex|lib/gunther/core/config/'

# 1. Ejecución de procesos solo en Gunther.Command
bad=$(grep -rn -E 'System\.cmd|:os\.cmd|Port\.open' lib | grep -v 'lib/gunther/core/command/' || true)
[ -n "$bad" ] && { echo "Ejecución de procesos fuera de Gunther.Command:"; echo "$bad"; fail=1; }

# 2. Referencias a las hermanas solo en los módulos de frontera (excepción: Apero.Crypto y Apero.Env en providers)
bad=$(grep -rn -E '\b(Arrea|Apero|Trebejo)\.' lib | grep -v -E "$BOUNDARY" | grep -v -E 'lib/gunther/core/provider/.*(Apero\.Crypto|Apero\.Env)' || true)
[ -n "$bad" ] && { echo "Referencias a hermanas fuera de los módulos de frontera:"; echo "$bad"; fail=1; }

# 3. El núcleo no referencia módulos opcionales
bad=$(grep -rn -E 'Gunther\.(Gateway|MCP\.Server|Rag|Agent|Hive|Node\.Agent)\b' $CORE || true)
[ -n "$bad" ] && { echo "El núcleo referencia módulos opcionales:"; echo "$bad"; fail=1; }

# 4. Deserialización siempre segura
bad=$(grep -rn 'binary_to_term' lib | grep -v '\[:safe\]' || true)
[ -n "$bad" ] && { echo "binary_to_term sin [:safe]:"; echo "$bad"; fail=1; }

# 5. El ArgsBuilder no emite --rpc
bad=$(grep -rn -E '"--rpc"|--rpc ' lib || true)
[ -n "$bad" ] && { echo "Uso de --rpc (excluido por D-66):"; echo "$bad"; fail=1; }

exit $fail
