#!/usr/bin/env bash
# Erster Deploy auf dem Docker-Host (192.168.100.154 / rasp5srv2).
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

"${ROOT_DIR}/scripts/validate-env.sh"
"${ROOT_DIR}/scripts/setup-network.sh"

cd "${ROOT_DIR}"

if ! docker image inspect "${SAMBA_AD_IMAGE}" >/dev/null 2>&1; then
  echo "Image ${SAMBA_AD_IMAGE} nicht gefunden – baue lokal ..."
  "${ROOT_DIR}/scripts/build-image.sh"
else
  echo "Image ${SAMBA_AD_IMAGE} vorhanden – überspringe Build (./scripts/build-image.sh zum Neu-Bauen)"
fi

docker compose pull watchtower 2>/dev/null || true
docker compose up -d

echo ""
echo "Warte auf Provisionierung (bis smb.conf existiert)..."
provisioned=0
for _ in $(seq 1 72); do
  if docker exec dc01 test -f /var/lib/samba/private/smb.conf 2>/dev/null; then
    echo "Domain provisioniert."
    provisioned=1
    break
  fi
  if ! docker ps --format '{{.Names}}' | grep -qx dc01; then
    echo "Container dc01 nicht läuft – Logs:" >&2
    docker logs dc01 --tail 40 >&2 || true
    exit 1
  fi
  sleep 5
done

if [[ "${provisioned}" -eq 0 ]]; then
  echo "Timeout bei Provisionierung. Prüfe: docker logs dc01" >&2
  exit 1
fi

"${ROOT_DIR}/scripts/configure-dc.sh"

echo ""
echo "DC: ${DC_HOSTNAME:-dc01}.${REALM:-ad.orv.space} (${DC_IP:-192.168.100.10})"
echo "Domain join: ${REALM:-ad.orv.space} (NetBIOS: ${DOMAIN:-AD})"
echo "Backup: ${ROOT_DIR}/scripts/backup.sh"
