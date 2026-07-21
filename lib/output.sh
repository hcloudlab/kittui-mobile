#!/usr/bin/env bash
set -euo pipefail

kml_uri_encode() {
  jq -rn --arg value "$1" '$value|@uri'
}

kml_server_host() {
  local host
  host="$(kml_state_get '.server_host')"
  [[ -n "$host" ]] || host="$(kml_detect_public_host)"
  [[ -n "$host" ]] || kml_die "无法检测 VPS 公网地址，请使用 --server-host 指定。"
  kml_state_set_string '.server_host' "$host"
  printf '%s\n' "$host"
}

kml_reality_link() {
  local host uuid port public_key short_id sni
  host="$(kml_server_host)"
  uuid="$(kml_state_get '.reality.uuid')"
  port="$(kml_state_get '.reality.port')"
  public_key="$(kml_state_get '.reality.public_key')"
  short_id="$(kml_state_get '.reality.short_id')"
  sni="$(kml_state_get '.reality.sni')"
  printf 'vless://%s@%s:%s?encryption=none&security=reality&sni=%s&fp=%s&pbk=%s&sid=%s&type=tcp&flow=xtls-rprx-vision#KitTUI-Mobile-Reality\n' \
    "$uuid" "$host" "$port" "$sni" "$REALITY_FINGERPRINT" "$public_key" "$short_id"
}

kml_hysteria_link_for_scheme() {
  local scheme="$1" secure="$2" host password port sni pin query
  host="$(kml_server_host)"
  password="$(kml_uri_encode "$(kml_state_get '.hysteria2.password')")"
  port="$(kml_state_get '.hysteria2.port')"
  sni="$(kml_uri_encode "$(kml_state_get '.hysteria2.sni')")"
  pin="$(kml_uri_encode "$(kml_state_get '.hysteria2.pin_sha256')")"
  query="insecure=1&sni=$sni"
  if [[ "$secure" == "true" ]]; then
    query="$query&pinSHA256=$pin"
  fi
  printf '%s://%s@%s:%s/?%s#KitTUI-Mobile-Hysteria2\n' "$scheme" "$password" "$host" "$port" "$query"
}

kml_write_mihomo() {
  local host reality_port hysteria_port uuid public_key short_id password sni pin
  host="$(kml_server_host)"
  reality_port="$(kml_state_get '.reality.port')"
  hysteria_port="$(kml_state_get '.hysteria2.port')"
  uuid="$(kml_state_get '.reality.uuid')"
  public_key="$(kml_state_get '.reality.public_key')"
  short_id="$(kml_state_get '.reality.short_id')"
  password="$(kml_state_get '.hysteria2.password')"
  sni="$(kml_state_get '.hysteria2.sni')"
  pin="$(kml_state_get '.hysteria2.pin_sha256')"

  cat > "$KML_OUTPUT_DIR/mihomo-provider.yaml" <<EOF
proxies:
  - name: KitTUI-Mobile-Reality
    type: vless
    server: $host
    port: $reality_port
    uuid: $uuid
    network: tcp
    tls: true
    udp: true
    flow: xtls-rprx-vision
    servername: $REALITY_DEFAULT_SNI
    client-fingerprint: chrome
    reality-opts:
      public-key: $public_key
      short-id: $short_id
  - name: KitTUI-Mobile-Hysteria2
    type: hysteria2
    server: $host
    port: $hysteria_port
    password: $password
    sni: $sni
    skip-cert-verify: true
    fingerprint: $pin
EOF

  cat > "$KML_OUTPUT_DIR/mihomo-complete.yaml" <<EOF
mixed-port: 7890
allow-lan: false
mode: rule
log-level: info
proxies:
  - name: KitTUI-Mobile-Reality
    type: vless
    server: $host
    port: $reality_port
    uuid: $uuid
    network: tcp
    tls: true
    udp: true
    flow: xtls-rprx-vision
    servername: $REALITY_DEFAULT_SNI
    client-fingerprint: chrome
    reality-opts:
      public-key: $public_key
      short-id: $short_id
  - name: KitTUI-Mobile-Hysteria2
    type: hysteria2
    server: $host
    port: $hysteria_port
    password: $password
    sni: $sni
    skip-cert-verify: true
    fingerprint: $pin
proxy-groups:
  - name: PROXY
    type: select
    proxies:
      - KitTUI-Mobile-Reality
      - KitTUI-Mobile-Hysteria2
      - DIRECT
rules:
  - MATCH,PROXY
EOF
}

