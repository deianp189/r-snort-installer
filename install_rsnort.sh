#!/bin/bash
set -e

LOG_FILE="/var/log/rsnort-install.log"
mkdir -p "$(dirname "$LOG_FILE")"
exec > >(tee -a "$LOG_FILE") 2>&1

echo "===================="
echo "📅 Instalación R-SNORT: $(date)"
echo "===================="

echo "🌐 [R-SNORT] Actualizando lista de paquetes..."
sudo apt update

echo "📦 [R-SNORT] Instalando dependencias..."
sudo apt install --no-install-recommends -y bash build-essential libpcap-dev xz-utils liblzma-dev clamav clamav-daemon

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

# Guardar la interfaz seleccionada
echo "$IFACE" | sudo tee /etc/rsnort_iface > /dev/null
echo "✅ Interfaz seleccionada: $IFACE"
echo "➡️ Guardado en /etc/rsnort_iface"

# Detectar interfaces con IP (excluyendo loopback)
ip_ifaces=($(ip -o -4 addr show | awk '!/ lo / {print $2}' | sort -u))
num_ip_ifaces=${#ip_ifaces[@]}

if ip addr show "$IFACE" | grep -q 'inet '; then
  if [[ "$num_ip_ifaces" -le 1 ]]; then
    echo "⚠️  $IFACE es la única interfaz con IP activa."
    echo "❗ Si eliminas su IP, podrías perder acceso por SSH o Internet."
    read -rp "¿Quieres eliminar su IP para instalar R-Snort como módulo central? [s/N]: " resp
    if [[ "$resp" =~ ^[sS]$ ]]; then
      echo "true" | sudo tee /etc/rsnort_borrar_ip > /dev/null
    else
      echo "false" | sudo tee /etc/rsnorrar_ip > /dev/null
    fi
  else
    read -rp "¿Quieres eliminar la IP de $IFACE para instalar R-Snort como módulo central? [s/N]: " resp
    if [[ "$resp" =~ ^[sS]$ ]]; then
      echo "true" | sudo tee /etc/rsnort_borrar_ip > /dev/null
    else
      echo "false" | sudo tee /etc/rsnort_borrar_ip > /dev/null
    fi
  fi
else
  echo "ℹ️ La interfaz $IFACE no tiene IP asignada."
  echo "false" | sudo tee /etc/rsnort_borrar_ip > /dev/null
fi

echo "📦 [R-SNORT] Instalando herramientas de compilación adicionales..."
sudo apt install --no-install-recommends -y autoconf automake libtool cmake pkg-config

echo "📦 [R-SNORT] Instalando biblioteca de tests 'check'..."
sudo apt install --no-install-recommends -y check

# Instalación del paquete .deb
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

# Verifica instalación y ejecuta el instalador interno
if dpkg -s r-snort >/dev/null 2>&1; then
  echo "🚀 Ejecutando instalador interno de R-Snort..."
  sudo /opt/r-snort/r-snort_installer.sh
else
  echo "❌ Error: el paquete r-snort no se instaló correctamente."
  exit 1
fi

echo "✅ Instalación de R-Snort completada con éxito."
