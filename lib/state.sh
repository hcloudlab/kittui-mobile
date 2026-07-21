#!/usr/bin/env bash
set -euo pipefail

kml_json_escape() {
  jq -Rsa . <<<"${1:-}" | tr -d '\n'
}

kml_prepare_dirs() {
  install -d -m 0750 "$KML_ROOT" "$KML_BIN_DIR" "$KML_CONFIG_DIR" "$KML_XRAY_CONFIG_DIR" \
    "$KML_HYSTERIA_CONFIG_DIR" "$KML_CERT_DIR" "$KML_OUTPUT_DIR" "$KML_LOG_DIR" "$KML_BACKUP_DIR"
}

kml_state_init() {
  kml_prepare_dirs
  if [[ ! -s "$KML_STATE_FILE" ]]; then
    jq -n \
      --arg version "$KML_VERSION" \
      --arg root "$KML_ROOT" \
      '{version:$version, root:$root, created_at:now|todate, server_host:"", force_replace:false, firewall:{mode:"auto",detected:"unknown",created_rules:[]}, binaries:{}, services:{}, reality:{}, hysteria2:{}, backups:[]}' \
      > "$KML_STATE_FILE"
  fi
  chmod 0600 "$KML_STATE_FILE"
}

kml_state_get() {
  local filter="$1"
  [[ -s "$KML_STATE_FILE" ]] || return 0
  jq -r "$filter // empty" "$KML_STATE_FILE"
}

kml_state_set_string() {
  local filter="$1" value="$2" tmp
  tmp="$(mktemp)"
  jq --arg value "$value" "$filter = \$value" "$KML_STATE_FILE" > "$tmp"
  install -m 0600 "$tmp" "$KML_STATE_FILE"
  rm -f "$tmp"
}

kml_state_set_bool() {
  local filter="$1" value="$2" tmp
  tmp="$(mktemp)"
  jq --argjson value "$value" "$filter = \$value" "$KML_STATE_FILE" > "$tmp"
  install -m 0600 "$tmp" "$KML_STATE_FILE"
  rm -f "$tmp"
}

kml_state_set_number() {
  local filter="$1" value="$2" tmp
  tmp="$(mktemp)"
  jq --argjson value "$value" "$filter = \$value" "$KML_STATE_FILE" > "$tmp"
  install -m 0600 "$tmp" "$KML_STATE_FILE"
  rm -f "$tmp"
}

kml_state_append_json() {
  local filter="$1" json="$2" tmp
  tmp="$(mktemp)"
  jq --argjson item "$json" "$filter += [\$item]" "$KML_STATE_FILE" > "$tmp"
  install -m 0600 "$tmp" "$KML_STATE_FILE"
  rm -f "$tmp"
}
