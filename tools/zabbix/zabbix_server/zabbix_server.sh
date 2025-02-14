#!/bin/bash

# Importamos funciones de lib.sh
. ./tools/lib.sh
. ./tools/zabbix/zabbix_server/BBDD/mysql.sh

# Paquetes a instalar
packages_to_install=("zabbix-server-mysql" "zabbix-frontend-php" "zabbix-nginx-conf" "zabbix-sql-scripts" "zabbix-agent" "mysql-server")

# Definición de las variables correctamente
MYSQL_USER="root"
MYSQL_PASSWORD="lluc2005"
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


# apt install zabbix-server-mysql zabbix-frontend-php zabbix-nginx-conf zabbix-sql-scripts zabbix-agent

# MySQL: zabbix-server-MySQL 
# PostgresSQL: zabbix-server-pgsql php8.3-pgsql

# Nginx: zabbix-nginx-conf 
# Apache: zabbix-apache-conf

# Llamar a la función para instalar los paquetes
install_packages "$packages_to_install"

log_info "Selecciona base de datos a usar:"
echo "1 - MySQL"
echo "2 - PostgreSQL"
read -r db_type

if [ "$db_type" -eq 1 ]; then

    log_info "Configurando MySQL..."

    create_mysql_database_user "$MYSQL_DB" "$MYSQL_USER" "$MYSQL_PASSWORD"

    imoport_mysql_schema

    disable_log_bin_trust_function_creators

    log_info "Configuracion de MySQL completada correctamente."

else

    log_info "Configuracion de PostgreSQL completada correctamente."

fi

log_info "configurando zabbix server..."

config_zabbix_server "$MYSQL_DB" "$MYSQL_USER" "$MYSQL_PASSWORD"