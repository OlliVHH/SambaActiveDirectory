#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

read -r -p "Samba-Daten in data/samba loeschen? [y/N] " confirm
if [[ "${confirm}" != "y" && "${confirm}" != "Y" ]]; then
  echo "Abgebrochen."
  exit 0
fi

cd "${ROOT_DIR}"
docker compose stop samba-dc 2>/dev/null || true

if [[ -d "${ROOT_DIR}/data/samba" ]]; then
  find "${ROOT_DIR}/data/samba" -mindepth 1 -delete 2>/dev/null || true
fi

echo "Daten geloescht. Weiter: bash scripts/deploy.sh"
