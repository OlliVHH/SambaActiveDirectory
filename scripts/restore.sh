#!/usr/bin/env bash
# Stellt ein samba-tool domain backup wieder her (Container muss gestoppt sein).
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CONTAINER="${DC_CONTAINER:-dc01}"

if [[ $# -lt 1 ]]; then
  echo "Usage: $0 <backup-pfad-unter-data/backups/>" >&2
  echo "Beispiel: $0 data/backups/20260623-040000" >&2
  exit 1
fi

BACKUP_PATH="$1"
if [[ ! -d "${BACKUP_PATH}" ]]; then
  BACKUP_PATH="${ROOT_DIR}/${1}"
fi

if [[ ! -d "${BACKUP_PATH}" ]]; then
  echo "Backup-Verzeichnis nicht gefunden: ${BACKUP_PATH}" >&2
  exit 1
fi

echo "WARNUNG: Stoppe ${CONTAINER} und setze Samba-Daten zurück."
read -r -p "Fortfahren? [y/N] " confirm
if [[ "${confirm}" != "y" && "${confirm}" != "Y" ]]; then
  echo "Abgebrochen."
  exit 0
fi

docker compose -f "${ROOT_DIR}/docker-compose.yml" stop samba-dc

SAMBA_DATA="${ROOT_DIR}/data/samba"
if [[ -d "${SAMBA_DATA}" ]]; then
  find "${SAMBA_DATA}" -mindepth 1 -delete
fi

BACKUP_TAR="$(find "${BACKUP_PATH}" -maxdepth 1 -name '*.tar' -o -name '*.tar.bz2' -o -name '*.tar.gz' | head -n1)"
if [[ -z "${BACKUP_TAR}" ]]; then
  echo "Keine Backup-Datei (*.tar*) in ${BACKUP_PATH} gefunden." >&2
  exit 1
fi

docker compose -f "${ROOT_DIR}/docker-compose.yml" run --rm \
  -v "${SAMBA_DATA}:/var/lib/samba" \
  -v "${BACKUP_TAR}:/restore.tar:ro" \
  --entrypoint bash \
  "${SAMBA_AD_IMAGE:-quay.io/samba.org/samba-ad-server:latest}" \
  -c 'samba-tool domain backup restore --backup-file=/restore.tar --newservername=DC01 --targetdir=/var/lib/samba'

echo "Starte DC neu ..."
docker compose -f "${ROOT_DIR}/docker-compose.yml" up -d samba-dc
