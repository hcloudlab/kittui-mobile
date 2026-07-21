#!/usr/bin/env bash
set -euo pipefail

kml_ensure_service_user() {
  local user="$1"
  if id "$user" >/dev/null 2>&1; then
    return 0
  fi
  useradd --system --no-create-home --home-dir /nonexistent --shell /usr/sbin/nologin "$user"
}

kml_set_service_permissions() {
  chown -R root:root "$KML_ROOT"
  chown -R root:"$KML_XRAY_USER" "$KML_XRAY_CONFIG_DIR"
  chown -R root:"$KML_HYSTERIA_USER" "$KML_HYSTERIA_CONFIG_DIR" "$KML_CERT_DIR"
  chmod 0750 "$KML_XRAY_CONFIG_DIR" "$KML_HYSTERIA_CONFIG_DIR" "$KML_CERT_DIR"
  find "$KML_XRAY_CONFIG_DIR" -type f -exec chmod 0640 {} +
  find "$KML_HYSTERIA_CONFIG_DIR" -type f -exec chmod 0640 {} +
  find "$KML_CERT_DIR" -type f -exec chmod 0640 {} +
}
