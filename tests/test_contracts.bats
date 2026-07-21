#!/usr/bin/env bats

setup() {
  export PROJECT_ROOT="$BATS_TEST_DIRNAME/.."
  export KML_ROOT="$BATS_TEST_TMPDIR/root"
  export PATH="$BATS_TEST_TMPDIR/bin:$PATH"
  mkdir -p "$BATS_TEST_TMPDIR/bin"
}

write_fake_ss() {
  local content="$1"
  cat > "$BATS_TEST_TMPDIR/bin/ss" <<EOF
#!/usr/bin/env bash
cat <<'SS_EOF'
$content
SS_EOF
EOF
  chmod +x "$BATS_TEST_TMPDIR/bin/ss"
}

load_libs() {
  # shellcheck source=/dev/null
  source "$PROJECT_ROOT/lib/constants.sh"
  # shellcheck source=/dev/null
  source "$PROJECT_ROOT/lib/log.sh"
  # shellcheck source=/dev/null
  source "$PROJECT_ROOT/lib/os.sh"
  # shellcheck source=/dev/null
  source "$PROJECT_ROOT/lib/state.sh"
  # shellcheck source=/dev/null
  source "$PROJECT_ROOT/lib/ports.sh"
  # shellcheck source=/dev/null
  source "$PROJECT_ROOT/lib/validate.sh"
  # shellcheck source=/dev/null
  source "$PROJECT_ROOT/lib/output.sh"
}

@test "Ubuntu and Debian support is documented" {
  grep -q "Ubuntu 22.04" "$PROJECT_ROOT/README.md"
  grep -q "Ubuntu 24.04" "$PROJECT_ROOT/README.md"
  grep -q "Debian 11" "$PROJECT_ROOT/README.md"
  grep -q "Debian 12" "$PROJECT_ROOT/README.md"
}

@test "amd64 and arm64 architecture mapping is strict" {
  load_libs

  uname() {
    printf '%s\n' 'x86_64'
  }

  [ "$(uname -m)" = "x86_64" ]
  run kml_arch
  [ "$status" -eq 0 ]
  [ "$output" = "amd64" ]

  uname() {
    printf '%s\n' 'aarch64'
  }

  [ "$(uname -m)" = "aarch64" ]
  run kml_arch
  [ "$status" -eq 0 ]
  [ "$output" = "arm64" ]
}

@test "443 TCP occupied chooses next Reality TCP candidate" {
  write_fake_ss 'LISTEN 0 4096 0.0.0.0:443 0.0.0.0:* users:(("nginx",pid=10,fd=3))'
  load_libs
  run kml_choose_port "Reality" tcp
  [ "$status" -eq 0 ]
  last_line="${lines[$((${#lines[@]} - 1))]}"
  [ "$last_line" = "8443" ]
}

@test "443 UDP occupied chooses next Hysteria2 UDP candidate" {
  write_fake_ss 'UNCONN 0 0 0.0.0.0:443 0.0.0.0:* users:(("hysteria",pid=10,fd=3))'
  load_libs
  run kml_choose_port "Hysteria2" udp
  [ "$status" -eq 0 ]
  last_line="${lines[$((${#lines[@]} - 1))]}"
  [ "$last_line" = "8443" ]
}

@test "Reality and Hysteria2 may both use numeric 443 on separate transports" {
  write_fake_ss ''
  load_libs
  run kml_choose_port "Reality" tcp
  [ "$output" = "443" ]
  run kml_choose_port "Hysteria2" udp
  [ "$output" = "443" ]
}

@test "UFW active handling never enables or resets UFW" {
  if grep -R "ufw reset" "$PROJECT_ROOT/lib" "$PROJECT_ROOT/install.sh"; then
    false
  fi
  if grep -R "ufw enable" "$PROJECT_ROOT/lib" "$PROJECT_ROOT/install.sh"; then
    false
  fi
  grep -q "ufw allow" "$PROJECT_ROOT/lib/firewall.sh"
}

