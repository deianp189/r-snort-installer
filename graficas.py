import pandas as pd
import matplotlib.pyplot as plt
import os

GRAF_DIR = "graficas"
INFORME_MD = "informe.md"

def cargar_csv(ruta):
    with open(ruta, encoding="utf-8") as f:
        lines = f.readlines()

    header_line = None
    for i, line in enumerate(lines):
        if line.strip().split(';')[0].strip('"').lower() == "time":
            header_line = i
            break

    if header_line is None:
        raise ValueError(f"No se encontró encabezado 'time' en {ruta}")

    df = pd.read_csv(ruta, skiprows=header_line, sep=';')
    df.columns = [col.strip().strip('"') for col in df.columns]
    df["time"] = pd.to_datetime(df["time"], format="%d-%m %H:%M:%S", errors="coerce")
    df.set_index("time", inplace=True)
    return df

def graficar_comparacion(df1, df2, columna, titulo, ylabel, filename, md_lines):
    plt.figure(figsize=(12, 6))
    if df1 is not None and columna in df1.columns:
        plt.plot(df1.index, df1[columna], label='Snort apagado')
    if df2 is not None and columna in df2.columns:
        plt.plot(df2.index, df2[columna], label='Snort encendido')
    plt.title(titulo)
    plt.xlabel("Tiempo")
    plt.ylabel(ylabel)
    plt.legend()
    plt.grid(True)
    plt.tight_layout()
    full_path = os.path.join(GRAF_DIR, filename)
    plt.savefig(full_path)
    print(f"Gráfica guardada como: {full_path}")
    plt.close()

    md_lines.append(f"## {titulo}\n")
    md_lines.append(f"**{ylabel}.**\n")
    md_lines.append(f"![{titulo}]({full_path})\n")

def main():
    os.makedirs(GRAF_DIR, exist_ok=True)
    
    ruta_snort_off = "snort_off_semicolon.csv"
    ruta_snort_on = "snort_on_semicolon.csv"

    df_off = cargar_csv(ruta_snort_off) if os.path.exists(ruta_snort_off) else None
    df_on = cargar_csv(ruta_snort_on) if os.path.exists(ruta_snort_on) else None

    columnas = {
        "total usage:usr": ("Uso de CPU del usuario (%)", "% CPU", "cpu_usr.png"),
        "total usage:sys": ("Uso de CPU del sistema (%)", "% CPU", "cpu_sys.png"),
        "total usage:idl": ("CPU inactiva (%)", "% CPU", "cpu_idle.png"),
        "used": ("Memoria usada (bytes)", "Bytes", "mem_used.png"),
        "dsk/total:read": ("Lectura de disco (B/s)", "Bytes/s", "disk_read.png"),
        "dsk/total:writ": ("Escritura de disco (B/s)", "Bytes/s", "disk_write.png"),
        "net/total:recv": ("Red: Bytes recibidos por segundo", "Bytes/s", "net_recv.png"),
        "net/total:send": ("Red: Bytes enviados por segundo", "Bytes/s", "net_send.png"),
        "csw": ("Context switches por segundo", "csw/s", "context_switch.png"),
    }

    md_lines = [
        "# Informe de rendimiento de R-Snort\n",
        "Este informe compara métricas de sistema con Snort encendido y apagado, usando los datos de `dstat`.\n"
    ]

    for col, info in columnas.items():
        titulo, ylabel, filename = info
        if ((df_off is not None and col in df_off.columns) or
            (df_on is not None and col in df_on.columns)):
            graficar_comparacion(df_off, df_on, col, titulo, ylabel, filename, md_lines)
        else:
            print(f"Columna '{col}' no disponible en los CSV.")

    with open(INFORME_MD, 'w', encoding='utf-8') as f:
        f.write('\n'.join(md_lines))
    print(f"Informe generado como: {INFORME_MD}")

if __name__ == "__main__":
    main()