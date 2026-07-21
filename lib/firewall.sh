#!/usr/bin/env bash
set -euo pipefail

kml_firewall_detect() {
  if command -v ufw >/dev/null 2>&1 && ufw status 2>/dev/null | grep -qi '^Status: active'; then
    printf 'ufw\n'
  elif command -v firewall-cmd >/dev/null 2>&1 && firewall-cmd --state >/dev/null 2>&1; then
    printf 'firewalld\n'
  elif command -v nft >/dev/null 2>&1 && nft list ruleset 2>/dev/null | grep -q .; then
    printf 'nftables\n'
  elif command -v iptables >/dev/null 2>&1 && iptables -S 2>/dev/null | grep -q -- '^-A'; then
    printf 'iptables\n'
  else
    printf 'none\n'
  fi
}

kml_firewall_record_rule() {
  local kind="$1" value="$2"
  kml_state_append_json '.firewall.created_rules' "$(jq -n --arg kind "$kind" --arg value "$value" '{kind:$kind,value:$value}')"
}

kml_firewall_apply_port() {
  local port="$1" proto="$2" label="$3" mode="$4" detected
  detected="$(kml_firewall_detect)"
  kml_state_set_string '.firewall.detected' "$detected"
  kml_state_set_string '.firewall.mode' "$mode"
  if [[ "$mode" == "none" ]]; then
    kml_warn "已指定 --no-firewall，未修改防火墙。请手动放行 ${port}/$(kml_proto_upper "$proto")。"
    return 0
  fi
  case "$detected" in
    ufw)
      if ! ufw status numbered | grep -Fq "${port}/${proto}"; then
        ufw allow "$port/$proto" comment "$label"
        kml_firewall_record_rule ufw "$port/$proto"
      fi
      ;;
    firewalld)
      if ! firewall-cmd --query-port="$port/$proto" >/dev/null 2>&1; then
        firewall-cmd --add-port="$port/$proto" --permanent
        firewall-cmd --reload
        kml_firewall_record_rule firewalld "$port/$proto"
      fi
      ;;
    nftables|iptables)
      kml_warn "检测到自定义 $detected 规则，默认不自动修改。请确认放行 ${port}/$(kml_proto_upper "$proto")。"
      printf '参考命令：iptables -I INPUT -p %s --dport %s -j ACCEPT\n' "$proto" "$port"
      ;;
    none)
      kml_warn "未检测到活动防火墙，脚本不会启用防火墙。请同时检查 VPS 云防火墙。"
      ;;
  esac
}

kml_firewall_remove_recorded() {
  [[ -s "$KML_STATE_FILE" ]] || return 0
  jq -c '.firewall.created_rules[]?' "$KML_STATE_FILE" | while read -r rule; do
    local kind value
    kind="$(jq -r '.kind' <<<"$rule")"
    value="$(jq -r '.value' <<<"$rule")"
    case "$kind" in
      ufw)
        command -v ufw >/dev/null 2>&1 && ufw delete allow "$value" || true
        ;;
      firewalld)
        command -v firewall-cmd >/dev/null 2>&1 && firewall-cmd --remove-port="$value" --permanent && firewall-cmd --reload || true
        ;;
    esac
  done
}
