#!/usr/bin/env bash
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=constants.sh
source "$PROJECT_DIR/lib/constants.sh"
# shellcheck source=log.sh
source "$PROJECT_DIR/lib/log.sh"
# shellcheck source=os.sh
source "$PROJECT_DIR/lib/os.sh"
# shellcheck source=state.sh
source "$PROJECT_DIR/lib/state.sh"
# shellcheck source=ports.sh
source "$PROJECT_DIR/lib/ports.sh"
# shellcheck source=conflicts.sh
source "$PROJECT_DIR/lib/conflicts.sh"
# shellcheck source=download.sh
source "$PROJECT_DIR/lib/download.sh"
# shellcheck source=users.sh
source "$PROJECT_DIR/lib/users.sh"
# shellcheck source=firewall.sh
source "$PROJECT_DIR/lib/firewall.sh"
# shellcheck source=service.sh
source "$PROJECT_DIR/lib/service.sh"
# shellcheck source=xray.sh
source "$PROJECT_DIR/lib/xray.sh"
# shellcheck source=hysteria2.sh
source "$PROJECT_DIR/lib/hysteria2.sh"
# shellcheck source=validate.sh
source "$PROJECT_DIR/lib/validate.sh"
# shellcheck source=output.sh
source "$PROJECT_DIR/lib/output.sh"

kml_usage() {
  cat <<'EOF'
KitTUI Mobile Lite

Usage:
  sudo bash install.sh install [--force-replace] [--server-host IP_OR_DOMAIN] [--hysteria-domain DOMAIN] [--manage-firewall|--no-firewall]
  sudo kittui-mobile status
  sudo kittui-mobile show
  sudo kittui-mobile repair
  sudo kittui-mobile uninstall

Notes:
  默认部署 Reality 443/TCP 和 Hysteria2 443/UDP。TCP 与 UDP 分别检测，允许同时使用数字端口 443。
EOF
}

kml_parse_install_args() {
  KML_FORCE_REPLACE="false"
  KML_FIREWALL_MODE="auto"
  KML_SERVER_HOST=""
  KML_HYSTERIA_DOMAIN=""
  while [[ "$#" -gt 0 ]]; do
    case "$1" in
      --force-replace) KML_FORCE_REPLACE="true" ;;
      --manage-firewall) KML_FIREWALL_MODE="auto" ;;
      --no-firewall) KML_FIREWALL_MODE="none" ;;
      --server-host)
        shift
        KML_SERVER_HOST="${1:-}"
        ;;
      --hysteria-domain)
        shift
        KML_HYSTERIA_DOMAIN="${1:-}"
        ;;
      -h|--help) kml_usage; exit 0 ;;
      *) kml_die "未知参数：$1" ;;
    esac
    shift || true
  done
}

kml_install() {
  kml_parse_install_args "$@"
  kml_require_root
  kml_require_supported_os
  kml_abort_on_conflicts_without_force "$KML_FORCE_REPLACE"
  kml_install_dependencies
  kml_state_init
  if [[ -n "$KML_SERVER_HOST" ]]; then
    kml_state_set_string '.server_host' "$KML_SERVER_HOST"
  fi
  kml_guard_existing_environment "$KML_FORCE_REPLACE"
  kml_ensure_service_user "$KML_XRAY_USER"
  kml_ensure_service_user "$KML_HYSTERIA_USER"
  kml_install_xray_binary
  kml_install_hysteria_binary
  kml_configure_xray
  kml_configure_hysteria2 "$KML_HYSTERIA_DOMAIN"
  kml_set_service_permissions
  kml_write_systemd_units
  kml_firewall_apply_port "$(kml_state_get '.reality.port')" tcp "KitTUI Mobile Reality" "$KML_FIREWALL_MODE"
  kml_firewall_apply_port "$(kml_state_get '.hysteria2.port')" udp "KitTUI Mobile Hysteria2" "$KML_FIREWALL_MODE"
  if ! kml_service_enable_start "$KML_XRAY_SERVICE"; then
    kml_rollback_if_force
    kml_die "Reality 服务启动失败。日志：$KML_LOG_DIR/$KML_XRAY_SERVICE.log"
  fi
  if ! kml_service_enable_start "$KML_HYSTERIA_SERVICE"; then
    kml_rollback_if_force
    kml_die "Hysteria2 服务启动失败。日志：$KML_LOG_DIR/$KML_HYSTERIA_SERVICE.log"
  fi
  kml_install_command
  kml_generate_outputs
  if ! kml_validate_install; then
    kml_rollback_if_force
    kml_die "安装验证失败，未显示成功。"
  fi
  kml_success_summary
}

