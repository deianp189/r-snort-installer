#!/bin/bash

snort_config() {
  local CONFIG_DIR="$1"
  local INSTALL_DIR="$2"
  local IFACE="$3"

  log "Copiando configuración..."
  mkdir -p "$INSTALL_DIR/etc/snort"
  cp "$CONFIG_DIR/snort.lua" "$INSTALL_DIR/etc/snort/"
  cp "$CONFIG_DIR/custom.rules" "$INSTALL_DIR/etc/snort/"

  if [[ -f "$CONFIG_DIR/blocklist.rules" ]]; then
  cp "$CONFIG_DIR/blocklist.rules" "$INSTALL_DIR/etc/snort/"
else
  log "No se encontró blocklist.rules, creando archivo vacío..."
  touch "$INSTALL_DIR/etc/snort/blocklist.rules"
fi
  
  mkdir -p "$INSTALL_DIR/etc/snort/reputation" "$INSTALL_DIR/etc/snort/snort3-community-rules"
  touch "$INSTALL_DIR/etc/snort/reputation/interface.info"
  tar -xzf "$CONFIG_DIR/snort3-community-rules.tar.gz" -C "$INSTALL_DIR/etc/snort/snort3-community-rules" --strip-components=1

  if [ -f /etc/systemd/system/snort.service ]; then
    cp /etc/systemd/system/snort.service /etc/systemd/system/snort.service.bak
    log "Backup del servicio original guardado."
  fi

  cat > /etc/systemd/system/snort.service <<EOF
[Unit]
Description=Snort NIDS Daemon
After=network.target

[Service]
ExecStart=$INSTALL_DIR/bin/snort -c $INSTALL_DIR/etc/snort/snort.lua -i $IFACE -A alert_fast
ExecReload=/bin/kill -HUP \${MAINPID}
Restart=always
User=root
Group=root
LimitCORE=infinity
LimitNOFILE=65536
LimitNPROC=65536
PIDFile=/var/run/snort.pid

[Install]
WantedBy=multi-user.target
EOF

  systemctl daemon-reexec
  systemctl daemon-reload
  systemctl enable snort.service
  systemctl restart snort.service || error "No se pudo iniciar Snort."
  sleep 2
  systemctl status snort.service --no-pager
  success "Servicio Snort configurado y activo."
}
