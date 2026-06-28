#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CONTAINER="${DC_CONTAINER:-dc01}"

echo "=== Container ==="
docker ps -a --filter "name=${CONTAINER}" --format 'table {{.Names}}\t{{.Status}}'

echo ""
echo "=== Logs (tail 40) ==="
docker logs "${CONTAINER}" --tail 40 2>&1 || true

echo ""
echo "=== testparm (one-off) ==="
docker compose -f "${ROOT_DIR}/docker-compose.yml" run --rm --no-deps --entrypoint samba-tool samba-dc testparm -s 2>&1 || true
