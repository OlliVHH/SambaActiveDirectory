#!/usr/bin/env bash
set -euo pipefail

/usr/local/sbin/samba-domain-provision.sh
/usr/local/sbin/update-etc-files.sh
exec /usr/sbin/samba -i
