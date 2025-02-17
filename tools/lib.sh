#!/bin/bash

# Archivo de log
LOGFILE="/var/log/Project/zabbix_installation.log"

# Definir colores
green="32m"   # Verde
red="31m"     # Rojo
yellow="33m"  # Amarillo
blue="34m"    # Azul
magenta="35m" # Magenta
cyan="36m"    # Cian
white="37m"   # Blanco
reset="0m"    # Reset de color

# Función para escribir errores en el log y mostrar el mensaje en rojo
log_error() {
    # Registrar el error en el archivo de log
    echo "$(date) - ERROR: $1" | tee -a $LOGFILE
    # Mostrar el error en la terminal en rojo
    echo -e "\033[$red$(date) - ERROR: $1\033[0m"
    # Detener la ejecución del script
    exit 1
}

log_info() {
    # Registrar el mensaje informativo en el archivo de log
    echo "$(date) - INFO: $1" | tee -a $LOGFILE
    # Mostrar el mensaje en la terminal en verde
    echo -e "\033[$green$(date) - INFO: $1\033[0m"
}

# Función para instalar paquetes y manejar errores
install_packages() {
    local package_array=("$@")  # Recibe el arreglo de paquetes como argumento

    log_info "Instalando los paquetes..."
    for package in "${package_array[@]}"; do
        if ! apt install -y "$package"; then
            log_error "Error al instalar el paquete: $package"
        fi
    done

    log_info "Los paquetes se han instalado correctamente."
}

config_zabbix_server() {
    local config_file="/etc/zabbix/zabbix_server.conf"
    local db_name="$1"    # El nuevo valor para DBName
    local db_user="$2"    # El nuevo valor para DBUser
    local db_password="$3"  # El nuevo valor para DBPassword

    # Verificar si el archivo existe
    log_info "Verificando la existencia de $config_file..."
    if [ ! -f "$config_file" ]; then
        log_error "El archivo $config_file no existe."
        exit 1
    fi

    # Log de inicio de la configuración
    log_info "Configurando $config_file: modificando DBName, DBUser y DBPassword..."

    # Descomentar las líneas que empiezan con DBName, DBUser, y DBPassword si están comentadas
    sudo sed -i "s/^#\?\(DBName=.*\)/\1/" "$config_file"   # Descomentar DBName
    sudo sed -i "s/^#\?\(DBUser=.*\)/\1/" "$config_file"   # Descomentar DBUser
    sudo sed -i "s/^#\?\(DBPassword=.*\)/\1/" "$config_file"  # Descomentar DBPassword

    # Usamos sed para modificar el valor de DBName, DBUser y DBPassword en el archivo
    if sudo sed -i "s/^DBName=.*/DBName=$db_name/" "$config_file" && \
       sudo sed -i "s/^DBUser=.*/DBUser=$db_user/" "$config_file" && \
       sudo sed -i "s/^DBPassword=.*/DBPassword=$db_password/" "$config_file"; then
        log_info "La configuración de DBName, DBUser y DBPassword se ha actualizado correctamente en $config_file."
    else
        log_error "Error al modificar DBName, DBUser o DBPassword en $config_file."
        exit 1
    fi
}
