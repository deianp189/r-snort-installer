#!/bin/bash
set -euo pipefail      # -o pipefail evita que los errores en un pipe pasen desapercibidos

echo "🧹 Limpiando instalación previa de R-Snort..."

########################################################################
# 1. Eliminar R-Snort y artefactos relacionados
########################################################################
sudo dpkg --purge r-snort 2>/dev/null || true

sudo rm -rf \
  /opt/r-snort \
  /etc/rsnort_iface \
  /etc/rsnort_borrar_ip \
  /etc/systemd/system/snort.service \
  /usr/local/snort \
  /usr/local/bin/snort \
  /var/log/snort_install.log

########################################################################
# 1-bis. Eliminar completamente libdaq (paquetes y compilaciones manuales)
########################################################################
echo "🧹 Limpiando libdaq…"

# 1-bis-A) Paquetes instalados con APT
sudo apt-get purge -y 'libdaq*' 2>/dev/null || true    # cubre libdaq3, libdaq-dev, etc.
sudo apt-get autoremove -y

# 1-bis-B) Copias compiladas a mano (por defecto van a /usr/local)
sudo rm -rf \
  /usr/local/lib/libdaq* \
  /usr/local/include/*daq* \
  /usr/local/lib/pkgconfig/libdaq.pc

# 1-bis-C) Fuentes descargadas durante el build
sudo rm -rf /opt/r-snort/software/libdaq

# Vuelve a generar la caché de librerías dinámicas
sudo ldconfig

########################################################################
# 2. Limpiar estado de dpkg/APT y recargar systemd
########################################################################
sudo dpkg --configure -a
sudo apt-get --fix-broken install -y
sudo systemctl daemon-reexec
sudo systemctl daemon-reload

echo "🧼 Instalación previa eliminada."

########################################################################
# 3. Borrar .deb anterior y generar uno nuevo
########################################################################
rm -f r-snort-deb.deb

echo "📦 Reconstruyendo paquete r-snort..."
dpkg-deb --build r-snort-deb r-snort-deb.deb

########################################################################
# 4. Verificación final
########################################################################
if [[ -f "r-snort-deb.deb" ]]; then
  echo "✅ Paquete .deb creado correctamente."
else
  echo "❌ Error: el paquete .deb no se generó correctamente."
  exit 1
fi
