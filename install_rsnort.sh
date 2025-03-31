#!/bin/bash
set -e

echo "🌐 [R-SNORT] Actualizando lista de paquetes..."
sudo apt update

echo "📦 [R-SNORT] Instalando dependencias..."
sudo apt install -y bash build-essential libpcap-dev xz-utils liblzma-dev clamav clamav-daemon

echo "✅ [R-SNORT] Dependencias instaladas."

if [ ! -f r-snort-deb.deb ]; then
  echo "❌ [ERROR] No se encontró el archivo r-snort-deb.deb"
  echo "➡️  Ejecuta: dpkg-deb --build r-snort-deb"
  exit 1
fi

echo "📦 [R-SNORT] Instalando paquete .deb..."
sudo dpkg -i r-snort-deb.deb || {
  echo "⚠️  dpkg reportó errores. Intentando solucionarlos..."
  sudo apt --fix-broken install -y
}

echo "🎉 [R-SNORT] Instalación completa."
