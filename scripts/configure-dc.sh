#!/usr/bin/env bash
# Wendet DHCP-Optionen (DNS, Domain-Suffix) nach Provisionierung an.
# Mehrere "dhcp set"-Zeilen sind in JSON nicht abbildbar – daher dieses Skript.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENV_FILE="${ROOT_DIR}/.env"
CONTAINER="${DC_CONTAINER:-dc01}"

if [[ -f "${ENV_FILE}" ]]; then
  set -a
  # shellcheck source=/dev/null
  source "${ENV_FILE}"
  set +a
fi

: "${DC_IP:?DC_IP fehlt}"
: "${REALM:?REALM fehlt}"

if ! docker ps --format '{{.Names}}' | grep -qx "${CONTAINER}"; then
  echo "Container ${CONTAINER} läuft nicht." >&2
  exit 1
fi

docker exec "${CONTAINER}" bash -s -- "${DC_IP}" "${REALM}" <<'REMOTE'
set -euo pipefail
DC_IP="$1"
REALM="$2"
SMB_CONF="/var/lib/samba/private/smb.conf"

if [[ ! -f "${SMB_CONF}" ]]; then
  echo "Noch nicht provisioniert (${SMB_CONF} fehlt). Starte den DC zuerst." >&2
  exit 1
fi

mark="# samba-ad-docker dhcp options"
if grep -qF "${mark}" "${SMB_CONF}"; then
  echo "DHCP-Optionen bereits gesetzt."
  exit 0
fi

cat >> "${SMB_CONF}" <<EOF

${mark}
 dhcp set = 6 = ${DC_IP}
 dhcp set = 15 = ${REALM}
EOF

samba-tool testparm -s >/dev/null
echo "DHCP-Optionen ergänzt. Samba-Dienste neu starten..."
samba_ctl restart || systemctl restart samba || true
REMOTE

echo "Fertig."
