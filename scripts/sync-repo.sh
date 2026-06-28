#!/usr/bin/env bash
# Setzt Repo auf origin/main zurück (.env bleibt erhalten).
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENV_BACKUP="/tmp/samba-ad-env.backup.$$"

cd "${ROOT_DIR}"

if [[ -f .env ]]; then
  cp .env "${ENV_BACKUP}"
  echo "Backup: ${ENV_BACKUP}"
fi

git fetch origin
git reset --hard origin/main

if [[ -f "${ENV_BACKUP}" ]]; then
  cp "${ENV_BACKUP}" .env
  echo ".env wiederhergestellt."
fi

chmod +x scripts/*.sh 2>/dev/null || true

echo "Repo synchronisiert: $(git log -1 --oneline)"
echo "Weiter mit: ./scripts/build-image.sh && ./scripts/deploy.sh"
