#!/bin/bash

###############################################################################
# 1.  package_install  – instala cada tarball individual
###############################################################################
package_install() {
  local archivo="$1"
  [[ "$archivo" == *.tar.gz ]] && gzip -t "$archivo" \
    || error "Archivo corrupto: $archivo"

  log "Instalando: $(basename "$archivo")"
  tar -xf "$archivo"
  local dir
  dir=$(find . -mindepth 1 -maxdepth 1 -type d | head -n 1) \
       || error "No se encontró directorio tras descomprimir"
  cd "$dir"

  case "$archivo" in
    *daq*)
      cleanup_old_daq
      log "⚙️  Compilando libdaq…"
      [[ -x bootstrap ]] && ./bootstrap || { [[ -f configure.ac && ! -f configure ]] && autoreconf -fi; }
      ./configure --prefix=/usr/local --disable-static --enable-shared
      make -j"$(nproc)"
      sudo make install
      sudo ldconfig
      ;;
    *luajit*)
      make -j"$(nproc)"
      sudo make install PREFIX=/usr/local
      ;;
    # OpenSSL ya no se compila: simplemente se omite
    *openssl*)
      log "⏭  Omitiendo OpenSSL – se usará el de la distribución"
      cd ..
      rm -rf "$dir"
      return 0
      ;;
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

  for f in $(ls *.tar.* 2>/dev/null | sort | grep -Eiv 'snort|openssl'); do
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
