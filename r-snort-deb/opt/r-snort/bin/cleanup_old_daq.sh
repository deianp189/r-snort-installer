###############################################################################
# 0.  cleanup_old_daq  – borra cualquier instalación previa de libdaq
###############################################################################
cleanup_old_daq() {
  log "🧹  Eliminando restos antiguos de libdaq…"
  #-- Paquetes APT
  sudo apt-get purge -y 'libdaq*'  >/dev/null 2>&1 || true
  #-- Builds manuales en /usr/local
  sudo rm -f \
      /usr/local/include/daq*.h \
      /usr/local/lib/libdaq* \
      /usr/local/lib/pkgconfig/libdaq.pc \
      /usr/lib/pkgconfig/libdaq*.pc
  sudo ldconfig
}
