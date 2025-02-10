# Usa la imagen base de nginx
FROM nginx:latest

# Instala Zabbix y dependencias
RUN wget https://repo.zabbix.com/zabbix/7.0/ubuntu/pool/main/z/zabbix-release/zabbix-release_latest_7.0+ubuntu24.04_all.deb \
    && dpkg -i zabbix-release_latest_7.0+ubuntu24.04_all.deb \
    && apt update -y && apt upgrade -y \
    && apt install -y zabbix-server-mysql zabbix-frontend-php zabbix-nginx-conf zabbix-sql-scripts zabbix-agent mysql-server

# Configurar MySQL
RUN service mysql start \
    && mysql -uroot -e "CREATE DATABASE zabbix CHARACTER SET utf8mb4 COLLATE utf8mb4_bin;" \
    && mysql -uroot -e "CREATE USER 'zabbix'@'localhost' IDENTIFIED BY 'password';" \
    && mysql -uroot -e "GRANT ALL PRIVILEGES ON zabbix.* TO 'zabbix'@'localhost';" \
    && mysql -uroot -e "SET GLOBAL log_bin_trust_function_creators = 1;" \
    && service mysql stop

# Importar el esquema y los datos de Zabbix
RUN service mysql start \
    && zcat /usr/share/zabbix-sql-scripts/mysql/server.sql.gz | mysql --default-character-set=utf8mb4 -uzabbix -p'zabbix_password' zabbix \
    && service mysql stop

# Deshabilitar log_bin_trust_function_creators
RUN service mysql start \
    && mysql -uroot -e "SET GLOBAL log_bin_trust_function_creators = 0;" \
    && service mysql stop

# Configurar Zabbix para usar la base de datos
RUN sed -i 's/^# DBPassword=/DBPassword=password/' /etc/zabbix/zabbix_server.conf

# Exponer el puerto de Zabbix frontend
EXPOSE 8080

# Iniciar Zabbix Server y Nginx
CMD ["bash", "-c", "service mysql start && service zabbix-server start && nginx -g 'daemon off;'"]
