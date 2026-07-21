#!/usr/bin/env bash
set -euo pipefail

kml_write_systemd_units() {
  cat > "/etc/systemd/system/$KML_XRAY_SERVICE" <<EOF
[Unit]
Description=KitTUI Mobile Lite Xray Reality
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User=$KML_XRAY_USER
Group=$KML_XRAY_USER
ExecStart=$KML_BIN_DIR/xray run -config $KML_XRAY_CONFIG_DIR/config.json
Restart=on-failure
RestartSec=3
LimitNOFILE=1048576
AmbientCapabilities=CAP_NET_BIND_SERVICE
CapabilityBoundingSet=CAP_NET_BIND_SERVICE
NoNewPrivileges=true
PrivateTmp=true
ProtectSystem=strict
ProtectHome=true
ReadWritePaths=$KML_LOG_DIR

[Install]
WantedBy=multi-user.target
EOF

  cat > "/etc/systemd/system/$KML_HYSTERIA_SERVICE" <<EOF
[Unit]
Description=KitTUI Mobile Lite Hysteria2
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User=$KML_HYSTERIA_USER
Group=$KML_HYSTERIA_USER
ExecStart=$KML_BIN_DIR/hysteria server -c $KML_HYSTERIA_CONFIG_DIR/config.yaml
Restart=on-failure
RestartSec=3
LimitNOFILE=1048576
AmbientCapabilities=CAP_NET_BIND_SERVICE
CapabilityBoundingSet=CAP_NET_BIND_SERVICE
NoNewPrivileges=true
PrivateTmp=true
ProtectSystem=strict
ProtectHome=true
ReadWritePaths=$KML_LOG_DIR

[Install]
WantedBy=multi-user.target
EOF
  systemctl daemon-reload
}

kml_service_enable_start() {
  local service="$1"
  local log_file="$KML_LOG_DIR/$service.log"
  systemctl enable "$service" >"$log_file" 2>&1
  if ! systemctl restart "$service" >>"$log_file" 2>&1; then
    systemctl status "$service" >>"$log_file" 2>&1 || true
    return 1
  fi
  systemctl is-active --quiet "$service"
}

kml_install_command() {
  local app_dir="$KML_ROOT/app"
  install -d -m 0750 "$app_dir"
  rm -rf "${app_dir:?}/lib"
  cp -a "$PROJECT_DIR/lib" "$app_dir/lib"
  install -m 0755 "$PROJECT_DIR/install.sh" "$app_dir/install.sh"
  cat > "$KML_COMMAND" <<EOF
#!/usr/bin/env bash
set -euo pipefail
PROJECT_DIR="$app_dir"
source "$app_dir/lib/main.sh"
kml_main "\$@"
EOF
  chmod 0755 "$KML_COMMAND"
}