kml_success_summary() {
  cat <<EOF

KitTUI Mobile Lite 安装完成

Reality
状态：active
端口：$(kml_state_get '.reality.port')/TCP

Hysteria2
状态：active
端口：$(kml_state_get '.hysteria2.port')/UDP

查看节点：
sudo kittui-mobile show

检查状态：
sudo kittui-mobile status

卸载：
sudo kittui-mobile uninstall

输出目录：
$KML_OUTPUT_DIR

脚本无法修改VPS厂商的云防火墙，请确认云控制台已放行显示的TCP和UDP端口。
EOF
}

kml_status() {
  kml_state_init
  printf 'KitTUI Mobile Lite 状态\n\n'
  printf 'Reality service: '
  systemctl is-active "$KML_XRAY_SERVICE" 2>/dev/null || true
  printf 'Hysteria2 service: '
  systemctl is-active "$KML_HYSTERIA_SERVICE" 2>/dev/null || true
  printf '\n端口：Reality %s/TCP, Hysteria2 %s/UDP\n' "$(kml_state_get '.reality.port')" "$(kml_state_get '.hysteria2.port')"
  printf '输出目录：%s\n' "$KML_OUTPUT_DIR"
}

kml_show() {
  [[ -s "$KML_OUTPUT_DIR/share-links.txt" ]] || kml_die "尚未生成节点输出，请先运行 install 或 repair。"
  cat "$KML_OUTPUT_DIR/share-links.txt"
}

kml_repair() {
  kml_require_root
  kml_state_init
  kml_ensure_service_user "$KML_XRAY_USER"
  kml_ensure_service_user "$KML_HYSTERIA_USER"
  kml_install_xray_binary
  kml_install_hysteria_binary
  [[ -s "$KML_XRAY_CONFIG_DIR/config.json" ]] || kml_configure_xray
  [[ -s "$KML_HYSTERIA_CONFIG_DIR/config.yaml" ]] || kml_configure_hysteria2 ""
  kml_set_service_permissions
  kml_write_systemd_units
  kml_service_enable_start "$KML_XRAY_SERVICE" || kml_die "Reality 修复启动失败。"
  kml_service_enable_start "$KML_HYSTERIA_SERVICE" || kml_die "Hysteria2 修复启动失败。"
  kml_generate_outputs
  kml_validate_install
  kml_info "修复完成。"
}

kml_uninstall() {
  kml_require_root
  if [[ -s "$KML_STATE_FILE" ]]; then
    kml_firewall_remove_recorded
  fi
  systemctl disable --now "$KML_XRAY_SERVICE" >/dev/null 2>&1 || true
  systemctl disable --now "$KML_HYSTERIA_SERVICE" >/dev/null 2>&1 || true
  rm -f "/etc/systemd/system/$KML_XRAY_SERVICE" "/etc/systemd/system/$KML_HYSTERIA_SERVICE"
  systemctl daemon-reload >/dev/null 2>&1 || true
  rm -rf "$KML_ROOT"
  rm -f "$KML_COMMAND"
  userdel "$KML_XRAY_USER" >/dev/null 2>&1 || true
  userdel "$KML_HYSTERIA_USER" >/dev/null 2>&1 || true
  kml_info "已卸载 KitTUI Mobile Lite。未修改 3X-UI、用户原有 Xray/Hysteria2、Web 服务、SSH、Fail2ban、sysctl 或其他防火墙规则。"
}

kml_main() {
  local command="${1:-install}"
  shift || true
  case "$command" in
    install) kml_install "$@" ;;
    status) kml_status ;;
    show) kml_show ;;
    repair) kml_repair ;;
    uninstall) kml_uninstall ;;
    -h|--help|help) kml_usage ;;
    *) kml_die "未知命令：$command" ;;
  esac
}
