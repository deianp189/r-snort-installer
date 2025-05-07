Este documento resume el hilo de depuración que tuvimos para **evitar
el error `DAQ_Msg_h`/`DAQ_PKT_FLAG_SIGNIFICANT_GROUPS`** al compilar Snort 3.

## Resumen del problema
* Existen versiones 2.x y 3.x de libdaq; Snort 3 requiere ≥ 3.0.
* Si las cabeceras 2.x permanecen en `/usr/local/include`, GCC mezcla
  cabeceras 2.x con librerías 3.x ⇒ símbolos ausentes.

## Solución implementada
1. `cleanup_old_daq` que purga todas las copias previas (APT + builds
   manuales).
2. Compilar libdaq ≥ 3.0 en **/usr/local**.
3. Exportar `PKG_CONFIG_PATH` con `/usr/local/lib/pkgconfig` al principio.
4. Verificaciones duras antes de compilar Snort (`pkg-config` + cabeceras).
5. Quitar la limpieza redundante dentro de `snort_install`.

## Módulos afectados (scripts bash)
* **package_install** – bloque *daq* recompuesto.
* **software_package_install** – llama a `cleanup_old_daq` antes del bucle.
* **snort_install** – verificación de versión sin borrar libdaq recién instalada.
* **cleanup_old_daq** – nuevo helper central.

## Comandos clave de depuración
```bash
pkg-config --modversion libdaq          # 3.0.19 esperado
pkg-config --cflags libdaq              # -I/usr/local/include ...
locate daq_common.h                     # solo en /usr/local/include
