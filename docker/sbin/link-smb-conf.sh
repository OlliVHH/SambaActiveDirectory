#!/usr/bin/env bash
# Debian legt smb.conf oft nach /etc/samba/smb.conf – beide Pfade unterstützen.
set -euo pipefail

SAMBA_STATE="${SAMBA_STATE:-/var/lib/samba}"
PRIVATE="${SAMBA_STATE}/private/smb.conf"
ETC="/etc/samba/smb.conf"

mkdir -p /etc/samba "${SAMBA_STATE}/private"

if [[ -f "${PRIVATE}" ]]; then
  ln -sf "${PRIVATE}" "${ETC}"
  echo "Symlink: ${ETC} -> ${PRIVATE}"
  exit 0
fi

if [[ -f "${ETC}" ]]; then
  echo "smb.conf OK: ${ETC}"
  exit 0
fi

echo "Fehler: keine smb.conf in ${PRIVATE} oder ${ETC}" >&2
exit 1
