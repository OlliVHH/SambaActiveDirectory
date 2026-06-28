#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CONTAINER="${DC_CONTAINER:-dc01}"
BACKUP_ROOT="${ROOT_DIR}/data/backups"
STAMP="$(date +%Y%m%d-%H%M%S)"
TARGET="${BACKUP_ROOT}/${STAMP}"

mkdir -p "${TARGET}"

if ! docker ps --format '{{.Names}}' | grep -qx "${CONTAINER}"; then
  echo "Container ${CONTAINER} laeuft nicht." >&2
  exit 1
fi

echo "Backup nach ${TARGET} ..."
docker exec "${CONTAINER}" samba-tool domain backup offline --targetdir="/tmp/backup-${STAMP}"
docker cp "${CONTAINER}:/tmp/backup-${STAMP}/." "${TARGET}/"
docker exec "${CONTAINER}" rm -rf "/tmp/backup-${STAMP}"
echo "Fertig: ${TARGET}"
