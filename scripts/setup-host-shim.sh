#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENV_FILE="${ROOT_DIR}/.env"
CONTAINER="${DC_CONTAINER:-dc01}"

if [[ -f "${ENV_FILE}" ]]; then
  set -a
  # shellcheck source=/dev/null
  source "${ENV_FILE}"
  set +a
fi

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

echo "Host-Shim: ${HOST_SHIM_IP} auf ${SHIM_DEV}"
