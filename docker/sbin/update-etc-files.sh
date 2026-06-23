#!/usr/bin/env bash
set -euo pipefail

SAMBA_STATE="${SAMBA_STATE:-/var/lib/samba}"
: "${REALM:?REALM is required}"

until ip -o addr show scope global >/dev/null 2>&1; do
  echo "Warte auf globale IP..."
  sleep 1
done

SERVER_IP="$(ip -o addr show scope global | awk '{print $4}' | cut -d/ -f1 | head -n1)"
SEARCH_DOMAIN="$(echo "${REALM}" | tr '[:upper:]' '[:lower:]')"

if ! grep -q "${SEARCH_DOMAIN}" /etc/resolv.conf 2>/dev/null; then
  printf 'search %s\nnameserver %s\n' "${SEARCH_DOMAIN}" "${SERVER_IP}" >/etc/resolv.conf
fi

if ! grep -q "${SEARCH_DOMAIN}" /etc/hosts 2>/dev/null; then
  printf '%s %s.%s %s\n' "${SERVER_IP}" "$(hostname)" "${SEARCH_DOMAIN}" "$(hostname)" >>/etc/hosts
fi

if [[ -f "${SAMBA_STATE}/private/krb5.conf" ]] && ! grep -q "${SEARCH_DOMAIN}" /etc/krb5.conf 2>/dev/null; then
  cp "${SAMBA_STATE}/private/krb5.conf" /etc/krb5.conf
fi

SMB_CONF="${SAMBA_STATE}/private/smb.conf"
if [[ -f "${SMB_CONF}" ]] && ! grep -q "ldap server require strong auth" "${SMB_CONF}"; then
  sed -i '/^\[global\]/a\
 ldap server require strong auth = No' "${SMB_CONF}"
fi
