#!/usr/bin/env bash
set -euo pipefail

kml_service_exists() {
  systemctl list-unit-files "$1" >/dev/null 2>&1 || systemctl status "$1" >/dev/null 2>&1
}

kml_path_exists_nonempty() {
  [[ -e "$1" ]] || return 1
  if [[ -d "$1" ]]; then
    find "$1" -mindepth 1 -maxdepth 1 2>/dev/null | read -r _
  else
    [[ -s "$1" ]]
  fi
}

kml_detect_conflicts() {
  local conflicts=()
  for service in xray.service hysteria2.service x-ui.service; do
    if kml_service_exists "$service"; then
      conflicts+=("service:$service")
    fi
  done
  if pgrep -fa 'x-ui|3x-ui|3X-UI' >/dev/null 2>&1; then
    conflicts+=("process:3X-UI")
  fi
  for path in /usr/local/etc/xray /etc/xray /etc/hysteria /opt/kittui; do
    if kml_path_exists_nonempty "$path"; then
      conflicts+=("path:$path")
    fi
  done
  if [[ -d "$KML_ROOT" && ! -s "$KML_STATE_FILE" ]]; then
    conflicts+=("path:$KML_ROOT without KitTUI Mobile state")
  fi
  if kml_service_exists "$KML_XRAY_SERVICE" && [[ ! -s "$KML_STATE_FILE" ]]; then
    conflicts+=("service:$KML_XRAY_SERVICE without state")
  fi
  if kml_service_exists "$KML_HYSTERIA_SERVICE" && [[ ! -s "$KML_STATE_FILE" ]]; then
    conflicts+=("service:$KML_HYSTERIA_SERVICE without state")
  fi
  printf '%s\n' "${conflicts[@]:-}"
}

kml_backup_conflict_path() {
  local item="$1" stamp="$2" src dest
  case "$item" in
    path:*) src="${item#path:}" ;;
    service:*) src="/etc/systemd/system/${item#service:}" ;;
    *) return 0 ;;
  esac
  [[ -e "$src" ]] || return 0
  dest="$KML_BACKUP_DIR/$stamp$(tr '/' '_' <<<"$src")"
  cp -a "$src" "$dest"
  kml_state_append_json '.backups' "$(jq -n --arg source "$src" --arg backup "$dest" --arg at "$stamp" '{source:$source, backup:$backup, created_at:$at}')"
  printf '  - %s -> %s\n' "$src" "$dest"
}

kml_guard_existing_environment() {
  local force="$1" stamp conflicts item
  mapfile -t conflicts < <(kml_detect_conflicts)
  [[ "${#conflicts[@]}" -eq 0 || -z "${conflicts[0]:-}" ]] && return 0
  if [[ "$force" != "true" ]]; then
    printf '\n检测到现有Xray、Hysteria2或3X-UI环境。为避免覆盖已有节点，本次安装已取消。\n\n' >&2
    printf '检测结果：\n' >&2
    printf '  - %s\n' "${conflicts[@]}" >&2
    printf '\n如确认要在备份后继续，请显式使用 --force-replace。\n' >&2
    exit 1
  fi
  stamp="$(date '+%Y%m%d-%H%M%S')"
  kml_info "已启用 --force-replace，先创建备份并列出检测对象。"
  printf '准备替换或绕过的对象：\n'
  printf '  - %s\n' "${conflicts[@]}"
  printf '备份路径：%s\n' "$KML_BACKUP_DIR"
  for item in "${conflicts[@]}"; do
    kml_backup_conflict_path "$item" "$stamp"
  done
  kml_state_set_bool '.force_replace' true
}

kml_abort_on_conflicts_without_force() {
  local force="$1" conflicts
  mapfile -t conflicts < <(kml_detect_conflicts)
  [[ "${#conflicts[@]}" -eq 0 || -z "${conflicts[0]:-}" ]] && return 0
  [[ "$force" == "true" ]] && return 0
  printf '\n检测到现有Xray、Hysteria2或3X-UI环境。为避免覆盖已有节点，本次安装已取消。\n\n' >&2
  printf '检测结果：\n' >&2
  printf '  - %s\n' "${conflicts[@]}" >&2
  printf '\n如确认要在备份后继续，请显式使用 --force-replace。\n' >&2
  exit 1
}

kml_restore_backups() {
  [[ -s "$KML_STATE_FILE" ]] || return 0
  jq -c '.backups[]?' "$KML_STATE_FILE" | while read -r backup; do
    local source copy
    source="$(jq -r '.source' <<<"$backup")"
    copy="$(jq -r '.backup' <<<"$backup")"
    [[ -e "$copy" ]] || continue
    rm -rf "$source"
    cp -a "$copy" "$source"
  done
}

kml_rollback_if_force() {
  if [[ "$(kml_state_get '.force_replace')" == "true" ]]; then
    kml_warn "新服务验证失败，正在按备份记录回滚。"
    kml_restore_backups
  fi
}
