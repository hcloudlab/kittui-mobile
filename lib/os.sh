#!/usr/bin/env bash
set -euo pipefail

kml_require_root() {
  [[ "$(id -u)" == "0" ]] || kml_die "请使用 root 权限运行，例如：sudo bash install.sh"
}

kml_arch() {
  local raw
  raw="$(uname -m)"
  case "$raw" in
    x86_64|amd64) printf 'amd64\n' ;;
    aarch64|arm64) printf 'arm64\n' ;;
    *) kml_die "不支持的 CPU 架构：$raw" ;;
  esac
}

kml_xray_asset() {
  case "$(kml_arch)" in
    amd64) printf 'Xray-linux-64.zip\n' ;;
    arm64) printf 'Xray-linux-arm64-v8a.zip\n' ;;
  esac
}

kml_hysteria_asset() {
  case "$(kml_arch)" in
    amd64) printf 'hysteria-linux-amd64\n' ;;
    arm64) printf 'hysteria-linux-arm64\n' ;;
  esac
}

kml_require_supported_os() {
  [[ -r /etc/os-release ]] || kml_die "无法读取 /etc/os-release"
  # shellcheck disable=SC1091
  source /etc/os-release
  case "${ID:-}" in
    ubuntu|debian) : ;;
    *) kml_die "当前仅支持 Ubuntu / Debian，检测到：${ID:-unknown}" ;;
  esac
  case "${VERSION_ID:-}" in
    22.04|24.04|11|12) : ;;
    *) kml_warn "未在 ${PRETTY_NAME:-当前系统} 上完成验证，继续前请谨慎。" ;;
  esac
}

kml_pkg_install() {
  export DEBIAN_FRONTEND=noninteractive
  apt-get update
  apt-get install -y --no-install-recommends "$@"
}

kml_install_dependencies() {
  kml_info "安装最小依赖：ca-certificates curl openssl jq iproute2 tar unzip"
  kml_pkg_install ca-certificates curl openssl jq iproute2 tar unzip
  if apt-get install -y --no-install-recommends qrencode; then
    kml_info "已安装可选依赖 qrencode，将生成独立二维码。"
  else
    kml_warn "qrencode 安装失败或不可用，将跳过二维码 PNG 生成。"
  fi
}

kml_detect_public_host() {
  local endpoint ip
  for endpoint in https://api.ipify.org https://ifconfig.me/ip https://icanhazip.com; do
    ip="$(curl -fsS --max-time 6 "$endpoint" 2>/dev/null | tr -d '[:space:]' || true)"
    if [[ -n "$ip" ]]; then
      printf '%s\n' "$ip"
      return 0
    fi
  done
  hostname -I 2>/dev/null | awk '{print $1}'
}
