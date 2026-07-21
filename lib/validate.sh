#!/usr/bin/env bash
set -euo pipefail

kml_validate_yaml_basic() {
  local file="$1"
  awk '
    /^[[:space:]]*\t/ { exit 2 }
    /^[^#[:space:]][^:]*$/ { exit 3 }
    { next }
  ' "$file" || kml_die "YAML 基础语法检查失败：$file"
}

kml_validate_outputs() {
  jq empty "$KML_OUTPUT_DIR/sing-box-outbounds.json"
  jq empty "$KML_OUTPUT_DIR/sing-box-complete.json"
  kml_validate_yaml_basic "$KML_OUTPUT_DIR/mihomo-provider.yaml"
  kml_validate_yaml_basic "$KML_OUTPUT_DIR/mihomo-complete.yaml"
  for file in share-links.txt reality.txt hysteria2.txt subscription-raw.txt subscription-base64.txt mihomo-complete.yaml mihomo-provider.yaml sing-box-complete.json sing-box-outbounds.json install-summary.txt; do
    [[ -s "$KML_OUTPUT_DIR/$file" ]] || kml_die "输出文件缺失或为空：$file"
  done
  if grep -R "private_key\\|privateKey" "$KML_OUTPUT_DIR" >/dev/null 2>&1; then
    kml_die "输出目录疑似泄露 Reality 私钥，已停止。"
  fi
}

kml_validate_install() {
  local reality_port hysteria_port
  "$KML_BIN_DIR/xray" run -test -config "$KML_XRAY_CONFIG_DIR/config.json" >/dev/null 2>&1 \
    || kml_die "Reality 配置测试失败。"
  systemctl is-active --quiet "$KML_XRAY_SERVICE" || kml_die "Reality 服务未 active。"
  systemctl is-active --quiet "$KML_HYSTERIA_SERVICE" || kml_die "Hysteria2 服务未 active。"
  reality_port="$(kml_state_get '.reality.port')"
  hysteria_port="$(kml_state_get '.hysteria2.port')"
  kml_assert_listening "$reality_port" tcp
  kml_assert_listening "$hysteria_port" udp
  kml_validate_outputs
}
