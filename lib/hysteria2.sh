#!/usr/bin/env bash
set -euo pipefail

kml_random_password() {
  openssl rand -base64 32 | tr -d '=+/[:space:]' | cut -c1-32
}

kml_cert_fingerprint_colon() {
  openssl x509 -noout -fingerprint -sha256 -in "$1" | sed -E 's/^sha256 Fingerprint=//I'
}

kml_hysteria_render_config() {
  local password="$1" port="$2" cert="$3" key="$4"
  cat <<EOF
listen: :$port
tls:
  cert: $cert
  key: $key
auth:
  type: password
  password: "$password"
masquerade:
  type: proxy
  proxy:
    url: https://www.cloudflare.com/
    rewriteHost: true
EOF
}

kml_domain_mode_guard() {
  local domain="$1"
  [[ -n "$domain" ]] || return 0
  for binary in nginx caddy apache2 httpd; do
    if command -v "$binary" >/dev/null 2>&1; then
      kml_die "检测到已有 $binary。域名模式不会覆盖现有 Web 服务配置，已终止。"
    fi
  done
  kml_die "当前版本仅实现无域名自签名模式；域名模式必须先完成 ACME 安全接入设计。"
}

kml_configure_hysteria2() {
  local domain="$1" password port cert key fingerprint
  kml_domain_mode_guard "$domain"
  password="$(kml_state_get '.hysteria2.password')"
  [[ -n "$password" ]] || password="$(kml_random_password)"
  port="$(kml_state_get '.hysteria2.port')"
  [[ -n "$port" ]] || port="$(kml_choose_port "Hysteria2" udp)"

  cert="$KML_CERT_DIR/hysteria2.crt"
  key="$KML_CERT_DIR/hysteria2.key"
  if [[ ! -s "$cert" || ! -s "$key" ]]; then
    openssl req -x509 -newkey rsa:2048 -sha256 -days 3650 -nodes \
      -keyout "$key" \
      -out "$cert" \
      -subj "/CN=$HYSTERIA_DEFAULT_SNI" >/dev/null 2>&1
  fi
  fingerprint="$(kml_cert_fingerprint_colon "$cert")"
  kml_hysteria_render_config "$password" "$port" "$cert" "$key" > "$KML_HYSTERIA_CONFIG_DIR/config.yaml"

  kml_state_set_string '.hysteria2.password' "$password"
  kml_state_set_number '.hysteria2.port' "$port"
  kml_state_set_string '.hysteria2.sni' "$HYSTERIA_DEFAULT_SNI"
  kml_state_set_string '.hysteria2.cert' "$cert"
  kml_state_set_string '.hysteria2.key' "$key"
  kml_state_set_string '.hysteria2.pin_sha256' "$fingerprint"
}
