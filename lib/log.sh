#!/usr/bin/env bash
set -euo pipefail

kml_now() {
  date '+%Y-%m-%d %H:%M:%S'
}

kml_info() {
  printf '[%s] %s\n' "$(kml_now)" "$*"
}

kml_warn() {
  printf '[%s] 警告：%s\n' "$(kml_now)" "$*" >&2
}

kml_error() {
  printf '[%s] 错误：%s\n' "$(kml_now)" "$*" >&2
}

kml_die() {
  kml_error "$*"
  exit 1
}