kml_write_sing_box() {
  local host reality_port hysteria_port uuid public_key short_id password sni pin
  host="$(kml_server_host)"
  reality_port="$(kml_state_get '.reality.port')"
  hysteria_port="$(kml_state_get '.hysteria2.port')"
  uuid="$(kml_state_get '.reality.uuid')"
  public_key="$(kml_state_get '.reality.public_key')"
  short_id="$(kml_state_get '.reality.short_id')"
  password="$(kml_state_get '.hysteria2.password')"
  sni="$(kml_state_get '.hysteria2.sni')"
  pin="$(kml_state_get '.hysteria2.pin_sha256')"

  jq -n \
    --arg host "$host" --argjson reality_port "$reality_port" --argjson hysteria_port "$hysteria_port" \
    --arg uuid "$uuid" --arg public_key "$public_key" --arg short_id "$short_id" \
    --arg password "$password" --arg sni "$sni" --arg pin "$pin" \
    '[
      {type:"vless",tag:"KitTUI-Mobile-Reality",server:$host,server_port:$reality_port,uuid:$uuid,flow:"xtls-rprx-vision",packet_encoding:"xudp",tls:{enabled:true,server_name:"www.cloudflare.com",utls:{enabled:true,fingerprint:"chrome"},reality:{enabled:true,public_key:$public_key,short_id:$short_id}}},
      {type:"hysteria2",tag:"KitTUI-Mobile-Hysteria2",server:$host,server_port:$hysteria_port,password:$password,tls:{enabled:true,server_name:$sni,insecure:true,certificate_public_key_sha256:$pin}}
    ]' > "$KML_OUTPUT_DIR/sing-box-outbounds.json"

  jq -n --slurpfile outbounds "$KML_OUTPUT_DIR/sing-box-outbounds.json" \
    '{log:{level:"info"},inbounds:[{type:"mixed",tag:"mixed-in",listen:"127.0.0.1",listen_port:2080}],outbounds:($outbounds[0] + [{type:"direct",tag:"direct"}]),route:{rules:[],final:"KitTUI-Mobile-Reality"}}' \
    > "$KML_OUTPUT_DIR/sing-box-complete.json"
}

kml_generate_outputs() {
  local reality_link hy2_secure hy2_compat hy2_short_secure hy2_short_compat
  install -d -m 0750 "$KML_OUTPUT_DIR"
  reality_link="$(kml_reality_link)"
  hy2_secure="$(kml_hysteria_link_for_scheme hysteria2 true)"
  hy2_compat="$(kml_hysteria_link_for_scheme hysteria2 false)"
  hy2_short_secure="$(kml_hysteria_link_for_scheme hy2 true)"
  hy2_short_compat="$(kml_hysteria_link_for_scheme hy2 false)"

  printf '%s' "$reality_link" > "$KML_OUTPUT_DIR/reality.txt"
  {
    printf '# 安全增强版，包含 pinSHA256\n%s' "$hy2_secure"
    printf '# 兼容版，仅 insecure=1\n%s' "$hy2_compat"
    printf '# hy2 安全增强版\n%s' "$hy2_short_secure"
    printf '# hy2 兼容版\n%s' "$hy2_short_compat"
  } > "$KML_OUTPUT_DIR/hysteria2.txt"
  {
    cat "$KML_OUTPUT_DIR/reality.txt"
    grep -E '^(hysteria2|hy2)://' "$KML_OUTPUT_DIR/hysteria2.txt"
  } > "$KML_OUTPUT_DIR/share-links.txt"
  cp "$KML_OUTPUT_DIR/share-links.txt" "$KML_OUTPUT_DIR/subscription-raw.txt"
  base64 < "$KML_OUTPUT_DIR/subscription-raw.txt" | tr -d '\n' > "$KML_OUTPUT_DIR/subscription-base64.txt"
  printf '\n' >> "$KML_OUTPUT_DIR/subscription-base64.txt"

  kml_write_mihomo
  kml_write_sing_box

  cat > "$KML_OUTPUT_DIR/install-summary.txt" <<EOF
KitTUI Mobile Lite 安装摘要

Reality: $(kml_state_get '.reality.port')/TCP
Hysteria2: $(kml_state_get '.hysteria2.port')/UDP
输出目录：$KML_OUTPUT_DIR

脚本无法修改 VPS 厂商的云防火墙，请确认云控制台已放行上述 TCP 和 UDP 端口。
EOF

  kml_validate_outputs

  if command -v qrencode >/dev/null 2>&1; then
    qrencode -o "$KML_OUTPUT_DIR/reality-qr.png" "$reality_link"
    qrencode -o "$KML_OUTPUT_DIR/hysteria2-qr.png" "$hy2_secure"
  fi
}
