#!/usr/bin/env bash
# Baut das native ARM64 Samba-Image auf dem Host (rasp5srv2).
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENV_FILE="${ROOT_DIR}/.env"

if [[ -f "${ENV_FILE}" ]]; then
  set -a
  # shellcheck source=/dev/null
  source "${ENV_FILE}"
  set +a
fi

arch="$(uname -m)"
if [[ "${arch}" != "aarch64" && "${arch}" != "arm64" ]]; then
  echo "Warnung: Host ist ${arch}, Image ist für linux/arm64 konfiguriert." >&2
fi

cd "${ROOT_DIR}"
echo "Baue ${SAMBA_AD_IMAGE:-samba-ad-orv:bookworm-arm64} ..."
docker compose build samba-dc

echo ""
docker image inspect "${SAMBA_AD_IMAGE:-samba-ad-orv:bookworm-arm64}" \
  --format 'Image: {{.RepoTags}} | {{.Os}}/{{.Architecture}} | Samba im Build-Log prüfen'
