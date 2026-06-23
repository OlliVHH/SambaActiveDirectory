#!/usr/bin/env bash
# Prüft .env vor dem Start (REALM, ADMIN_PASSWORD, Image-Tag).
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
case "${arch}" in
  aarch64|arm64)
    if [[ "${SAMBA_AD_IMAGE}" == *":4.24.3"* ]] || [[ "${SAMBA_AD_IMAGE}" == *"quay.io"* ]]; then
      echo "Fehler: ${SAMBA_AD_IMAGE} ist nicht ARM64-native." >&2
      echo "Setze: SAMBA_AD_IMAGE=diegogslomp/samba-ad-dc:arm64" >&2
      exit 1
    fi
    ;;
esac

echo "OK: REALM=${REALM} DOMAIN=${DOMAIN} IMAGE=${SAMBA_AD_IMAGE}"
