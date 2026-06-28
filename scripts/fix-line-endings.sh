#!/usr/bin/env bash
# Entfernt Windows-Zeilenenden (CRLF) aus Shell-Skripten.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

while IFS= read -r -d '' file; do
  sed -i 's/\r$//' "${file}"
  echo "Fixed: ${file}"
done < <(find "${ROOT_DIR}/scripts" "${ROOT_DIR}/docker/sbin" -name '*.sh' -print0 2>/dev/null)

echo "Fertig."
