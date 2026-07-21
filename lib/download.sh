#!/usr/bin/env bash
set -euo pipefail

kml_sha256() {
  sha256sum "$1" | awk '{print $1}'
}

kml_verify_sha256() {
  local file="$1" expected="$2" actual
  [[ -n "$expected" ]] || kml_die "缺少 SHA-256 校验值：$file"
  actual="$(kml_sha256 "$file")"
  [[ "$actual" == "$expected" ]] || kml_die "SHA-256 校验失败：$file expected=$expected actual=$actual"
}

kml_download() {
  local url="$1" dest="$2"
  curl -fL --retry 3 --connect-timeout 12 "$url" -o "$dest"
}

kml_install_xray_binary() {
  local asset url dgst_url tmp expected
  if [[ -x "$KML_BIN_DIR/xray" ]]; then
    return 0
  fi
  asset="$(kml_xray_asset)"
  url="https://github.com/XTLS/Xray-core/releases/download/$XRAY_VERSION/$asset"
  dgst_url="$url.dgst"
  tmp="$(mktemp -d)"
  kml_info "下载固定版本 Xray：$XRAY_VERSION / $asset"
  kml_download "$url" "$tmp/$asset"
  kml_download "$dgst_url" "$tmp/$asset.dgst"
  expected="$(grep -m1 '^SHA2-256=' "$tmp/$asset.dgst" | sed -E 's/^SHA2-256=[[:space:]]*//' | tr -d '[:space:]')"
  kml_verify_sha256 "$tmp/$asset" "$expected"
  unzip -q "$tmp/$asset" -d "$tmp/xray"
  install -m 0755 "$tmp/xray/xray" "$KML_BIN_DIR/xray"
  jq --arg version "$XRAY_VERSION" --arg asset "$asset" --arg sha "$expected" '.binaries.xray={version:$version,asset:$asset,sha256:$sha,path:"/opt/kittui-mobile/bin/xray"}' "$KML_STATE_FILE" > "$tmp/state"
  install -m 0600 "$tmp/state" "$KML_STATE_FILE"
  rm -rf "$tmp"
}

kml_install_hysteria_binary() {
  local asset url hashes_url tmp expected
  if [[ -x "$KML_BIN_DIR/hysteria" ]]; then
    return 0
  fi
  asset="$(kml_hysteria_asset)"
  url="https://github.com/apernet/hysteria/releases/download/$HYSTERIA_VERSION_URL/$asset"
  hashes_url="https://github.com/apernet/hysteria/releases/download/$HYSTERIA_VERSION_URL/hashes.txt"
  tmp="$(mktemp -d)"
  kml_info "下载固定版本 Hysteria2：$HYSTERIA_VERSION / $asset"
  kml_download "$url" "$tmp/$asset"
  kml_download "$hashes_url" "$tmp/hashes.txt"
  expected="$(awk -v asset="build/$asset" '$2 == asset {print $1; exit}' "$tmp/hashes.txt")"
  kml_verify_sha256 "$tmp/$asset" "$expected"
  install -m 0755 "$tmp/$asset" "$KML_BIN_DIR/hysteria"
  jq --arg version "$HYSTERIA_VERSION" --arg asset "$asset" --arg sha "$expected" '.binaries.hysteria2={version:$version,asset:$asset,sha256:$sha,path:"/opt/kittui-mobile/bin/hysteria"}' "$KML_STATE_FILE" > "$tmp/state"
  install -m 0600 "$tmp/state" "$KML_STATE_FILE"
  rm -rf "$tmp"
}
