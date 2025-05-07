#!/bin/bash

###############################################################################
# 3.  snort_install  – compila e instala Snort 3
###############################################################################
snort_install() {
  local SOFTWARE_DIR="$1"
  local INSTALL_DIR="$2"

  log "Preparando instalación de Snort 3…"

  cd "$SOFTWARE_DIR"
  tar -xzf snort3.tar.gz
  cd "$(find . -maxdepth 1 -type d -name 'snort3*' | head -n 1)"

  #–– Fix histórico NUMTHREADS
  sed -i 's/\[ \"\\$NUMTHREADS\" -lt \"\\$MINTHREADS\" \]/[ \"${NUMTHREADS:-0}\" -lt \"${MINTHREADS:-1}\" ]/' configure_cmake.sh

  export CXXFLAGS="-Wno-deprecated-declarations"
  export PKG_CONFIG_PATH="/usr/local/lib/pkgconfig:/usr/lib/pkgconfig${PKG_CONFIG_PATH:+:$PKG_CONFIG_PATH}"

  #–– Verificación dura de libdaq ≥ 3
  daq_ver=$(pkg-config --modversion libdaq 2>/dev/null || echo 0)
  [[ "${daq_ver%%.*}" -lt 3 ]] && error "libdaq $daq_ver detectada (< 3.0). La instalación de dependencias falló."
  hdr_dir=$(pkg-config --cflags libdaq | sed -n 's/^-I\([^ ]*\).*$/\1/p')
  [[ ! -f "$hdr_dir/daq_module_api.h" ]] && error "Cabeceras de DAQ no halladas en $hdr_dir"

  ./configure_cmake.sh --prefix="$INSTALL_DIR"
  cd build
  temp_swap_if_necessary

  log "⌛ Compilando Snort 3…"
  make -j"$(nproc)" || error "Fallo en make"
  sudo make install
  sudo ldconfig
  sudo ln -sf "$INSTALL_DIR/bin/snort" /usr/local/bin/snort
  success "Snort 3 instalado con éxito."
}

