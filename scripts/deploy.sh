#!/usr/bin/env bash
# Erster Deploy auf dem Docker-Host (192.168.100.154).
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

if [[ ! -f "${ROOT_DIR}/.env" ]]; then
  cp "${ROOT_DIR}/.env.example" "${ROOT_DIR}/.env"
  echo "Erstellt .env – bitte ADMIN_PASSWORD setzen, dann erneut ausführen."
  exit 1
fi

chmod +x "${ROOT_DIR}/scripts/"*.sh

# shellcheck source=/dev/null
set -a; source "${ROOT_DIR}/.env"; set +a

"${ROOT_DIR}/scripts/setup-network.sh"

cd "${ROOT_DIR}"
docker compose pull samba-dc watchtower
docker compose up -d

echo ""
echo "Warte auf Provisionierung (bis smb.conf existiert)..."
for i in $(seq 1 60); do
  if docker exec dc01 test -f /var/lib/samba/private/smb.conf 2>/dev/null; then
  echo "Domain provisioniert."
  break
  fi
  sleep 5
done

"${ROOT_DIR}/scripts/configure-dc.sh"

echo ""
echo "DC: dc01.ad.orv.space (${DC_IP:-192.168.100.10})"
echo "Domain join: ad.orv.space (NetBIOS: AD)"
echo "Backup: ${ROOT_DIR}/scripts/backup.sh"
