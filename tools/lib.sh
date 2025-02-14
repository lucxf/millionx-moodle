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

install_packages() {
    local packages="$1"  # Recibe el listado de paquetes como una cadena de texto
    IFS=' ' read -r -a package_array <<< "$packages"  # Convierte la cadena en un arreglo

    log_info "Instalando los paquetes..."
    for package in "${package_array[@]}"; do
        if ! apt install -y "$package"; then
            log_error "Error al instalar el paquete: $package"
        fi
    done

    log_info "Los paquetes se han instalado correctamente."
}