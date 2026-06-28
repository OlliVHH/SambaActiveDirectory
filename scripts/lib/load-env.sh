#!/usr/bin/env bash
# Lädt nur bekannte Variablen aus .env (robust gegen Leerzeichen/Kommentare).
load_env() {
  local env_file="$1"
  local keys=(
    REALM DOMAIN ADMIN_PASSWORD DC_HOSTNAME
    DC_IP DOCKER_HOST_IP HOST_SHIM_IP GATEWAY SUBNET MACVLAN_PARENT
    DNS_FORWARDER SAMBA_AD_IMAGE
  )
  local line key val
  declare -A file_vars=()
  while IFS= read -r line || [[ -n "${line}" ]]; do
    line="${line%%#*}"
    line="$(echo "${line}" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"
    [[ -z "${line}" ]] && continue
    key="${line%%=*}"
    val="${line#*=}"
    val="${val#\"}" ; val="${val%\"}"
    val="${val#\'}" ; val="${val%\'}"
    file_vars["${key}"]="${val}"
  done < "${env_file}"
  for key in "${keys[@]}"; do
    if [[ -n "${file_vars[${key}]+x}" ]]; then
      export "${key}=${file_vars[${key}]}"
    fi
  done
}
