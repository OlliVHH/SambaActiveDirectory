#!/usr/bin/env bash

# IPv4-only Bindung und DHCP nach der Domain-Provisionierung.

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

  /var/lib/samba/private/smb.conf \

  /usr/local/samba/private/smb.conf; do

  if [[ -f "${candidate}" ]]; then

    SMB_CONF="${candidate}"

    break

  fi

done



if [[ -z "${SMB_CONF}" ]]; then

  echo "Noch nicht provisioniert (smb.conf fehlt)." >&2

  exit 1

fi



INTERFACE="$(ip -o link show up | awk -F': ' '!/ lo:/ {print $2; exit}')"

CHANGED=0



mark_ipv4="# samba-ad-docker ipv4-only"

if ! grep -qF "${mark_ipv4}" "${SMB_CONF}"; then

  cat >> "${SMB_CONF}" <<EOF



${mark_ipv4}

 bind interfaces only = yes

 interfaces = lo ${INTERFACE} ${DC_IP}

EOF

  CHANGED=1

  echo "IPv4-only Bindung ergänzt."

fi



mark_dhcp="# samba-ad-docker dhcp"

if ! grep -qF "${mark_dhcp}" "${SMB_CONF}"; then

  cat >> "${SMB_CONF}" <<EOF



${mark_dhcp}

 dhcp support = yes

 dhcp range = ${RANGE_START} ${RANGE_END}

 dhcp lease time = ${LEASE_TIME}

 dhcp set = 3 = ${GATEWAY}

 dhcp set = 6 = ${DC_IP}

 dhcp set = 15 = ${REALM}

 server services = +dns +smb +ldap +kdc +winbindd +ntp +dhcp

EOF

  CHANGED=1

  echo "DHCP ergänzt."

fi



if [[ "${CHANGED}" -eq 0 ]]; then

  echo "Konfiguration bereits vollständig."

  exit 0

fi



samba-tool testparm -s >/dev/null

echo "Konfiguration OK: ${SMB_CONF}"

REMOTE



echo "Starte DC neu ..."

docker restart "${CONTAINER}" >/dev/null

echo "Fertig."

