#!/usr/bin/env bash
# Generiert config/config.json aus .env für sambacc (Samba AD Container).
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENV_FILE="${ROOT_DIR}/.env"
OUT_FILE="${ROOT_DIR}/config/config.json"

if [[ ! -f "${ENV_FILE}" ]]; then
  echo "Fehler: ${ENV_FILE} nicht gefunden. Kopiere .env.example nach .env" >&2
  exit 1
fi

set -a
# shellcheck source=/dev/null
source "${ENV_FILE}"
set +a

: "${REALM:?REALM fehlt in .env}"
: "${DOMAIN:?DOMAIN fehlt in .env}"
: "${ADMIN_PASSWORD:?ADMIN_PASSWORD fehlt in .env}"
: "${DC_HOSTNAME:?DC_HOSTNAME fehlt in .env}"
: "${DNS_FORWARDER:?DNS_FORWARDER fehlt in .env}"
: "${DHCP_RANGE_START:?DHCP_RANGE_START fehlt in .env}"
: "${DHCP_RANGE_END:?DHCP_RANGE_END fehlt in .env}"
: "${GATEWAY:?GATEWAY fehlt in .env}"
: "${DHCP_LEASE_TIME:=86400}"

mkdir -p "${ROOT_DIR}/config"

# NetBIOS-Name: max. 15 Zeichen, typisch DC01
NETBIOS_NAME="$(echo "${DC_HOSTNAME}" | tr '[:lower:]' '[:upper:]')"

escape_json() {
  python3 -c 'import json,sys; print(json.dumps(sys.stdin.read()))'
}

ADMIN_PASSWORD_JSON="$(printf '%s' "${ADMIN_PASSWORD}" | escape_json)"

cat > "${OUT_FILE}" <<EOF
{
  "samba-container-config": "v0",
  "configs": {
    "dc01": {
      "instance_name": "${NETBIOS_NAME}",
      "instance_features": ["addc"],
      "domain_settings": "ad_orv",
      "globals": ["ad_globals"]
    }
  },
  "globals": {
    "ad_globals": {
      "options": {
        "dns forwarder": "${DNS_FORWARDER}",
        "dhcp support": "yes",
        "dhcp range": "${DHCP_RANGE_START} ${DHCP_RANGE_END}",
        "dhcp lease time": "${DHCP_LEASE_TIME}",
        "dhcp set": "3 = ${GATEWAY}",
        "interfaces": "lo eth0",
        "bind interfaces only": "yes",
        "server services": "+dns +smb +ldap +kdc +winbindd +ntp +dhcp"
      }
    }
  },
  "domain_settings": {
    "ad_orv": {
      "realm": "${REALM}",
      "short_domain": "${DOMAIN}",
      "admin_password": ${ADMIN_PASSWORD_JSON},
      "interfaces": {
        "include_pattern": "^eth0$"
      }
    }
  }
}
EOF

echo "Geschrieben: ${OUT_FILE}"
