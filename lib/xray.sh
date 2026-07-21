#!/usr/bin/env bash
set -euo pipefail

kml_uuid() {
  if command -v uuidgen >/dev/null 2>&1; then
    uuidgen | tr '[:upper:]' '[:lower:]'
  else
    od -An -tx1 -N16 /dev/urandom | tr -d ' \n' | sed -E 's/(.{8})(.{4})(.{4})(.{4})(.{12})/\1-\2-\3-\4-\5/'
  fi
}

kml_xray_keys() {
  local output private public
  output="$("$KML_BIN_DIR/xray" x25519)"
  private="$(awk -F': ' '/Private key|^Password:/ {print $2}' <<<"$output" | head -n1)"
  public="$(awk -F': ' '/Public key|Password \(PublicKey\)/ {print $2}' <<<"$output" | tail -n1)"
  [[ -n "$private" && -n "$public" ]] || kml_die "无法生成 Reality X25519 密钥。"
  printf '%s %s\n' "$private" "$public"
}

kml_xray_render_config() {
  local uuid="$1" private_key="$2" short_id="$3" port="$4"
  cat <<EOF
{
  "log": {
    "loglevel": "warning",
    "access": "$KML_LOG_DIR/xray-access.log",
    "error": "$KML_LOG_DIR/xray-error.log"
  },
  "inbounds": [
    {
      "listen": "0.0.0.0",
      "port": $port,
      "protocol": "vless",
      "settings": {
        "clients": [
          {
            "id": "$uuid",
            "flow": "xtls-rprx-vision"
          }
        ],
        "decryption": "none"
      },
      "streamSettings": {
        "network": "tcp",
        "security": "reality",
        "realitySettings": {
          "show": false,
          "dest": "$REALITY_DEFAULT_DEST",
          "serverNames": ["$REALITY_DEFAULT_SNI"],
          "privateKey": "$private_key",
          "shortIds": ["$short_id"]
        }
      }
    }
  ],
  "outbounds": [
    {"protocol": "freedom", "tag": "direct"}
  ]
}
EOF
}

kml_configure_xray() {
  local uuid private_key public_key short_id port existing
  existing="$(kml_state_get '.reality.uuid')"
  uuid="${existing:-$(kml_uuid)}"
  private_key="$(kml_state_get '.reality.private_key')"
  public_key="$(kml_state_get '.reality.public_key')"
  if [[ -z "$private_key" || -z "$public_key" ]]; then
    read -r private_key public_key < <(kml_xray_keys)
  fi
  short_id="$(kml_state_get '.reality.short_id')"
  [[ -n "$short_id" ]] || short_id="$(openssl rand -hex 4)"
  port="$(kml_state_get '.reality.port')"
  [[ -n "$port" ]] || port="$(kml_choose_port "Reality" tcp)"

  kml_xray_render_config "$uuid" "$private_key" "$short_id" "$port" > "$KML_XRAY_CONFIG_DIR/config.json"
  jq empty "$KML_XRAY_CONFIG_DIR/config.json"
  "$KML_BIN_DIR/xray" run -test -config "$KML_XRAY_CONFIG_DIR/config.json" >"$KML_LOG_DIR/xray-config-test.log" 2>&1 \
    || kml_die "Reality 配置测试失败，未启动服务。日志：$KML_LOG_DIR/xray-config-test.log"

  kml_state_set_string '.reality.uuid' "$uuid"
  kml_state_set_string '.reality.private_key' "$private_key"
  kml_state_set_string '.reality.public_key' "$public_key"
  kml_state_set_string '.reality.short_id' "$short_id"
  kml_state_set_number '.reality.port' "$port"
  kml_state_set_string '.reality.sni' "$REALITY_DEFAULT_SNI"
  kml_state_set_string '.reality.dest' "$REALITY_DEFAULT_DEST"
  kml_state_set_string '.reality.fingerprint' "$REALITY_FINGERPRINT"
}
