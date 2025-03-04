#!/bin/bash

# Set strict error handling
set -euo pipefail

# Definir rutas locales (actualizado para usuario)
BASE_DIR="/home/usuario"
TEMP_DIR="$BASE_DIR/temp"
OUTPUT_DIR="$BASE_DIR/output"
ERROR_LOG_DIR="$BASE_DIR/error_log"
COMPLETED="$BASE_DIR/completed"
LOG_FILE="$BASE_DIR/mercantil_monitor.log"

# Función para registrar mensajes
log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "$LOG_FILE"
}

# Crear carpetas si no existen con permisos adecuados
mkdir -p "$TEMP_DIR" "$OUTPUT_DIR" "$ERROR_LOG_DIR" "$COMPLETED"
chmod 700 "$TEMP_DIR" "$OUTPUT_DIR" "$ERROR_LOG_DIR" "$COMPLETED"
touch "$LOG_FILE"
chmod 600 "$LOG_FILE"

# Limitar el número de archivos a procesar por ciclo
MAX_FILES_PER_CYCLE=5

# Función para validar nombre de archivo
validate_filename() {
    local filename="$(basename "$1")"
    if [[ "$filename" =~ [^a-zA-Z0-9_.-] ]]; then
        log "⚠️ Nombre de archivo inválido: $filename"
        return 1
    fi
    return 0
}

# Función para procesar archivos
procesar_archivos() {
    log "📂 Descargando archivos permitidos (PDF, PNG, JPG, JPEG) desde Dropbox..."
    
    # Descargar solo archivos con extensiones permitidas
    rclone copy dropbox:/proyecto-mercantil/input "$TEMP_DIR" --progress --drive-shared-with-me \
        --include "*.pdf" --include "*.png" --include "*.jpg" --include "*.jpeg" \
        --config "/home/usuario/.config/rclone/rclone.conf"

    # Verificar si hay archivos en TEMP
    FILES=$(find "$TEMP_DIR" -maxdepth 1 -type f \( -iname "*.pdf" -o -iname "*.png" -o -iname "*.jpg" -o -iname "*.jpeg" \) | head -n $MAX_FILES_PER_CYCLE)
    
    if [ -z "$FILES" ]; then
        log "⚠️ No hay archivos válidos en Dropbox para procesar."
        return
    fi

    # Array para mantener un registro de los archivos procesados
    processed_files=()
    
    for FILE in $FILES; do
        [ -f "$FILE" ] || continue  # Saltar si no es un archivo
        
        # Validar nombre de archivo
        if ! validate_filename "$FILE"; then
            mv "$FILE" "$ERROR_LOG_DIR/"
            continue
        fi
        
        filename=$(basename "$FILE")
        log "🛠️ Procesando: $filename"
        
        # Ejecutar OCR y convertir a HTML con manejo de errores
        if /usr/local/bin/marker_single --output_dir "$OUTPUT_DIR" --output_format html --force_ocr --strip_existing_ocr --debug --languages es "$FILE" > "$TEMP_DIR/${filename}.log" 2>&1; then
            log "✅ Procesado correctamente: $filename"
            
            # Mover archivo a la carpeta de completados
            mv "$FILE" "$COMPLETED/"
            processed_files+=("$filename")
            
            # Verificar que los archivos de salida existen antes de subir
            if [ "$(ls -A "$OUTPUT_DIR")" ]; then
                # Subir archivos procesados a Dropbox
                log "🚀 Subiendo archivos procesados a Dropbox..."
                rclone copy "$OUTPUT_DIR" dropbox:/proyecto-mercantil/output --progress --drive-shared-with-me --config "/home/usuario/.config/rclone/rclone.conf"
                
                # Limpiar directorio de salida después de subir
                rm -rf "$OUTPUT_DIR"/*
            else
                log "⚠️ No se encontraron archivos de salida para subir"
            fi
        else
            log "❌ Error en: $filename - Moviendo a error_log/"
            mv "$FILE" "$ERROR_LOG_DIR/"
            # Guardar el log de error
            mv "$TEMP_DIR/${filename}.log" "$ERROR_LOG_DIR/${filename}.error.log"
        fi
    done
    
    # Subir archivos completados a Dropbox si existen
    if [ "$(ls -A "$COMPLETED")" ]; then
        log "📤 Subiendo archivos completados a Dropbox..."
        rclone copy "$COMPLETED" dropbox:/proyecto-mercantil/completed --progress --drive-shared-with-me --config "/home/usuario/.config/rclone/rclone.conf"
        
        # Eliminar archivos procesados de la carpeta input en Dropbox y localmente
        for file in "${processed_files[@]}"; do
            log "🗑️ Eliminando archivo '$file' de la carpeta input en Dropbox..."
            rclone delete "dropbox:/proyecto-mercantil/input/$file" --drive-shared-with-me --config "/home/usuario/.config/rclone/rclone.conf"
        done
        
        # Limpiar directorio de completados
        rm -rf "$COMPLETED"/*
    fi
}

# Manejo de señales para limpieza adecuada
trap 'log "Deteniendo servicio..."; exit 0' SIGTERM SIGINT

# Bucle principal para monitorear Dropbox
log "🚀 Iniciando servicio de monitoreo de Dropbox..."

while true; do
    log "🔄 Escaneando cambios en Dropbox..."
    
    # Verificar conexión a internet antes de intentar acceder a Dropbox
    if ! ping -c 1 dropbox.com &> /dev/null; then
        log "⚠️ Sin conexión a internet. Reintentando en 60 segundos..."
        sleep 60
        continue
    fi
    
    # Revisar si hay archivos en la carpeta de Dropbox con extensiones válidas
    if rclone lsf dropbox:/proyecto-mercantil/input --drive-shared-with-me --include "*.pdf" --include "*.png" --include "*.jpg" --include "*.jpeg" --config "/home/usuario/.config/rclone/rclone.conf" | grep -Ei "\.(pdf|png|jpg|jpeg)$"; then
        procesar_archivos
    else
        log "⏳ No hay archivos PDF o imágenes nuevas en Dropbox. Esperando..."
    fi
    
    # Esperar 30 segundos antes de volver a comprobar
    sleep 30
done
