#!/usr/bin/env bash
# Komplette Installation auf rasp5srv2 – immer mit: bash scripts/install.sh
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENV_FILE="${ROOT_DIR}/.env"
ENV_BACKUP="/tmp/samba-ad-env.backup"

cd "${ROOT_DIR}"

echo "=== 1/7 Repository aktualisieren ==="
if [[ -f "${ENV_FILE}" ]]; then
  cp "${ENV_FILE}" "${ENV_BACKUP}"
  echo "Backup: ${ENV_BACKUP}"
fi
git fetch origin
git reset --hard origin/main
if [[ -f "${ENV_BACKUP}" ]]; then
  cp "${ENV_BACKUP}" "${ENV_FILE}"
fi

chmod +x "${ROOT_DIR}/scripts/"*.sh 2>/dev/null || true

echo "=== 2/7 .env prüfen ==="
if [[ ! -f "${ENV_FILE}" ]]; then
  cp "${ROOT_DIR}/.env.example" "${ENV_FILE}"
  echo "FEHLER: .env neu erstellt. Bitte ADMIN_PASSWORD setzen:"
  echo "  nano ${ENV_FILE}"
  exit 1
fi

# shellcheck source=scripts/lib/load-env.sh
source "${ROOT_DIR}/scripts/lib/load-env.sh"
load_env "${ENV_FILE}"

missing=()
for var in REALM DOMAIN ADMIN_PASSWORD DC_IP DNS_FORWARDER SAMBA_AD_IMAGE MACVLAN_PARENT SUBNET GATEWAY DC_HOSTNAME; do
  if [[ -z "${!var:-}" ]]; then
    missing+=("${var}")
  fi
done
if [[ ${#missing[@]} -gt 0 ]]; then
  echo "FEHLER: Fehlende Werte in .env: ${missing[*]}" >&2
  exit 1
fi
if [[ "${ADMIN_PASSWORD}" == "ChangeMe_SecurePassword123!" ]]; then
  echo "FEHLER: Bitte ADMIN_PASSWORD in .env ändern (nicht Default)." >&2
  exit 1
fi

echo "=== 3/7 Voraussetzungen ==="
command -v docker >/dev/null || { echo "FEHLER: docker nicht installiert" >&2; exit 1; }
docker compose version >/dev/null || { echo "FEHLER: docker compose nicht verfügbar" >&2; exit 1; }
ip link show "${MACVLAN_PARENT}" >/dev/null || { echo "FEHLER: Interface ${MACVLAN_PARENT} nicht gefunden" >&2; exit 1; }

echo "=== 4/7 Alte Container stoppen, Daten leeren ==="
docker compose down --remove-orphans 2>/dev/null || true
mkdir -p "${ROOT_DIR}/data/samba" "${ROOT_DIR}/data/backups"
find "${ROOT_DIR}/data/samba" -mindepth 1 -delete 2>/dev/null || true

echo "=== 5/7 Macvlan-Shim (Host -> DC) ==="
if [[ "${EUID}" -ne 0 ]]; then
  bash "${ROOT_DIR}/scripts/setup-host-shim.sh" 2>/dev/null || \
    sudo bash "${ROOT_DIR}/scripts/setup-host-shim.sh"
else
  bash "${ROOT_DIR}/scripts/setup-host-shim.sh"
fi

echo "=== 6/7 Image bauen und DC starten ==="
docker compose build samba-dc
docker compose up -d samba-dc

echo "=== 7/7 Warte auf Provisionierung (max. 10 Min) ==="
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
    echo "Container-Status: ${state} – warte/weiter..."
    docker logs dc01 --tail 15 2>&1 || true
  fi
  sleep 5
done

if [[ "${ready}" -ne 1 ]]; then
  echo "FEHLER: Timeout. Ausführen: bash scripts/diagnose-dc.sh" >&2
  exit 1
fi

echo ""
echo "=== ERFOLG ==="
echo "  DC:     ${DC_HOSTNAME}.${REALM} @ ${DC_IP}"
echo "  Domain: ${REALM} (NetBIOS: ${DOMAIN})"
echo ""
echo "Tests:"
echo "  bash scripts/diagnose-dc.sh"
echo "  docker exec dc01 samba-tool domain info ${DC_IP}"
