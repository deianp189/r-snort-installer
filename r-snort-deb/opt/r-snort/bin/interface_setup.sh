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

  # Contar interfaces activas con dirección IP (excluyendo loopback)
  ip_ifaces=($(ip -o -4 addr show | awk '!/ lo / {print $2}' | sort -u))
  num_ip_ifaces=${#ip_ifaces[@]}
  BORRAR_IP=$(cat /etc/rsnort_borrar_ip 2>/dev/null || echo "false")

  if ip addr show "$iface" | grep -q 'inet '; then
    if [[ "$BORRAR_IP" == "true" && "$num_ip_ifaces" -gt 1 ]]; then
      log "Eliminando IP de $iface para sniffeo como módulo central..."
      ip addr flush dev "$iface"
    elif [[ "$BORRAR_IP" == "true" && "$num_ip_ifaces" -le 1 ]]; then
      log "⚠️ Se pidió eliminar IP pero $iface es la única interfaz con IP. Conservando IP por seguridad."
    else
      log "Conservando la IP de $iface por elección del usuario."
    fi
  else
    log "$iface no tiene IP asignada. Nada que eliminar."
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
