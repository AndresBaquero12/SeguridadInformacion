#!/bin/bash
# ============================================================
# Laboratorio de Seguridad de la Información - Metadatos
# Script recopilatorio de comandos usados (Kali Linux)
# Integrantes: Sebastian Urrego, Andres Baquero, Julian Cristancho
# ============================================================

# ---- Variables (ajusta los nombres de archivo segun tu caso) ----
IMG1="1000184727.jpg"        # Foto Samsung A35
IMG2="image0.jpeg"           # Foto iPhone 16 Pro
DOC="informeTEST.docx"       # Documento Word a analizar

# Identificación del equipo en cada captura
echo "sebastian urrego andres baquero julian cristancho"

# ============================================================
# 1. METADATOS DE IMAGENES
# ============================================================

echo "== Metadatos completos de $IMG1 =="
exiftool "$IMG1"

echo "== Metadatos completos de $IMG2 =="
exiftool "$IMG2"

echo "== Verificar GPS (esperado: sin datos) =="
exiftool -gps:all "$IMG1"
exiftool -gps:all "$IMG2"

echo "== Comparacion directa entre ambas imagenes =="
exiftool -Make -Model -Software -DateTimeOriginal -ImageSize -FileSize "$IMG1" "$IMG2"

echo "== Extraer thumbnail embebido =="
exiftool -b -ThumbnailImage "$IMG1" > thumb_extraido.jpg

# ============================================================
# 2. HASH DE IMAGENES (integridad de evidencia)
# ============================================================

echo "== Hash ANTES de modificar metadatos =="
sha256sum "$IMG1"

echo "== Modificar un metadato de prueba =="
exiftool -overwrite_original -Comment="Prueba laboratorio forense" "$IMG1"

echo "== Hash DESPUES de modificar metadatos =="
sha256sum "$IMG1"

echo "== Hashes completos (md5, sha1, sha256) de ambas imagenes =="
md5sum "$IMG1" "$IMG2"
sha1sum "$IMG1" "$IMG2"
sha256sum "$IMG1" "$IMG2"

# ============================================================
# 3. METADATOS DE DOCUMENTO WORD (.docx)
# ============================================================

echo "== Metadatos completos del documento =="
exiftool "$DOC"

echo "== Ver nombres tecnicos exactos de los tags =="
exiftool -s "$DOC"

echo "== Autor, ultimo editor y fechas clave =="
exiftool -CorePropertiesCreator -CorePropertiesLastModifiedBy -CorePropertiesCreated -CorePropertiesModified "$DOC"

echo "== Aplicacion, empresa y plantilla usada =="
exiftool -PropertiesApplication -PropertiesCompany -PropertiesTemplate "$DOC"

echo "== Fecha de modificacion de cada archivo interno del ZIP =="
exiftool -a -G1 -ZipFileName -ZipModifyDate "$DOC"

# ============================================================
# 4. BUSCAR AUTORES DE CAMBIOS RASTREADOS (control de cambios)
# ============================================================

echo "== Extraer contenido interno del docx (es un ZIP) =="
mkdir -p docx_extraido
unzip -o "$DOC" -d docx_extraido/contenido

echo "== Autores de cambios rastreados (si Control de Cambios estaba activo) =="
grep -oP 'w:author="\K[^"]+' docx_extraido/contenido/word/document.xml | sort -u

echo "== Autores de comentarios (si existen) =="
grep -oP 'w:author="\K[^"]+' docx_extraido/contenido/word/comments.xml 2>/dev/null | sort -u

echo "== Ver XML crudo de propiedades del documento =="
cat docx_extraido/contenido/docProps/core.xml
cat docx_extraido/contenido/docProps/app.xml

# ============================================================
# 5. HASH DEL DOCUMENTO WORD
# ============================================================

echo "== Hash del documento (linea base) =="
md5sum "$DOC"
sha1sum "$DOC"
sha256sum "$DOC"

echo "== Guardar todos los hashes .docx en un archivo para el informe =="
sha256sum informeTEST*.docx > hashes_docx.txt
cat hashes_docx.txt

# ============================================================
# 6. GRABAR SESION COMPLETA (opcional, ejecutar aparte)
# ============================================================
# script -a sesion_laboratorio.txt
# ... (hacer las pruebas) ...
# exit
