#!/usr/bin/env bash
# Provisioniert ad.orv.space beim ersten Start (Debian-Paket-Pfade).
set -euo pipefail

SAMBA_STATE="${SAMBA_STATE:-/var/lib/samba}"
SECRETS="${SAMBA_STATE}/private/secrets.keytab"
SMB_CONF="${SAMBA_STATE}/private/smb.conf"

: "${REALM:?REALM is required}"
: "${DOMAIN:?DOMAIN is required}"
: "${ADMIN_PASS:?ADMIN_PASS is required}"
: "${DNS_FORWARDER:?DNS_FORWARDER is required}"

if [[ -f "${SECRETS}" ]]; then
  if [[ -f "${SMB_CONF}" ]]; then
    echo "Domain bereits provisioniert (${SECRETS} existiert)."
    exit 0
  fi
  echo "Fehler: ${SECRETS} existiert ohne smb.conf – Samba-Daten zurücksetzen." >&2
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

provision_common=(
  --server-role=dc
  --use-rfc2307
  --dns-backend=SAMBA_INTERNAL
  --realm="${REALM}"
  --domain="${DOMAIN}"
  --adminpass="${ADMIN_PASS}"
  --option="dns forwarder=${DNS_FORWARDER}"
  --option="interfaces=${INTERFACES}"
  --option="bind interfaces only=yes"
)

host_ip_args=()
if [[ -n "${DC_HOST_IP:-}" ]]; then
  host_ip_args=(--host-ip="${DC_HOST_IP}")
fi

samba-tool domain provision \
  "${provision_common[@]}" \
  "${host_ip_args[@]}"

echo "Provisionierung abgeschlossen."
