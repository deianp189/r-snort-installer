#!/bin/bash

check_root() {
  [ "$(id -u)" -eq 0 ] || error "Este script debe ejecutarse como root."
}

interface_selection() {
  if [[ -f /etc/rsnort_iface ]]; then
    IFACE=$(cat /etc/rsnort_iface)
    log "Interfaz cargada desde configuración previa: $IFACE"
  else
    error "No se encontró el archivo /etc/rsnort_iface con la interfaz seleccionada."
  fi
}

