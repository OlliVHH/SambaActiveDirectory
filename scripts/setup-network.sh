#!/usr/bin/env bash
# Erstellt Datenverzeichnisse für den Samba AD DC.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENV_FILE="${ROOT_DIR}/.env"

if [[ ! -f "${ENV_FILE}" ]]; then
  echo "Kopiere .env.example nach .env und bearbeite die Werte." >&2
  exit 1
fi

mkdir -p "${ROOT_DIR}/data/samba" "${ROOT_DIR}/data/backups"

echo ""
echo "Setup abgeschlossen. Nächste Schritte:"
echo "  1. Image bauen: ${ROOT_DIR}/scripts/build-image.sh"
echo "  2. Host-Shim: sudo ${ROOT_DIR}/scripts/setup-host-shim.sh"
echo "  3. Deploy: ${ROOT_DIR}/scripts/deploy.sh"
