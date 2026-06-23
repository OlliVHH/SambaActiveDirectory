#!/usr/bin/env bash
# Aktiviert DHCP und setzt DHCP-Optionen nach der Domain-Provisionierung.
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
: "${GATEWAY:?GATEWAY fehlt}"
: "${DHCP_RANGE_START:?DHCP_RANGE_START fehlt}"
: "${DHCP_RANGE_END:?DHCP_RANGE_END fehlt}"
: "${DHCP_LEASE_TIME:=86400}"

if ! docker ps --format '{{.Names}}' | grep -qx "${CONTAINER}"; then
  echo "Container ${CONTAINER} läuft nicht." >&2
  exit 1
fi

docker exec "${CONTAINER}" bash -s -- \
  "${DC_IP}" "${REALM}" "${GATEWAY}" \
  "${DHCP_RANGE_START}" "${DHCP_RANGE_END}" "${DHCP_LEASE_TIME}" <<'REMOTE'
set -euo pipefail
DC_IP="$1"
REALM="$2"
GATEWAY="$3"
RANGE_START="$4"
RANGE_END="$5"
LEASE_TIME="$6"

SMB_CONF=""
for candidate in \
  /usr/local/samba/private/smb.conf \
  /var/lib/samba/private/smb.conf; do
  if [[ -f "${candidate}" ]]; then
    SMB_CONF="${candidate}"
    break
  fi
done

if [[ -z "${SMB_CONF}" ]]; then
  echo "Noch nicht provisioniert (smb.conf fehlt). Warte auf den DC-Start." >&2
  exit 1
fi

mark="# samba-ad-docker dhcp"
if grep -qF "${mark}" "${SMB_CONF}"; then
  echo "DHCP bereits konfiguriert."
  exit 0
fi

cat >> "${SMB_CONF}" <<EOF

${mark}
 dhcp support = yes
 dhcp range = ${RANGE_START} ${RANGE_END}
 dhcp lease time = ${LEASE_TIME}
 dhcp set = 3 = ${GATEWAY}
 dhcp set = 6 = ${DC_IP}
 dhcp set = 15 = ${REALM}
 server services = +dns +smb +ldap +kdc +winbindd +ntp +dhcp
EOF

samba-tool testparm -s >/dev/null
echo "DHCP konfiguriert in ${SMB_CONF}"
REMOTE

echo "Starte DC neu ..."
docker restart "${CONTAINER}" >/dev/null
echo "Fertig."