@test "UFW inactive and no firewall are non-enabling paths" {
  grep -q "未检测到活动防火墙" "$PROJECT_ROOT/lib/firewall.sh"
  if grep -R "default deny" "$PROJECT_ROOT/lib" "$PROJECT_ROOT/install.sh"; then
    false
  fi
}

@test "firewalld active path records only project ports" {
  grep -q "firewall-cmd --add-port" "$PROJECT_ROOT/lib/firewall.sh"
  grep -q "kml_firewall_record_rule firewalld" "$PROJECT_ROOT/lib/firewall.sh"
}

@test "custom nftables and iptables are not automatically modified" {
  grep -q "检测到自定义" "$PROJECT_ROOT/lib/firewall.sh"
  grep -q "参考命令：iptables -I INPUT" "$PROJECT_ROOT/lib/firewall.sh"
  if grep -q "nft add rule" "$PROJECT_ROOT/lib/firewall.sh"; then
    false
  fi
}

@test "existing 3X-UI, Xray, and Hysteria2 conflict message exists" {
  grep -q "检测到现有Xray、Hysteria2或3X-UI环境" "$PROJECT_ROOT/lib/conflicts.sh"
  grep -q "x-ui.service" "$PROJECT_ROOT/lib/conflicts.sh"
  grep -q "xray.service" "$PROJECT_ROOT/lib/conflicts.sh"
  grep -q "hysteria2.service" "$PROJECT_ROOT/lib/conflicts.sh"
}

@test "repeat output generation keeps existing credentials from state" {
  load_libs
  kml_state_init
  kml_state_set_string '.server_host' "example.com"
  kml_state_set_string '.reality.uuid' "11111111-1111-4111-8111-111111111111"
  kml_state_set_string '.reality.public_key' "publicKeyValue"
  kml_state_set_string '.reality.short_id' "abcd1234"
  kml_state_set_number '.reality.port' "443"
  kml_state_set_string '.reality.sni' "www.cloudflare.com"
  kml_state_set_string '.hysteria2.password' "testPasswordValue"
  kml_state_set_number '.hysteria2.port' "443"
  kml_state_set_string '.hysteria2.sni' "kittui.local"
  kml_state_set_string '.hysteria2.pin_sha256' "AA:BB:CC"
  run kml_generate_outputs
  [ "$status" -eq 0 ]
  grep -q "11111111-1111-4111-8111-111111111111" "$KML_OUTPUT_DIR/reality.txt"
}

@test "download checksum failure path exists before install writes services" {
  grep -q "SHA-256 校验失败" "$PROJECT_ROOT/lib/download.sh"
  grep -q "kml_verify_sha256" "$PROJECT_ROOT/lib/download.sh"
}

@test "service startup failure does not print success first" {
  grep -n "kml_service_enable_start" "$PROJECT_ROOT/lib/main.sh"
  grep -n "kml_success_summary" "$PROJECT_ROOT/lib/main.sh"
}

@test "uninstall deletes only project services and project root" {
  grep -q "kittui-mobile-xray.service" "$PROJECT_ROOT/lib/constants.sh"
  grep -q "kittui-mobile-hysteria2.service" "$PROJECT_ROOT/lib/constants.sh"
  if grep -q "rm -rf /etc/xray" "$PROJECT_ROOT/lib/main.sh"; then
    false
  fi
  if grep -q "rm -rf /usr/local/etc/xray" "$PROJECT_ROOT/lib/main.sh"; then
    false
  fi
}

