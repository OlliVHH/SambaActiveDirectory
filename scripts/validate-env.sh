#!/usr/bin/env bash
# Prüft .env vor dem Start.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENV_FILE="${ROOT_DIR}/.env"

if [[ ! -f "${ENV_FILE}" ]]; then
  echo "Fehler: ${ENV_FILE} fehlt. Kopiere .env.example nach .env" >&2
  exit 1
fi

set -a
# shellcheck source=/dev/null
source "${ENV_FILE}"
set +a

missing=()
[[ -z "${REALM:-}" ]] && missing+=("REALM")
[[ -z "${DOMAIN:-}" ]] && missing+=("DOMAIN")
[[ -z "${ADMIN_PASSWORD:-}" ]] && missing+=("ADMIN_PASSWORD")
[[ -z "${DNS_FORWARDER:-}" ]] && missing+=("DNS_FORWARDER")
[[ -z "${SAMBA_AD_IMAGE:-}" ]] && missing+=("SAMBA_AD_IMAGE")

if [[ ${#missing[@]} -gt 0 ]]; then
  echo "Fehler: fehlende Werte in .env: ${missing[*]}" >&2
  exit 1
fi

arch="$(uname -m)"
if [[ "${arch}" == "aarch64" || "${arch}" == "arm64" ]]; then
  if [[ "${SAMBA_AD_IMAGE}" == *"quay.io"* ]] || [[ "${SAMBA_AD_IMAGE}" == *"diegogslomp"* ]]; then
    echo "Hinweis: Für Raspberry Pi nutze das lokale Image:" >&2
    echo "  SAMBA_AD_IMAGE=samba-ad-orv:bookworm-arm64" >&2
    echo "  ./scripts/build-image.sh" >&2
    exit 1
  fi
fi

echo "OK: REALM=${REALM} DOMAIN=${DOMAIN} IMAGE=${SAMBA_AD_IMAGE}"
