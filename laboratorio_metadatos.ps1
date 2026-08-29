# ============================================================
# Laboratorio de Seguridad de la Información - Metadatos
# Script recopilatorio de comandos (PowerShell / Windows)
# Integrantes: Sebastian Urrego, Andres Baquero, Julian Cristancho
#
# Requisito previo: exiftool debe estar instalado y accesible
# como 'exiftool' en el PATH (descargar de exiftool.org,
# renombrar exiftool(-k).exe a exiftool.exe y agregarlo al PATH).
# ============================================================

# ---- Variables (ajusta los nombres de archivo segun tu caso) ----
$IMG1 = "1000184727.jpg"        # Foto Samsung A35
$IMG2 = "image0.jpeg"           # Foto iPhone 16 Pro
$DOC  = "informeTEST.docx"      # Documento Word a analizar

# Identificación del equipo en cada captura
Write-Output "sebastian urrego andres baquero julian cristancho"

# ============================================================
# 1. METADATOS DE IMAGENES
# ============================================================

Write-Output "== Metadatos completos de $IMG1 =="
exiftool $IMG1

Write-Output "== Metadatos completos de $IMG2 =="
exiftool $IMG2

Write-Output "== Verificar GPS (esperado: sin datos) =="
exiftool -gps:all $IMG1
exiftool -gps:all $IMG2

Write-Output "== Comparacion directa entre ambas imagenes =="
exiftool -Make -Model -Software -DateTimeOriginal -ImageSize -FileSize $IMG1 $IMG2

Write-Output "== Extraer thumbnail embebido =="
exiftool -b -ThumbnailImage $IMG1 > thumb_extraido.jpg

# ============================================================
# 2. HASH DE IMAGENES (integridad de evidencia)
# ============================================================

Write-Output "== Hash ANTES de modificar metadatos =="
Get-FileHash $IMG1 -Algorithm SHA256

Write-Output "== Modificar un metadato de prueba =="
exiftool -overwrite_original -Comment="Prueba laboratorio forense" $IMG1

Write-Output "== Hash DESPUES de modificar metadatos =="
Get-FileHash $IMG1 -Algorithm SHA256

Write-Output "== Hashes completos (MD5, SHA1, SHA256) de ambas imagenes =="
Get-FileHash $IMG1, $IMG2 -Algorithm MD5
Get-FileHash $IMG1, $IMG2 -Algorithm SHA1
Get-FileHash $IMG1, $IMG2 -Algorithm SHA256

# ============================================================
# 3. METADATOS DE DOCUMENTO WORD (.docx)
# ============================================================

Write-Output "== Metadatos completos del documento =="
exiftool $DOC

Write-Output "== Ver nombres tecnicos exactos de los tags =="
exiftool -s $DOC

Write-Output "== Autor, ultimo editor y fechas clave =="
exiftool -CorePropertiesCreator -CorePropertiesLastModifiedBy -CorePropertiesCreated -CorePropertiesModified $DOC

Write-Output "== Aplicacion, empresa y plantilla usada =="
exiftool -PropertiesApplication -PropertiesCompany -PropertiesTemplate $DOC

Write-Output "== Fecha de modificacion de cada archivo interno del ZIP =="
exiftool -a -G1 -ZipFileName -ZipModifyDate $DOC

# ============================================================
# 4. BUSCAR AUTORES DE CAMBIOS RASTREADOS (control de cambios)
# ============================================================

Write-Output "== Extraer contenido interno del docx (es un ZIP) =="
$extractPath = ".\docx_extraido\contenido"
New-Item -ItemType Directory -Force -Path $extractPath | Out-Null
Copy-Item $DOC "$DOC.zip"
Expand-Archive -Path "$DOC.zip" -DestinationPath $extractPath -Force

Write-Output "== Autores de cambios rastreados (si Control de Cambios estaba activo) =="
Select-String -Path "$extractPath\word\document.xml" -Pattern 'w:author="([^"]+)"' -AllMatches |
    ForEach-Object { $_.Matches } |
    ForEach-Object { $_.Groups[1].Value } |
    Sort-Object -Unique

Write-Output "== Autores de comentarios (si existen) =="
if (Test-Path "$extractPath\word\comments.xml") {
    Select-String -Path "$extractPath\word\comments.xml" -Pattern 'w:author="([^"]+)"' -AllMatches |
        ForEach-Object { $_.Matches } |
        ForEach-Object { $_.Groups[1].Value } |
        Sort-Object -Unique
}

Write-Output "== Ver XML crudo de propiedades del documento =="
Get-Content "$extractPath\docProps\core.xml"
Get-Content "$extractPath\docProps\app.xml"

# ============================================================
# 5. HASH DEL DOCUMENTO WORD
# ============================================================

Write-Output "== Hash del documento (linea base) =="
Get-FileHash $DOC -Algorithm MD5
Get-FileHash $DOC -Algorithm SHA1
Get-FileHash $DOC -Algorithm SHA256

Write-Output "== Guardar todos los hashes .docx en un archivo para el informe =="
Get-FileHash informeTEST*.docx -Algorithm SHA256 | Out-File hashes_docx.txt
Get-Content hashes_docx.txt

# ============================================================
# 6. GRABAR SESION COMPLETA (opcional)
# ============================================================
# Start-Transcript -Path .\sesion_laboratorio.txt
# ... (hacer las pruebas) ...
# Stop-Transcript
