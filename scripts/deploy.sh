#!/usr/bin/env bash
# Deploy: Image bauen, DC starten, auf Provisionierung warten.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENV_FILE="${ROOT_DIR}/.env"

if [[ ! -f "${ENV_FILE}" ]]; then
  cp "${ROOT_DIR}/.env.example" "${ENV_FILE}"
  echo "Erstellt .env – bitte ADMIN_PASSWORD setzen, dann erneut ausführen."
  exit 1
fi

chmod +x "${ROOT_DIR}/scripts/"*.sh

set -a
# shellcheck source=/dev/null
source "${ENV_FILE}"
set +a

for var in REALM DOMAIN ADMIN_PASSWORD DC_IP DNS_FORWARDER SAMBA_AD_IMAGE MACVLAN_PARENT SUBNET GATEWAY; do
  if [[ -z "${!var:-}" ]]; then
    echo "Fehler: ${var} fehlt in .env" >&2
    exit 1
  fi
done

mkdir -p "${ROOT_DIR}/data/samba" "${ROOT_DIR}/data/backups"

cd "${ROOT_DIR}"
echo "Baue Image ${SAMBA_AD_IMAGE} ..."
docker compose build samba-dc

echo "Starte DC ..."
docker compose up -d samba-dc

echo "Warte auf Provisionierung (max. 10 Min) ..."
ready=0
for _ in $(seq 1 120); do
  state="$(docker inspect -f '{{.State.Status}}' dc01 2>/dev/null || echo missing)"
  if [[ "${state}" == "running" ]]; then
    if docker exec dc01 test -f /var/lib/samba/private/secrets.keytab 2>/dev/null \
      && docker exec dc01 samba-tool testparm -s >/dev/null 2>&1; then
      ready=1
      break
    fi
  elif [[ "${state}" == "restarting" || "${state}" == "exited" ]]; then
    echo "Container-Problem (${state}). Logs:" >&2
    docker logs dc01 --tail 30 >&2 || true
  fi
  sleep 5
done

if [[ "${ready}" -ne 1 ]]; then
  echo "Timeout. Diagnose: ${ROOT_DIR}/scripts/diagnose-dc.sh" >&2
  exit 1
fi

echo ""
echo "=== DC bereit ==="
echo "  FQDN:   ${DC_HOSTNAME}.${REALM}"
echo "  IP:     ${DC_IP}"
echo "  Domain: ${REALM} (NetBIOS: ${DOMAIN})"
echo ""
echo "Tests:"
echo "  docker exec dc01 samba-tool domain info ${DC_IP}"
echo "  docker exec dc01 samba-tool processes"
echo "  ${ROOT_DIR}/scripts/diagnose-dc.sh"
