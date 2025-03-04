#!/bin/bash

# Definir rutas locales
TEMP_DIR="/root/temp"
OUTPUT_DIR="/root/output"
ERROR_LOG_DIR="/root/error_log"
COMPLETED="/root/completed"

# Crear carpetas si no existen
mkdir -p "$TEMP_DIR" "$OUTPUT_DIR" "$ERROR_LOG_DIR" "$COMPLETED"

# Función para procesar archivos
procesar_archivos() {
    echo "📂 Descargando archivos permitidos (PDF, PNG, JPG, JPEG) desde Drive..."
    
    # Descargar solo archivos con extensiones permitidas
    rclone copy dropbox:/proyecto-mercantil/input "$TEMP_DIR" --progress --drive-shared-with-me  --include "*.pdf" --include "*.png" --include "*.jpg" --include "*.jpeg"

    # Verificar si hay archivos en TEMP
    FILES=$(find "$TEMP_DIR" -maxdepth 1 -type f \( -iname "*.pdf" -o -iname "*.png" -o -iname "*.jpg" -o -iname "*.jpeg" \))
    if [ -z "$FILES" ]; then
        echo "⚠️ No hay archivos válidos en Dropbox para procesar."
        return
    fi

    for FILE in $FILES; do
        [ -f "$FILE" ] || continue  # Saltar si no es un archivo

        echo "🛠️ Procesando: $(basename "$FILE")"

        # Ejecutar OCR y convertir a HTML
        if marker_single --output_dir "$OUTPUT_DIR" --output_format html --force_ocr --strip_existing_ocr --debug --languages es "$FILE"; then
            echo "✅ Procesado correctamente: $(basename "$FILE")"

            # Mover archivo a la carpeta de completados
            mv "$FILE" "$COMPLETED/"

            # Subir archivos procesados a Drive
            echo "🚀 Subiendo archivos procesados a Dropbox..."
            rclone copy "$OUTPUT_DIR" dropbox:/proyecto-mercantil/output --progress --drive-shared-with-me 

            # Subir archivos completados a Drive
            echo "📤 Subiendo archivos completados a Dropbox..."
            rclone copy "$COMPLETED" dropbox:/proyecto-mercantil/completed --progress --drive-shared-with-me 

            # Elimina archivos locales después de subirlos
            rm -r "$COMPLETED"/*
            rm -r "$OUTPUT_DIR"/*
        else
            echo "❌ Error en: $(basename "$FILE") - Moviendo a error_log/"
            mv "$FILE" "$ERROR_LOG_DIR/"
        fi
    done

    # Eliminar carpeta `input` de Drive después de procesar los archivos
    echo "🗑️ Eliminando archivos y carpeta 'input' en Dropbox..."
    rclone delete "dropbox:/proyecto-mercantil/input/$FILE_NAME" --progress --drive-shared-with-me 
}

# Bucle infinito para monitorear Google Drive
while true; do
    echo "🔄 Escaneando cambios en Dropbox..."
    
    # Revisar si hay archivos en la carpeta de Drive con extensiones válidas
    if rclone lsf dropbox:/proyecto-mercantil/input --drive-shared-with-me | grep -Ei "\.(pdf|png|jpg|jpeg)$"; then
        procesar_archivos
    else
        echo "⏳ No hay archivos PDF o imágenes nuevas en Dropbox. Esperando..."
    fi

    # Esperar 30 segundos antes de volver a comprobar
    sleep 30
done
