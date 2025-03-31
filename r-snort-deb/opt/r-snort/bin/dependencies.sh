#!/bin/bash

dependencies_install() {
  log "Verificando dependencias del sistema..."

  local pkgs=(build-essential libpcap-dev xz-utils liblzma-dev clamav clamav-daemon)
  local faltantes=()

  for pkg in "${pkgs[@]}"; do
    if ! dpkg -s "$pkg" >/dev/null 2>&1; then
      faltantes+=("$pkg")
    fi
  done

  if (( ${#faltantes[@]} > 0 )); then
    error "Faltan las siguientes dependencias del sistema: ${faltantes[*]}. Instálalas manualmente con: sudo apt install ${faltantes[*]}"
  fi

  log "Todas las dependencias están satisfechas."
}
