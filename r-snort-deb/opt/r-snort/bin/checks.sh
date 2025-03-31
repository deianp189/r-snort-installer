#!/bin/bash

check_root() {
  [ "$(id -u)" -eq 0 ] || error "Este script debe ejecutarse como root."
}

interface_selection() {
  log "Detectando la primera interfaz Ethernet activa con IP..."

  # Detectar interfaces Ethernet activas con IP
  mapfile -t interfaces < <(
    ip -o -4 addr show up | awk '$2 ~ /^e/ {print $2}' | uniq
  )

  if (( ${#interfaces[@]} == 0 )); then
    error "No se encontró ninguna interfaz Ethernet activa con IP. Verifica la conexión de red."
  fi

  IFACE="${interfaces[0]}"
  log "Interfaz detectada automáticamente: $IFACE"
}
