#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CONTAINER="${DC_CONTAINER:-dc01}"

echo "=== Container ==="
docker ps -a --filter "name=${CONTAINER}" --format 'table {{.Names}}\t{{.Status}}'

echo ""
echo "=== Logs (tail 50) ==="
docker logs "${CONTAINER}" --tail 50 2>&1 || true

if docker ps --filter "name=${CONTAINER}" --filter "status=running" -q | grep -q .; then
  echo ""
  echo "=== testparm ==="
  docker exec "${CONTAINER}" samba-tool testparm -s 2>&1 | head -30 || true
  echo ""
  echo "=== domain info ==="
  # shellcheck source=/dev/null
  source "${ROOT_DIR}/.env" 2>/dev/null || true
  docker exec "${CONTAINER}" samba-tool domain info "${DC_IP:-192.168.100.10}" 2>&1 || true
  echo ""
  echo "=== processes ==="
  docker exec "${CONTAINER}" samba-tool processes 2>&1 || true
fi
