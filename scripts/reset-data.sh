#!/usr/bin/env bash
# Löscht Samba-Daten für Neu-Provisionierung (Container wird gestoppt).
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

read -r -p "Alle Samba-Daten löschen und DC neu provisionieren? [y/N] " confirm
if [[ "${confirm}" != "y" && "${confirm}" != "Y" ]]; then
  echo "Abgebrochen."
  exit 0
fi

cd "${ROOT_DIR}"
docker compose stop samba-dc 2>/dev/null || true

if [[ -d "${ROOT_DIR}/data/samba" ]]; then
  find "${ROOT_DIR}/data/samba" -mindepth 1 -delete 2>/dev/null || true
fi

# Legacy-Pfade von früheren Image-Versionen
for dir in samba-etc samba-private samba-var; do
  if [[ -d "${ROOT_DIR}/data/${dir}" ]]; then
    find "${ROOT_DIR}/data/${dir}" -mindepth 1 -delete 2>/dev/null || true
  fi
done

echo "Daten gelöscht. Starte mit: ./scripts/deploy.sh"
