#!/usr/bin/env bash
# Offline-Domain-Backup via samba-tool (im laufenden Container).
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENV_FILE="${ROOT_DIR}/.env"
CONTAINER="${DC_CONTAINER:-dc01}"
BACKUP_ROOT="${ROOT_DIR}/data/backups"
STAMP="$(date +%Y%m%d-%H%M%S)"
TARGET="${BACKUP_ROOT}/${STAMP}"

if [[ -f "${ENV_FILE}" ]]; then
  set -a
  # shellcheck source=/dev/null
  source "${ENV_FILE}"
  set +a
fi

mkdir -p "${TARGET}"

if ! docker ps --format '{{.Names}}' | grep -qx "${CONTAINER}"; then
  echo "Container ${CONTAINER} läuft nicht." >&2
  exit 1
fi

echo "Backup nach ${TARGET} ..."
docker exec "${CONTAINER}" samba-tool domain backup offline --targetdir="/tmp/backup-${STAMP}"

docker cp "${CONTAINER}:/tmp/backup-${STAMP}/." "${TARGET}/"
docker exec "${CONTAINER}" rm -rf "/tmp/backup-${STAMP}"

# Alte Backups optional rotieren (30 Tage)
find "${BACKUP_ROOT}" -mindepth 1 -maxdepth 1 -type d -mtime +30 -exec rm -rf {} + 2>/dev/null || true

echo "Backup abgeschlossen: ${TARGET}"
