#!/bin/bash

# Importamos funciones de lib.sh
. ./tools/lib.sh
. ./tools/zabbix/zabbix_server/BBDD/mysql.sh

# Paquetes a instalar
packages_to_install=("zabbix-server-mysql" "zabbix-frontend-php" "zabbix-nginx-conf" "zabbix-sql-scripts" "zabbix-agent" "mysql-server")

# Definición de las variables correctamente
MYSQL_USER="ubuser_sql"
MYSQL_PASSWORD="123456aA."
MYSQL_DB="zabbix_db"


# Comprobar si el usuario es root
if [ "$(id -u)" -ne 0 ]; then
    echo -e "\033[31mERROR: Este script debe ejecutarse como usuario root.\033[0m"
    exit 1
fi

log_info "Instalando repositorio de Zabbix..."
if ! wget https://repo.zabbix.com/zabbix/7.2/release/ubuntu/pool/main/z/zabbix-release/zabbix-release_latest_7.2+ubuntu24.04_all.deb; then
    log_error "Error al descargar el repositorio de Zabbix."
fi

if ! dpkg -i zabbix-release_latest_7.2+ubuntu24.04_all.deb; then
    log_error "Error al instalar el repositorio de Zabbix."
fi

if ! apt update -y && apt upgrade -y; then
    log_error "Error al actualizar el sistema."
fi

# Zabbix con mysql y nginx
log_info "Instalando el servidor, la interfaz y el agente de Zabbix..."
for package in "${packages_to_install[@]}"; do
    if ! apt install -y "$package"; then
        log_error "Error al instalar el paquete: $package"
    fi
done

log_info "Configurando MySQL..."
chmod +x ./tools/zabbix/zabbix_server/BBDD/mysql.sh

if ! sudo ./tools/zabbix/zabbix_server/BBDD/mysql.sh; then
    log_error "Error al configurar MySQL."
fi

# Importamos el esquema para la base de datos
log_info "Importando el esquema de la base de datos de Zabbix..."
if ! zcat /usr/share/zabbix/sql-scripts/mysql/server.sql.gz | mysql --defaults-file=~/.my.cnf "$MYSQL_DB"; then
    log_error "Error al importar el esquema para la base de datos."
fi

log_info "Instalación de Zabbix completada correctamente."
