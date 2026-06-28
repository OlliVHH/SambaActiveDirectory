#!/usr/bin/env bash
# Entfernt fehlerhafte smb.conf-Anhänge von alter configure-dc-Version.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SMB_CONF="${ROOT_DIR}/data/samba/private/smb.conf"

if [[ ! -f "${SMB_CONF}" ]]; then
  echo "Keine smb.conf unter ${SMB_CONF}" >&2
  exit 1
fi

cp "${SMB_CONF}" "${SMB_CONF}.bak.$(date +%Y%m%d%H%M%S)"

python3 <<'PY' "${SMB_CONF}"
import sys
path = sys.argv[1]
with open(path, encoding="utf-8", errors="replace") as f:
    lines = f.readlines()
out = []
for line in lines:
    if line.lstrip().startswith("# samba-ad-docker"):
        break
    out.append(line)
with open(path, "w", encoding="utf-8") as f:
    f.writelines(out)
print(f"Repariert: {path} ({len(lines) - len(out)} Zeilen entfernt)")
PY

echo "Starte DC neu ..."
cd "${ROOT_DIR}"
docker compose up -d samba-dc
sleep 5
docker logs dc01 --tail 20
