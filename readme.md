# R-SNORT Installer

Instalador automatizado de Snort 3.1.84 optimizado para Raspberry Pi 5 con arquitectura ARM64. Este proyecto proporciona un sistema completo de detección de intrusos (NIDS) configurado para brindar seguridad a redes SOHO, orientado a entornos experimentales, educativos o de pequeñas empresas.

## Características

- Compilación de Snort 3 y todas sus dependencias desde el código fuente.
- Configuración avanzada de `snort.lua` para entorno Linux y redes asimétricas.
- Integración con ClamAV para detección de malware.
- Servicio systemd completamente configurado y habilitado.
- Reglas comunitarias y personalizadas integradas.
- Swap temporal habilitado para evitar errores por falta de memoria.
- Validación de dependencias y estado del sistema.
- Preprocesadores activos.

## Requisitos

- Raspberry Pi 5 (ARM64) con Ubuntu Server o Desktop 24.04.
- Usuario con privilegios de sudo.
- Conexión a internet durante la instalación.
- Al menos 8 GB de almacenamiento libre.

## Estructura del proyecto

```
.
├── install_rsnort.sh            # Script de instalación principal
├── r-snort-deb/                 # Estructura de paquete .deb personalizado
│   ├── DEBIAN/                  # Scripts de mantenimiento del paquete
│   └── opt/r-snort/            
│       ├── bin/                # Scripts internos
│       ├── configuracion/      # Archivos de reglas y configuración
│       └── software/           # Tarballs del software a compilar
└── r-snort-deb.deb             # Paquete .deb instalable
```

## Instalación

### Opcion A: desde código fuente

```bash
git clone https://github.com/deianp189/r-snort-installer.git
cd r-snort-installer
sudo ./install_rsnort.sh
```

Este script:
- Actualiza el sistema
- Instala dependencias con `apt`
- Instala `r-snort-deb.deb` o lo construye si no existe
- Ejecuta todo el flujo de instalación automatizado

### Opcion B: instalación directa del paquete .deb

```bash
sudo dpkg -i r-snort-deb.deb
sudo apt --fix-broken install -y
```

## Uso del sistema

El servicio Snort queda instalado como `snort.service` y se activa al arranque:

```bash
sudo systemctl status snort
sudo journalctl -u snort -f
```

Los binarios, configuraciones y reglas están instalados bajo `/usr/local/snort/`.

## Actualizaciones y mantenimiento

- Para actualizar firmas de ClamAV:
  ```bash
  sudo freshclam
  ```

- Para editar reglas personalizadas:
  ```bash
  sudo nano /usr/local/snort/etc/snort/custom.rules
  sudo systemctl restart snort
  ```

- Para desinstalar el sistema:
  ```bash
  sudo systemctl stop snort
  sudo systemctl disable snort
  sudo rm -rf /usr/local/snort /etc/systemd/system/snort.service /var/log/snort
  sudo apt remove --purge r-snort -y
  sudo apt autoremove -y
  ```

## Versionado

Este repositorio utiliza [semver.org](https://semver.org/) como esquema de versiones:

- `MAJOR`: cambios incompatibles con versiones anteriores.
- `MINOR`: mejoras funcionales sin romper compatibilidad.
- `PATCH`: correcciones de errores o mejoras menores.

### Version actual

```
R-SNORT Installer v1.0.0
```

## Contribuciones

Pull requests, sugerencias y mejoras son bienvenidas. Este proyecto está pensado como base para automatizar Snort 3 en entornos ARM64, por lo que puede extenderse con nuevas funcionalidades, soporte para otras arquitecturas o integraciones.

## Autor

**Deian Orlando Petrovics T.**

Estudiante de Ingeniería Informática. Proyecto desarrollado como parte del Trabajo Fin de Grado, orientado a la automatización de sistemas de detección de intrusos en entornos de bajo coste y arquitectura ARM.

## Licencia

Este proyecto está licenciado bajo los términos de la licencia UAL.

