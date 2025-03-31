#!/bin/bash
set -e

echo "🌐 [R-SNORT] Actualizando lista de paquetes..."
sudo apt update

echo "📦 [R-SNORT] Instalando dependencias..."
sudo apt install -y bash build-essential libpcap-dev xz-utils liblzma-dev clamav clamav-daemon

echo "✅ [R-SNORT] Dependencias instaladas."

# Buscar interfaces Ethernet conectadas
echo "🔎 Buscando interfaces Ethernet disponibles..."
interfaces=($(ip -o link show | awk -F': ' '/^[0-9]+: e/ {print $2}'))

if [[ ${#interfaces[@]} -eq 0 ]]; then
  echo "❌ No se encontraron interfaces Ethernet. ¿Está el adaptador conectado?"
  exit 1
fi

echo "🌐 Interfaces disponibles:"
for i in "${!interfaces[@]}"; do
  echo "  [$i] ${interfaces[$i]}"
done

read -rp "➡️  Elige la interfaz para analizar tráfico (la del switch): " index
IFACE="${interfaces[$index]}"

# Guardar la interfaz en archivo para que el script dentro del .deb la use
echo "$IFACE" | sudo tee /etc/rsnort_iface > /dev/null

# Verificación
echo "✅ Interfaz seleccionada: $IFACE"
echo

# Instalación del paquete
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
