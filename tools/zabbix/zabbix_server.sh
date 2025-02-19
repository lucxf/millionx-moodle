#!/bin/bash

# Exit on any error
set -e

# Check if script is run as root
if [ "$EUID" -ne 0 ]; then 
    echo "Please run as root (sudo -s)"
    exit 1
fi

# Variables
MYSQL_ROOT_PASSWORD="your_root_password"
ZABBIX_DB_PASSWORD="your_zabbix_password"
DOMAIN_NAME="example.com"
LISTEN_PORT="8080"

# Install MySQL Server
echo "Installing MySQL Server..."
apt update
apt install -y mysql-server

# Secure MySQL installation
echo "Securing MySQL installation..."
mysql --user=root <<_EOF_
ALTER USER 'root'@'localhost' IDENTIFIED WITH mysql_native_password BY '${MYSQL_ROOT_PASSWORD}';
DELETE FROM mysql.user WHERE User='';
DELETE FROM mysql.user WHERE User='root' AND Host NOT IN ('localhost', '127.0.0.1', '::1');
DROP DATABASE IF EXISTS test;
DELETE FROM mysql.db WHERE Db='test' OR Db='test\\_%';
FLUSH PRIVILEGES;
_EOF_

# Configure locales
echo "Configuring locales..."
apt-get install -y locales
locale-gen en_US.UTF-8
update-locale LANG=en_US.UTF-8 LC_ALL=en_US.UTF-8
export LANG=en_US.UTF-8
export LC_ALL=en_US.UTF-8

# Install Zabbix repository
echo "Installing Zabbix repository..."
wget https://repo.zabbix.com/zabbix/7.2/release/ubuntu/pool/main/z/zabbix-release/zabbix-release_latest_7.2+ubuntu24.04_all.deb
dpkg -i zabbix-release_latest_7.2+ubuntu24.04_all.deb
apt update

# Install Zabbix components
echo "Installing Zabbix components..."
apt install -y zabbix-server-mysql zabbix-frontend-php zabbix-nginx-conf zabbix-sql-scripts zabbix-agent

# Configure MySQL
echo "Configuring MySQL database..."
mysql -uroot -p"${MYSQL_ROOT_PASSWORD}" <<EOF
create database zabbix character set utf8mb4 collate utf8mb4_bin;
create user zabbix@localhost identified by '${ZABBIX_DB_PASSWORD}';
grant all privileges on zabbix.* to zabbix@localhost;
set global log_bin_trust_function_creators = 1;
EOF

# Import initial schema
echo "Importing initial schema..."
zcat /usr/share/zabbix/sql-scripts/mysql/server.sql.gz | mysql --default-character-set=utf8mb4 -uzabbix -p"${ZABBIX_DB_PASSWORD}" zabbix

# Disable log_bin_trust_function_creators
mysql -uroot -p"${MYSQL_ROOT_PASSWORD}" <<EOF
set global log_bin_trust_function_creators = 0;
EOF

# Configure Zabbix server
echo "Configuring Zabbix server..."
sed -i "s/# DBPassword=/DBPassword=${ZABBIX_DB_PASSWORD}/" /etc/zabbix/zabbix_server.conf

# Configure PHP
echo "Configuring PHP..."
cat > /etc/php/8.3/fpm/conf.d/99-zabbix.ini <<EOF
[PHP]
max_execution_time = 300
memory_limit = 128M
post_max_size = 16M
upload_max_filesize = 2M
max_input_time = 300
date.timezone = UTC
EOF

# Configure Nginx
echo "Configuring Nginx..."
sed -i "s/# listen/listen ${LISTEN_PORT}/" /etc/zabbix/nginx.conf
sed -i "s/# server_name/server_name ${DOMAIN_NAME}/" /etc/zabbix/nginx.conf

# Start and enable services
echo "Starting services..."
systemctl restart mysql
systemctl enable mysql
systemctl restart zabbix-server zabbix-agent nginx php8.3-fpm
systemctl enable zabbix-server zabbix-agent nginx php8.3-fpm

echo "Installation complete!"
echo "Please access Zabbix UI at: http://${DOMAIN_NAME}:${LISTEN_PORT}"
echo "Default credentials:"
echo "Username: Admin"
echo "Password: zabbix"

echo "MySQL root password: ${MYSQL_ROOT_PASSWORD}"
echo "Zabbix database password: ${ZABBIX_DB_PASSWORD}"
echo "Please save these passwords in a secure location."