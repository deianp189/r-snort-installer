#!/bin/bash
set -euo pipefail

LOG_FILE="/var/log/rsnort-install.log"
mkdir -p "$(dirname "$LOG_FILE")"
exec > >(tee -a "$LOG_FILE") 2>&1

echo "===================="
echo "📅 Instalación R-SNORT: $(date)"
echo "===================="

echo "🌐 [R-SNORT] Actualizando lista de paquetes..."
sudo apt update

echo "📦 [R-SNORT] Instalando dependencias base..."
sudo apt install --no-install-recommends -y \
  bash build-essential autoconf automake libtool cmake pkg-config \
  flex bison libfl-dev libpcre3-dev \
  libpcap-dev liblzma-dev xz-utils check \
  clamav clamav-daemon \
  libssl-dev

echo "✅ Dependencias de sistema instaladas."

# ────────────── Selección de interfaz de captura ──────────────
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

echo "$IFACE" | sudo tee /etc/rsnort_iface > /dev/null
echo "✅ Interfaz seleccionada: $IFACE (guardada en /etc/rsnort_iface)"

# ¿Hay que eliminar su IP?
ip_ifaces=($(ip -o -4 addr show | awk '!/ lo / {print $2}' | sort -u))
if ip addr show "$IFACE" | grep -q 'inet '; then
  if [[ "${#ip_ifaces[@]}" -le 1 ]]; then
    echo "⚠️  $IFACE es la única interfaz con IP activa."
    read -rp "❗ Si eliminas su IP podrías perder acceso por SSH. ¿Continuar? [s/N]: " resp
  else
    read -rp "¿Eliminar la IP de $IFACE para instalar R-Snort como módulo central? [s/N]: " resp
  fi
  [[ "$resp" =~ ^[sS]$ ]] && echo true  | sudo tee /etc/rsnort_borrar_ip > /dev/null \
                          || echo false | sudo tee /etc/rsnort_borrar_ip > /dev/null
else
  echo "ℹ️ $IFACE no tiene IP asignada."
  echo false | sudo tee /etc/rsnort_borrar_ip > /dev/null
fi

# ────────────── Instalación del paquete .deb ──────────────
if [[ ! -f r-snort-deb.deb ]]; then
  echo "❌ No se encontró el archivo r-snort-deb.deb"
  echo "➡️  Ejecuta: dpkg-deb --build r-snort-deb"
  exit 1
fi

echo "📦 Instalando paquete .deb..."
sudo dpkg -i r-snort-deb.deb || {
  echo "⚠️  Corrigiendo dependencias pendientes..."
  sudo apt --fix-broken install -y
}

if dpkg -s r-snort >/dev/null 2>&1; then
  echo "🚀 Lanzando instalador interno de R-Snort..."
  sudo /opt/r-snort/r-snort_installer.sh
else
  echo "❌ Error: el paquete r-snort no se instaló correctamente."
  exit 1
fi

echo "✅ Instalación de R-Snort completada con éxito."
