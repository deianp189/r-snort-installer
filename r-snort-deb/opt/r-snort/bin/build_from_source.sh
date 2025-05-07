#!/bin/bash

###############################################################################
# 1.  package_install  – instala cada tarball individual
###############################################################################
package_install() {
  local archivo="$1"

  #-- Validación básica
  [[ "$archivo" == *.tar.gz ]] && gzip -t "$archivo" \
    || error "Archivo corrupto: $archivo"

  log "Instalando: $(basename "$archivo")"
  tar -xf "$archivo"
  dir=$(find . -mindepth 1 -maxdepth 1 -type d | head -n 1) \
    || error "No se encontró directorio tras descomprimir"

  cd "$dir" || error "No se pudo entrar en $dir"

  case "$archivo" in
    ##########################################################################
    # 1.a  DAQ  – compila únicamente libdaq ≥ 3 y la instala en /usr/local
    ##########################################################################
    *daq*)
      cleanup_old_daq                          # ← evita colisiones
      log "⚙️  Compilando libdaq…"

      [[ -x bootstrap ]] && ./bootstrap || \
      { [[ -f configure.ac && ! -f configure ]] && autoreconf -fi; }

      ./configure --prefix=/usr/local --disable-static --enable-shared \
        || error "configure de DAQ falló"
      make -j"$(nproc)"
      sudo make install || error "Fallo al instalar DAQ"
      sudo ldconfig

      #-- Verificación final
      daq_ver=$(pkg-config --modversion libdaq 2>/dev/null || echo 0)
      [[ "${daq_ver%%.*}" -lt 3 ]] && \
        error "libdaq $daq_ver instalada (< 3.0)"
      hdr_dir=$(pkg-config --cflags libdaq | sed -n 's/^-I\([^ ]*\).*$/\1/p')
      [[ ! -f "$hdr_dir/daq_module_api.h" ]] && \
        error "Cabeceras de DAQ no halladas en $hdr_dir"
      ;;

    ##########################################################################
    # 1.b  LuaJIT  (sin cambios de fondo, solo cambia el prefijo)
    ##########################################################################
    *luajit*)
      make -j"$(nproc)"
      sudo make install PREFIX=/usr/local
      ;;

    ##########################################################################
    # 1.c  OpenSSL  (sin cambios de fondo, solo cambia el prefijo)
    ##########################################################################
    *openssl*)
      target=$(uname -m | grep -q aarch64 && echo linux-aarch64 || echo linux-generic32)
      ./Configure --prefix=/usr/local --openssldir=/etc/ssl "$target"
      make -j"$(nproc)"
      sudo make install
      ;;

    ##########################################################################
    # 1.d  Resto de librerías genéricas
    ##########################################################################
    *)
      [[ -f configure.ac && ! -f configure ]] && autoreconf -fi
      if [[ -f configure ]]; then
        ./configure --prefix=/usr/local --enable-shared
      else
        cmake . -DCMAKE_INSTALL_PREFIX=/usr/local
      fi
      make -j"$(nproc)"
      sudo make install
      ;;
  esac

  cd ..
  rm -rf "$dir"
  success "$(basename "$archivo") instalado."
}


###############################################################################
# 2.  software_package_install  – instala todos los tarballs salvo Snort
###############################################################################
software_package_install() {
  cd "$SOFTWARE_DIR"
  cleanup_old_daq                          # ← primera limpieza global
  log "Ordenando paquetes para instalar dependencias…"

  for f in $(ls *.tar.gz *.tar.xz 2>/dev/null | sort | grep -vi snort); do
    package_install "$f"
  done

  log "Dependencias listas; Snort se compilará más tarde."

  #-- Se mantiene tu lógica de ClamAV
  for pkg in clamav clamav-daemon; do
    if ! dpkg -s "$pkg" >/dev/null 2>&1; then
      log "[!] Falta '$pkg'; instala manualmente con: sudo apt install $pkg"
    fi
  done

  freshclam || log "No se pudo actualizar la base de firmas ahora"
  systemctl enable clamav-freshclam clamav-daemon
  systemctl restart clamav-daemon
  systemctl is-active --quiet clamav-daemon \
    && success "ClamAV activo." || log "ClamAV instalado pero inactivo."
}
