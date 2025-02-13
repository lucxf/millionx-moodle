#!/bin/bash

# Archivo de log
LOGFILE="/var/log/Project/zabbix_installation.log"

# Función para escribir errores en el log y mostrar el mensaje en rojo
log_error() {
    # Registrar el error en el archivo de log
    echo "$(date) - ERROR: $1" | tee -a $LOGFILE
    # Mostrar el error en la terminal en rojo
    echo -e "\033[31m$(date) - ERROR: $1\033[0m"
    # Detener la ejecución del script
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

mkdir -p /var/log/Project

log_info "Selecciona metodo de instalacion:"

# Pendiente cambiar el solo agent, es decir qeu instales zabbix server sin agent
echo "1 - Server, Frontend, Agent"
echo "2 - Agent"

echo "Selecciona instalación (1-2)"
read -r install_type

if [ "$install_type" -eq 1 ]; then
    # Instalar Zabbix Server, Frontend y Agent
    log_info "Instalando Zabbix Server, Frontend y Agent..."
    chmod +x ./tools/zabbix/zabbix_server/zabbix_server.sh
    if ! sudo ./tools/zabbix/zabbix_server/zabbix_server.sh; then
        log_error "Error al instalar Zabbix Server, Frontend y Agent."
    fi
else
    # Instalar Zabbix Agent
    log_info "Instalando Zabbix Agent..."
    chmod +x ./tools/zabbix/zabbix_agent.sh
    if ! sudo ./tools/zabbix/zabbix_agent/zabbix_agent.sh; then
        log_error "Error al instalar Zabbix Agent."
    fi
fi
