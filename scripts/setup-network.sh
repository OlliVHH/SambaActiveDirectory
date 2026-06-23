#!/usr/bin/env bash
# Erstellt Macvlan-Netzwerk und Datenverzeichnisse; generiert sambacc-Konfiguration.
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

: "${MACVLAN_PARENT:?MACVLAN_PARENT fehlt}"
: "${SUBNET:?SUBNET fehlt}"
: "${GATEWAY:?GATEWAY fehlt}"

NETWORK_NAME="samba-ad-lan"

mkdir -p "${ROOT_DIR}/data/samba" "${ROOT_DIR}/data/backups"

"${ROOT_DIR}/scripts/generate-config.sh"

echo ""
echo "Setup abgeschlossen. Nächste Schritte:"
echo "  1. Host-Shim (optional, für Host→DC Kommunikation): sudo ${ROOT_DIR}/scripts/setup-host-shim.sh"
echo "  2. DC starten: docker compose up -d samba-dc"
echo "  3. Nach erstem Start (Provisionierung ~2 Min): ${ROOT_DIR}/scripts/configure-dc.sh"
