#!/bin/bash

interface_setup() {
  local iface="$1"

  log "Verificando estado de la interfaz $iface..."
  state=$(ip link show "$iface" | grep -o 'state [A-Z]*' | awk '{print $2}')

  if [[ "$state" != "UP" ]]; then
    log "La interfaz $iface está DOWN. Activando..."
    ip link set dev "$iface" up || error "No se pudo activar la interfaz $iface."
  else
    log "La interfaz $iface ya está UP."
  fi

  # Verificar si tiene IP y eliminarla (para sniffeo puro)
  if ip addr show "$iface" | grep -q 'inet '; then
    log "Eliminando IP de $iface para sniffeo sin interferencias..."
    ip addr flush dev "$iface"
  fi

  # Establecer modo promiscuo si no lo está
  if ! ip link show "$iface" | grep -q PROMISC; then
    log "Activando modo promiscuo en $iface..."
    ip link set "$iface" promisc on || error "No se pudo activar modo promiscuo en $iface."
  else
    log "$iface ya está en modo promiscuo."
  fi

  success "Interfaz $iface preparada para análisis de red."
}

[[ -n "${IFACE:-}" ]] && interface_setup "$IFACE"
