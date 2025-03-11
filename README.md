# Script de Conversión con Rclone y Marker

## Introducción

Este documento detalla el funcionamiento del script `conversor.sh`, su configuración con `rclone` para trabajar con Dropbox, y la instalación de `Marker` en un entorno virtual de Python.

## 1. Instalación y Configuración de Rclone con Dropbox

### 1.1 Instalación de Rclone

```bash
su - root
sudo apt install rclone -y
```

## 1.2 Crear usuario

```bash
# Create a dedicated user for the service
sudo useradd -m -s /bin/bash usuario

# Set a strong password for the user
sudo passwd usuario
```

### 1.3 Configuración con Dropbox

Ejecuta:

```bash
su - usuario
rclone config
```

Sigue estos pasos:

1. Selecciona `n` para crear una nueva configuración.
2. Ingresa un nombre (ejemplo: `dropbox`).
3. Selecciona `Dropbox` como proveedor.
4. client\_id, lo dejamos en blanco
5. client\_secret, lo dejamos en blanco
6. Edit advanced config, lo dejamos en no
7. Use auto config, si tienes interfaz grafica le daremos que si y si no tiene interfaz grafica le daremos que no
8. config\_token, pondremos el token generado usando `rclone authorize "dropbox"` en nuestra maquina con interfaz grafica, para ello instlaremos rclone en nuestra maquina con entorno grafico y ejecutaremos el comando, copiamos el resultado y lo pegamos en el server
9. Guarda la configuración.

Para verificar la conexión:

```bash
rclone lsd dropbox:
```

---

## 2. Instalación de Marker en un Entorno Virtual

### 2.1 Instalación de Python y Virtualenv

- **IMPORTANTE**: Hacer con privilegios

```bash
su - root
sudo apt update && sudo apt install python3 python3-venv git -y
```

### 2.2 Creación del Entorno Virtual

- **IMPORTANTE**: Hacer con usuario usuario

```bash
su - usuario
python3 -m venv env
source env/bin/activate
```

### 2.3 Instalación de Marker

```bash
pip install marker-pdf
```

Para probar:

```bash
marker_single --help
```

---

## 3. Descripción del Script `conversor.sh`

### 3.1 Funcionalidad

- Descarga archivos (PDF, PNG, JPG, JPEG) de Dropbox a `/root/temp`.
- Usa `marker_single` para hacer OCR y convertir a HTML.
- Sube archivos procesados de vuelta a Dropbox.
- Elimina los archivos de la carpeta `input` en Dropbox.
- Se ejecuta en bucle infinito cada 30 segundos.
- **IMPORTANTE**: Si utilizas otro usuario cambiralo en el servicio en conversor.service, por el usuario asi como sus rutas absolutas
- La estructura en dropbox que se utiliza para el script es:
  ```
  proyecto-mercantil/
  ├── completed/   # Archivos que ya han sido procesados
  ├── input/       # Archivos pendientes de procesamiento
  └── output/      # Archivos procesados (resultados OCR en HTML)
  ```

### 3.2 Instalación del Script

1. Copia `conversor.sh` a `/usr/local/bin/`:
   ```bash
   su - root
   git clone https://github.com/0Vinylo0/proyecto_mercantil_marker
   sudo cp proyecto_mercantil_marker/conversor.sh /usr/local/bin/conversor.sh
   sudo chmod +x /usr/local/bin/conversor.sh
   ```
2. Crear las carpetas con:
   ```bash
   mkdir -p /root/temp /root/output /root/error_log /root/completed
   ```
---

## 4. Configuración del Servicio Systemd

### 4.1 Instalación del Servicio

Copia el archivo `conversor.service` a `/etc/systemd/system/`:

```bash
sudo cp proyecto_mercantil_marker/conversor.service /etc/systemd/system/conversor.service
```

### 4.2 Habilitar y Ejecutar el Servicio

```bash
sudo systemctl daemon-reload
sudo systemctl enable conversor.service
sudo systemctl start conversor.service
```

Para verificar el estado:

```bash
sudo systemctl status converso.service
```

---

## 5. Solución de Problemas

### 5.1 Ver Logs del Servicio

```bash
journalctl -xfeu conversor
```

### 5.2 Verificar Conexión con Dropbox

```bash
rclone lsd dropbox:
```

### 5.3 Revisar Archivos en las Carpetas

```bash
ls -l /root/temp /root/output /root/error_log /root/completed
```

---

## 6. Conclusión

Este sistema permite automatizar la conversión de archivos con OCR y sincronizar con Dropbox de forma eficiente. Siguiendo esta guía, puedes instalar y configurar `rclone` y `marker`, además de gestionar el servicio en systemd.