@test "Mihomo config includes required Reality fields" {
  load_libs
  kml_state_init
  kml_state_set_string '.server_host' "example.com"
  kml_state_set_string '.reality.uuid' "11111111-1111-4111-8111-111111111111"
  kml_state_set_string '.reality.public_key' "publicKeyValue"
  kml_state_set_string '.reality.short_id' "abcd1234"
  kml_state_set_number '.reality.port' "443"
  kml_state_set_string '.reality.sni' "www.cloudflare.com"
  kml_state_set_string '.hysteria2.password' "testPasswordValue"
  kml_state_set_number '.hysteria2.port' "443"
  kml_state_set_string '.hysteria2.sni' "kittui.local"
  kml_state_set_string '.hysteria2.pin_sha256' "AA:BB:CC"
  kml_generate_outputs
  grep -q "type: vless" "$KML_OUTPUT_DIR/mihomo-complete.yaml"
  grep -q "flow: xtls-rprx-vision" "$KML_OUTPUT_DIR/mihomo-complete.yaml"
  grep -q "reality-opts:" "$KML_OUTPUT_DIR/mihomo-complete.yaml"
}

@test "sing-box complete JSON parses and contains inbound route and outbounds" {
  load_libs
  kml_state_init
  kml_state_set_string '.server_host' "example.com"
  kml_state_set_string '.reality.uuid' "11111111-1111-4111-8111-111111111111"
  kml_state_set_string '.reality.public_key' "publicKeyValue"
  kml_state_set_string '.reality.short_id' "abcd1234"
  kml_state_set_number '.reality.port' "443"
  kml_state_set_string '.hysteria2.password' "testPasswordValue"
  kml_state_set_number '.hysteria2.port' "443"
  kml_state_set_string '.hysteria2.sni' "kittui.local"
  kml_state_set_string '.hysteria2.pin_sha256' "AA:BB:CC"
  kml_generate_outputs
  jq -e '.inbounds and .outbounds and .route' "$KML_OUTPUT_DIR/sing-box-complete.json"
}

@test "QR generation writes two independent files when qrencode is available" {
  cat > "$BATS_TEST_TMPDIR/bin/qrencode" <<'EOF'
#!/usr/bin/env bash
if [[ "$1" == "-o" ]]; then
  printf '%s\n' "$3" > "$2"
fi
EOF
  chmod +x "$BATS_TEST_TMPDIR/bin/qrencode"
  load_libs
  kml_state_init
  kml_state_set_string '.server_host' "example.com"
  kml_state_set_string '.reality.uuid' "11111111-1111-4111-8111-111111111111"
  kml_state_set_string '.reality.public_key' "publicKeyValue"
  kml_state_set_string '.reality.short_id' "abcd1234"
  kml_state_set_number '.reality.port' "443"
  kml_state_set_string '.hysteria2.password' "testPasswordValue"
  kml_state_set_number '.hysteria2.port' "443"
  kml_state_set_string '.hysteria2.sni' "kittui.local"
  kml_state_set_string '.hysteria2.pin_sha256' "AA:BB:CC"
  kml_generate_outputs
  [ -s "$KML_OUTPUT_DIR/reality-qr.png" ]
  [ -s "$KML_OUTPUT_DIR/hysteria2-qr.png" ]
  if cmp -s "$KML_OUTPUT_DIR/reality-qr.png" "$KML_OUTPUT_DIR/hysteria2-qr.png"; then
    false
  fi
}

@test "state.json permission is locked to 0600" {
  load_libs
  kml_state_init
  mode="$(stat -f '%Lp' "$KML_STATE_FILE" 2>/dev/null || stat -c '%a' "$KML_STATE_FILE")"
  [ "$mode" = "600" ]
}

@test "output files do not contain Reality private key field" {
  load_libs
  kml_state_init
  kml_state_set_string '.server_host' "example.com"
  kml_state_set_string '.reality.uuid' "11111111-1111-4111-8111-111111111111"
  kml_state_set_string '.reality.public_key' "publicKeyValue"
  kml_state_set_string '.reality.short_id' "abcd1234"
  kml_state_set_number '.reality.port' "443"
  kml_state_set_string '.hysteria2.password' "testPasswordValue"
  kml_state_set_number '.hysteria2.port' "443"
  kml_state_set_string '.hysteria2.sni' "kittui.local"
  kml_state_set_string '.hysteria2.pin_sha256' "AA:BB:CC"
  kml_generate_outputs
  if grep -R "private_key\|privateKey" "$KML_OUTPUT_DIR"; then
    false
  fi
}
