#!/bin/bash

# Archivo de log
LOGFILE="/var/log/Project/zabbix_installation.log"

packages_to_install=("zabbix-server-mysql" "zabbix-frontend-php" "zabbix-nginx-conf" "zabbix-sql-scripts" "zabbix-agent" "mysql-server")

$MYSQL_USER="ubuser_sql"
$MYSQL_PASSWORD="123456aA."
$MYSQL_DB="zabbix_db"
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

create_mysql_database_user() {
    local db_name=$1
    local db_user=$2
    local db_password=$3

    # Ejecutar las operaciones en MySQL y verificar si fallan
    if ! mysql -uroot -p <<EOF
CREATE DATABASE $db_name CHARACTER SET utf8mb4 COLLATE utf8mb4_bin;
CREATE USER '$db_user'@'localhost' IDENTIFIED BY '$db_password';
GRANT ALL PRIVILEGES ON $db_name.* TO '$db_user'@'localhost';
SET GLOBAL log_bin_trust_function_creators = 1;
EOF
    then
        log_error "Error al ejecutar los comandos MySQL para crear la base de datos $db_name y el usuario $db_user."
        exit 1
    fi
}

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

# Ejemplo de uso:
create_mysql_database_user $MYSQL_DB $MYSQL_USER $MYSQL_PASSWORD

# Importamos el esquema para la base de datos
if ! zcat /usr/share/zabbix/sql-scripts/mysql/server.sql.gz | mysql --default-character-set=utf8mb4 -u"$MYSQL_USER" -p"$MYSQL_PASSWORD" "$MYSQL_DB"; then
    log_error "Error al importar el esquema para la base de datos."
fi




