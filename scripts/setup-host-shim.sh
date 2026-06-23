#!/usr/bin/env bash
# Macvlan-Shim auf dem Docker-Host: ermöglicht Traffic vom Host (154) zum DC (10).
# Einmalig mit root ausführen.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENV_FILE="${ROOT_DIR}/.env"

if [[ ! -f "${ENV_FILE}" ]]; then
  echo ".env nicht gefunden." >&2
  exit 1
fi

set -a
# shellcheck source=/dev/null
source "${ENV_FILE}"
set +a

: "${MACVLAN_PARENT:?MACVLAN_PARENT fehlt}"
: "${HOST_SHIM_IP:?HOST_SHIM_IP fehlt}"
: "${SUBNET:?SUBNET fehlt}"

SHIM_DEV="macvlan-shim"
PREFIX_LEN="${SUBNET##*/}"

if ip link show "${SHIM_DEV}" >/dev/null 2>&1; then
  echo "Interface ${SHIM_DEV} existiert bereits."
else
  ip link add "${SHIM_DEV}" link "${MACVLAN_PARENT}" type macvlan mode bridge
  echo "Interface ${SHIM_DEV} erstellt."
fi

ip addr flush dev "${SHIM_DEV}" 2>/dev/null || true
ip addr add "${HOST_SHIM_IP}/${PREFIX_LEN}" dev "${SHIM_DEV}"
ip link set "${SHIM_DEV}" up

echo "Host-Shim aktiv: ${HOST_SHIM_IP} auf ${SHIM_DEV}"
echo "Test: ping -c2 ${DC_IP:-192.168.100.10}"
