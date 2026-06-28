#!/usr/bin/env bash
# Debian samba erwartet /etc/samba/smb.conf – AD-Config liegt unter /var/lib/samba/private/.
set -euo pipefail

SAMBA_STATE="${SAMBA_STATE:-/var/lib/samba}"
SMB_PRIVATE="${SAMBA_STATE}/private/smb.conf"

if [[ ! -f "${SMB_PRIVATE}" ]]; then
  echo "Fehler: ${SMB_PRIVATE} fehlt." >&2
  exit 1
fi

mkdir -p /etc/samba
ln -sf "${SMB_PRIVATE}" /etc/samba/smb.conf
