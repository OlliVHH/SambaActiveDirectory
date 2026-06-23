#!/usr/bin/env bash
# Erstellt Datenverzeichnisse für den Samba AD DC.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENV_FILE="${ROOT_DIR}/.env"

if [[ ! -f "${ENV_FILE}" ]]; then
  echo "Kopiere .env.example nach .env und bearbeite die Werte." >&2
  exit 1
fi

set -a
# shellcheck source=/dev/null
source "${ENV_FILE}"
set +a

mkdir -p \
  "${ROOT_DIR}/data/samba-etc" \
  "${ROOT_DIR}/data/samba-private" \
  "${ROOT_DIR}/data/samba-var" \
  "${ROOT_DIR}/data/backups"

echo ""
echo "Setup abgeschlossen. Nächste Schritte:"
echo "  1. Host-Shim (für Host→DC): sudo ${ROOT_DIR}/scripts/setup-host-shim.sh"
echo "  2. DC starten: docker compose up -d samba-dc"
echo "  3. Nach Provisionierung: ${ROOT_DIR}/scripts/configure-dc.sh"
