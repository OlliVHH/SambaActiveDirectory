#!/usr/bin/env bash
# DHCP-Konfiguration per Include-Datei (sicher in [global] eingebunden).
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

if ! docker ps -a --format '{{.Names}}' | grep -qx "${CONTAINER}"; then
  echo "Container ${CONTAINER} existiert nicht." >&2
  exit 1
fi

docker exec -i "${CONTAINER}" bash -s -- "${DC_IP}" "${REALM}" "${GATEWAY}" "${DHCP_RANGE_START}" "${DHCP_RANGE_END}" "${DHCP_LEASE_TIME}" <<'REMOTE'
set -euo pipefail
DC_IP="$1"
REALM="$2"
GATEWAY="$3"
RANGE_START="$4"
RANGE_END="$5"
LEASE_TIME="$6"

SAMBA_STATE="/var/lib/samba"
SMB_CONF="${SAMBA_STATE}/private/smb.conf"
DROPIN="${SAMBA_STATE}/private/ad-docker-dhcp.conf"
INCLUDE_LINE="include = ${DROPIN}"

if [[ ! -f "${SMB_CONF}" ]]; then
  echo "Noch nicht provisioniert (smb.conf fehlt)." >&2
  exit 1
fi

if [[ -f "${DROPIN}" ]]; then
  echo "DHCP-Drop-in existiert bereits: ${DROPIN}"
else
  cat > "${DROPIN}" <<EOF
# samba-ad-docker dhcp
dhcp support = yes
dhcp range = ${RANGE_START} ${RANGE_END}
dhcp lease time = ${LEASE_TIME}
EOF
  echo "dhcp set = 3 = ${GATEWAY}" >> "${DROPIN}"
  echo "dhcp set = 6 = ${DC_IP}" >> "${DROPIN}"
  echo "dhcp set = 15 = ${REALM}" >> "${DROPIN}"
  echo "Geschrieben: ${DROPIN}"
fi

if ! grep -qF "${DROPIN}" "${SMB_CONF}"; then
  sed -i "/^\[global\]/a ${INCLUDE_LINE}" "${SMB_CONF}"
  echo "Include in smb.conf ergänzt."
else
  echo "Include bereits in smb.conf."
fi

samba-tool testparm -s >/dev/null
echo "testparm OK"
REMOTE

echo "Starte DC neu ..."
docker restart "${CONTAINER}" >/dev/null
sleep 5

if docker ps --format '{{.Names}} {{.Status}}' | grep -q '^dc01 Up'; then
  echo "DC läuft."
else
  echo "DC startet nicht – Logs:" >&2
  docker logs dc01 --tail 40 >&2 || true
  exit 1
fi

echo "Fertig."
