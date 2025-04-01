#!/bin/bash

# Definir archivo de log
LOGFILE="/var/log/Project/installation.log"
DOMAIN="millionx-academy.com"
# LA ip es la del router publica, porque es donde està el reverse proxy, si el reverse proxy estubiera en otro aldo seria aputnado al Reverse Proxy
DNS_RESOLV_IP=172.30.10.13
# Como principal ponemos el que se ve des del exterior
NS1=$DNS_RESOLV_IP
NS2=172.31.9.254
NS3=172.31.9.255
USER="lucxf"
BIND_FOLDER_PATH="/etc/bind/"

# Función para registrar mensajes en el log y mostrar los errores en pantalla
log_error() {
    # Registrar el error en el archivo de log
    echo "$(date) - ERROR: $1" | tee -a $LOGFILE
    # Mostrar el error en la terminal en rojo
    echo -e "\033[31m$(date) - ERROR: $1\033[0m"

    exit 1
}

log_info() {
    # Registrar el mensaje informativo en el archivo de log
    echo "$(date) - INFO: $1" | tee -a $LOGFILE
    # Mostrar el mensaje en la terminal en azul
    echo -e "\033[34m$(date) - INFO: $1\033[0m"
}

# Comprobar si el usuario es root
if [ "$(id -u)" -ne 0 ]; then
    echo -e "\033[31mERROR: Este script debe ejecutarse como usuario root.\033[0m"
    exit 1
fi

# Creamos los directorios necesarios
mkdir -p /var/log/Project

#!/bin/bash

# Verificar si Webmin está instalado
if dpkg -l | grep -q webmin; then
    echo "✅ Webmin está instalado en el sistema."
else
    echo "❌ Webmin NO está instalado en el sistema."
    # Empezamos la instalación de Webmin
    log_info "Instalando Webmin..."
    chmod +x ./webmin_install.sh
    if ! sudo ./webmin_install.sh; then
        log_error "Error al instalar Webmin."
        log_info "Borrando todo lo instalado..."
        chmod +x ./BORRAR/borrar_webmin.sh
        sudo ./BORRAR/borrar_webmin.sh
    fi
fi

# Creamos la zona de DNS
log_info "Creando la zona de DNS..."
chmod +x ./bindDNS.sh
if ! sudo ./bindDNS.sh $DOMAIN $NS1 $NS2 $NS3 $DNS_RESOLV_IP $USER; then
    rm -r $BIND_FOLDER_PATH
    rm -r /var/cache/bind/
    apt purge bind9 bind9utils bind9-doc -y
    log_error "Error al crear la zona de DNS."
fi
