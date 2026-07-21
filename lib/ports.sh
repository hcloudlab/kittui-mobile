#!/usr/bin/env bash
set -euo pipefail

kml_port_candidates() {
  case "$1" in
    tcp) printf '%s\n' "$REALITY_TCP_CANDIDATES" ;;
    udp) printf '%s\n' "$HYSTERIA_UDP_CANDIDATES" ;;
    *) return 1 ;;
  esac
}

kml_proto_upper() {
  printf '%s' "$1" | tr '[:lower:]' '[:upper:]'
}

kml_port_in_use() {
  local port="$1" proto="$2" flag
  [[ "$proto" == "udp" ]] && flag="-Hlunp" || flag="-Hltnp"
  ss $flag 2>/dev/null | awk -v port=":$port" '
    {
      for (i = 1; i <= NF; i++) {
        if ($i ~ port "$") { found = 1 }
      }
    }
    END { exit !found }
  '
}

kml_port_owner() {
  local port="$1" proto="$2" flag line owner
  [[ "$proto" == "udp" ]] && flag="-Hlunp" || flag="-Hltnp"
  line="$(ss $flag 2>/dev/null | awk -v port=":$port" '{for (i=1;i<=NF;i++) if ($i ~ port "$") {print; exit}}')"
  owner="$(grep -oE 'users:\(\("[^"]+"' <<<"$line" | head -n1 | sed -E 's/.*\("//;s/"$//')"
  printf '%s\n' "${owner:-unknown}"
}

kml_choose_port() {
  local label="$1" proto="$2" candidates first port owner
  candidates="$(kml_port_candidates "$proto")"
  first="$(awk '{print $1}' <<<"$candidates")"
  for port in $candidates; do
    if ! kml_port_in_use "$port" "$proto"; then
      if [[ "$port" != "$first" ]]; then
        owner="$(kml_port_owner "$first" "$proto")"
        kml_warn "检测到 ${first}/$(kml_proto_upper "$proto") 已被 ${owner} 占用，${label} 自动选择 ${port}/$(kml_proto_upper "$proto")。非 443 端口可能影响部分客户端或网络兼容性。"
      fi
      printf '%s\n' "$port"
      return 0
    fi
  done
  kml_die "${label} 无可用 $(kml_proto_upper "$proto") 端口。候选：$candidates"
}

kml_assert_listening() {
  local port="$1" proto="$2"
  if ! kml_port_in_use "$port" "$proto"; then
    kml_die "验证失败：未检测到 ${port}/$(kml_proto_upper "$proto") 监听。"
  fi
}
