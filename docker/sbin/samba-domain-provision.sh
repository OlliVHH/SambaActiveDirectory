#!/usr/bin/env bash
# Provisioniert ad.orv.space beim ersten Start (Debian-Paket-Pfade).
set -euo pipefail

SAMBA_STATE="${SAMBA_STATE:-/var/lib/samba}"
SECRETS="${SAMBA_STATE}/private/secrets.keytab"
SMB_PRIVATE="${SAMBA_STATE}/private/smb.conf"
SMB_ETC="/etc/samba/smb.conf"

: "${REALM:?REALM is required}"
: "${DOMAIN:?DOMAIN is required}"
: "${ADMIN_PASS:?ADMIN_PASS is required}"
: "${DNS_FORWARDER:?DNS_FORWARDER is required}"

has_smb_conf() {
  [[ -f "${SMB_PRIVATE}" || -f "${SMB_ETC}" ]]
}

if [[ -f "${SECRETS}" ]]; then
  if has_smb_conf; then
    echo "Domain bereits provisioniert."
    exit 0
  fi
  echo "Fehler: secrets.keytab ohne smb.conf – Daten zurücksetzen (bash scripts/reset-data.sh)." >&2
  exit 1
fi

echo "Provisioniere Samba AD: REALM=${REALM} DOMAIN=${DOMAIN}"

rm -f /etc/samba/smb.conf /etc/samba/smb.conf.dpkg-old 2>/dev/null || true

until ip -o link show up | grep -v ' lo:' >/dev/null 2>&1; do
  echo "Warte auf Netzwerkinterface..."
  sleep 1
done
INTERFACE="$(ip -o link show up | awk -F': ' '!/ lo:/ {print $2; exit}')"

INTERFACES="lo ${INTERFACE}"
if [[ -n "${DC_HOST_IP:-}" ]]; then
  INTERFACES="lo ${INTERFACE} ${DC_HOST_IP}"
fi

host_ip_args=()
if [[ -n "${DC_HOST_IP:-}" ]]; then
  host_ip_args=(--host-ip="${DC_HOST_IP}")
fi

samba-tool domain provision \
  --server-role=dc \
  --use-rfc2307 \
  --dns-backend=SAMBA_INTERNAL \
  --realm="${REALM}" \
  --domain="${DOMAIN}" \
  --adminpass="${ADMIN_PASS}" \
  --option="dns forwarder=${DNS_FORWARDER}" \
  --option="interfaces=${INTERFACES}" \
  --option="bind interfaces only=yes" \
  "${host_ip_args[@]}"

if ! has_smb_conf; then
  echo "Fehler: Provision ohne smb.conf (Debian-Pfad ${SMB_ETC} erwartet)." >&2
  exit 1
fi

echo "Provisionierung abgeschlossen."
