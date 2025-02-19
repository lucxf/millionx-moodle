#!/bin/bash

# Log file setup
LOGFILE="/var/log/Project/zabbix_installation.log"
mkdir -p "$(dirname $LOGFILE)"

# Define colors
green="32m"   # Verde
red="31m"     # Rojo
yellow="33m"  # Amarillo
blue="34m"    # Azul
magenta="35m" # Magenta
cyan="36m"    # Cian
white="37m"   # Blanco
reset="0m"    # Reset de color

# Variables
MYSQL_ROOT_PASSWORD="your_root_password"
ZABBIX_DB_PASSWORD="your_zabbix_password"
DOMAIN_NAME="example.com"
LISTEN_PORT="8080"

# Logging functions
log_error() {
    echo "$(date) - ERROR: $1" | tee -a $LOGFILE
    echo -e "\033[$red$(date) - ERROR: $1\033[0m"
    cleanup
    exit 1
}

log_info() {
    echo "$(date) - INFO: $1" | tee -a $LOGFILE
    echo -e "\033[$green$(date) - INFO: $1\033[0m"
}

# Cleanup function
cleanup() {
    log_info "Starting cleanup process..."
    
    # Stop services
    systemctl stop zabbix-server zabbix-agent nginx php8.3-fpm mysql 2>/dev/null || true
    
    # Remove Zabbix packages
    apt-get remove --purge -y zabbix-server-mysql zabbix-frontend-php zabbix-nginx-conf zabbix-sql-scripts zabbix-agent 2>/dev/null || true
    
    # Remove MySQL if it was installed by this script
    if [ -f "/var/lib/mysql/.installed_by_zabbix" ]; then
        log_info "Removing MySQL server..."
        apt-get remove --purge -y mysql-server mysql-client 2>/dev/null || true
        rm -rf /var/lib/mysql
        rm -rf /etc/mysql
    fi
    
    # Remove Zabbix repository
    rm -f /etc/apt/sources.list.d/zabbix.list
    rm -f zabbix-release_latest_7.2+ubuntu24.04_all.deb
    
    # Clean up APT
    apt-get autoremove -y
    apt-get clean
    
    log_info "Cleanup completed"
}

# Check if script is run as root
if [ "$EUID" -ne 0 ]; then 
    log_error "Please run as root (sudo -s)"
fi

# Installation process with error handling
{
    # Mark the beginning of installation
    touch "/var/lib/mysql/.installed_by_zabbix"
    
    log_info "Installing MySQL Server..."
    apt update || log_error "Failed to update package list"
    apt install -y mysql-server || log_error "Failed to install MySQL server"

    log_info "Securing MySQL installation..."
    mysql --user=root <<_EOF_ || log_error "Failed to secure MySQL"
ALTER USER 'root'@'localhost' IDENTIFIED WITH mysql_native_password BY '${MYSQL_ROOT_PASSWORD}';
DELETE FROM mysql.user WHERE User='';
DELETE FROM mysql.user WHERE User='root' AND Host NOT IN ('localhost', '127.0.0.1', '::1');
DROP DATABASE IF EXISTS test;
DELETE FROM mysql.db WHERE Db='test' OR Db='test\\_%';
FLUSH PRIVILEGES;
_EOF_

    log_info "Configuring locales..."
    apt-get install -y locales || log_error "Failed to install locales"
    locale-gen en_US.UTF-8 || log_error "Failed to generate locale"
    update-locale LANG=en_US.UTF-8 LC_ALL=en_US.UTF-8 || log_error "Failed to update locale"
    export LANG=en_US.UTF-8
    export LC_ALL=en_US.UTF-8

    log_info "Installing Zabbix repository..."
    wget https://repo.zabbix.com/zabbix/7.2/release/ubuntu/pool/main/z/zabbix-release/zabbix-release_latest_7.2+ubuntu24.04_all.deb || log_error "Failed to download Zabbix repository"
    dpkg -i zabbix-release_latest_7.2+ubuntu24.04_all.deb || log_error "Failed to install Zabbix repository"
    apt update || log_error "Failed to update package list"

    log_info "Installing Zabbix components..."
    apt install -y zabbix-server-mysql zabbix-frontend-php zabbix-nginx-conf zabbix-sql-scripts zabbix-agent || log_error "Failed to install Zabbix components"

    log_info "Configuring MySQL database..."
    mysql -uroot -p"${MYSQL_ROOT_PASSWORD}" <<EOF || log_error "Failed to configure Zabbix database"
create database zabbix character set utf8mb4 collate utf8mb4_bin;
create user zabbix@localhost identified by '${ZABBIX_DB_PASSWORD}';
grant all privileges on zabbix.* to zabbix@localhost;
set global log_bin_trust_function_creators = 1;
EOF

    log_info "Importing initial schema..."
    zcat /usr/share/zabbix/sql-scripts/mysql/server.sql.gz | mysql --default-character-set=utf8mb4 -uzabbix -p"${ZABBIX_DB_PASSWORD}" zabbix || log_error "Failed to import schema"

    log_info "Configuring function creators..."
    mysql -uroot -p"${MYSQL_ROOT_PASSWORD}" <<EOF || log_error "Failed to configure MySQL settings"
set global log_bin_trust_function_creators = 0;
EOF

    log_info "Configuring Zabbix server..."
    sed -i "s/# DBPassword=/DBPassword=${ZABBIX_DB_PASSWORD}/" /etc/zabbix/zabbix_server.conf || log_error "Failed to configure Zabbix server"

    log_info "Configuring PHP..."
    cat > /etc/php/8.3/fpm/conf.d/99-zabbix.ini <<EOF || log_error "Failed to configure PHP"
[PHP]
max_execution_time = 300
memory_limit = 128M
post_max_size = 16M
upload_max_filesize = 2M
max_input_time = 300
date.timezone = UTC
EOF

    log_info "Configuring Nginx..."
    sed -i "s/# listen/listen ${LISTEN_PORT}/" /etc/zabbix/nginx.conf || log_error "Failed to configure Nginx port"
    sed -i "s/# server_name/server_name ${DOMAIN_NAME}/" /etc/zabbix/nginx.conf || log_error "Failed to configure Nginx server name"

    log_info "Starting services..."
    systemctl restart mysql || log_error "Failed to start MySQL"
    systemctl enable mysql || log_error "Failed to enable MySQL"
    systemctl restart zabbix-server zabbix-agent nginx php8.3-fpm || log_error "Failed to start Zabbix services"
    systemctl enable zabbix-server zabbix-agent nginx php8.3-fpm || log_error "Failed to enable Zabbix services"

    log_info "Installation completed successfully!"
    log_info "Please access Zabbix UI at: http://${DOMAIN_NAME}:${LISTEN_PORT}"
    log_info "Default credentials:"
    log_info "Username: Admin"
    log_info "Password: zabbix"
    log_info "MySQL root password: ${MYSQL_ROOT_PASSWORD}"
    log_info "Zabbix database password: ${ZABBIX_DB_PASSWORD}"
    log_info "Please save these passwords in a secure location."

} || {
    # If any command fails, this block will execute
    log_error "Installation failed. Check the log file at $LOGFILE for details"
}