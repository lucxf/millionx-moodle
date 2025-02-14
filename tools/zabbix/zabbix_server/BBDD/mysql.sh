#!/bin/bash

# Importamos funciones de lib.sh
. ./tools/lib.sh

create_mysql_database_user() {
    local db_name=$1
    local db_user=$2
    local db_password=$3

    # Verificar si el archivo .my.cnf existe, si no, crearlo
    if [ ! -f ~/.my.cnf ]; then
        echo "El archivo ~/.my.cnf no existe, creándolo con los valores predeterminados."
        
        # Crear el archivo .my.cnf con configuraciones predeterminadas
        cat <<EOF > ~/.my.cnf
[client]
user = $db_user
password = $db_password
host = localhost
EOF

        # Asegurarse de que el archivo tiene los permisos correctos
        chmod 600 ~/.my.cnf
    fi

    # Ejecutar las operaciones en MySQL y verificar si fallan
    if ! mysql --defaults-file=~/.my.cnf <<EOF
CREATE DATABASE IF NOT EXISTS $db_name DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_bin;
CREATE USER IF NOT EXISTS '$db_user'@'localhost' IDENTIFIED BY '$db_password';
GRANT ALL PRIVILEGES ON $db_name.* TO '$db_user'@'localhost';
SET GLOBAL log_bin_trust_function_creators = 1;
EOF
    then
        log_error "Error al ejecutar los comandos MySQL para crear la base de datos $db_name y el usuario $db_user."
    fi
}

# Crear la base de datos y el usuario en MySQL
create_mysql_database_user "$MYSQL_DB" "$MYSQL_USER" "$MYSQL_PASSWORD"

# Importamos el esquema para la base de datos
log_info "Importando el esquema de la base de datos de Zabbix..."
if ! zcat /usr/share/zabbix/sql-scripts/mysql/server.sql.gz | mysql --defaults-file=~/.my.cnf "$MYSQL_DB"; then
    log_error "Error al importar el esquema para la base de datos."
fi
