# Usa la imagen base de nginx
FROM nginx:latest

# Instala Zabbix y dependencias
RUN wget https://repo.zabbix.com/zabbix/7.0/ubuntu/pool/main/z/zabbix-release/zabbix-release_latest_7.0+ubuntu24.04_all.deb \
    && dpkg -i zabbix-release_latest_7.0+ubuntu24.04_all.deb \
    && apt update -y && apt upgrade -y \
    && apt install -y zabbix-server-mysql zabbix-frontend-php zabbix-nginx-conf zabbix-sql-scripts zabbix-agent mysql-server

# Copiar archivo .env
COPY .env /root/.env

# Configurar MySQL y Zabbix usando las variables de entorno
RUN export $(cat /root/.env | xargs) \
    && service mysql start \
    && mysql -uroot -e "CREATE DATABASE ${MYSQL_DB} CHARACTER SET utf8mb4 COLLATE utf8mb4_bin;" \
    && mysql -uroot -e "CREATE USER '${MYSQL_USER}'@'localhost' IDENTIFIED BY '${MYSQL_PASSWORD}';" \
    && mysql -uroot -e "GRANT ALL PRIVILEGES ON ${MYSQL_DB}.* TO '${MYSQL_USER}'@'localhost';" \
    && mysql -uroot -e "SET GLOBAL log_bin_trust_function_creators = 1;" \
    && service mysql stop

# Importar el esquema y los datos de Zabbix
RUN export $(cat /root/.env | xargs) \
    && service mysql start \
    && zcat /usr/share/zabbix-sql-scripts/mysql/server.sql.gz | mysql --default-character-set=utf8mb4 -u${MYSQL_USER} -p${MYSQL_PASSWORD} ${MYSQL_DB} \
    && service mysql stop

# Deshabilitar log_bin_trust_function_creators
RUN export $(cat /root/.env | xargs) \
    && service mysql start \
    && mysql -uroot -e "SET GLOBAL log_bin_trust_function_creators = 0;" \
    && service mysql stop

# Configurar Zabbix para usar la base de datos
RUN export $(cat /root/.env | xargs) \
    && sed -i "s/^# DBPassword=/DBPassword=${MYSQL_PASSWORD}/" /etc/zabbix/zabbix_server.conf

# Exponer el puerto de Zabbix frontend
EXPOSE 8080

# Iniciar Zabbix Server y Nginx
CMD ["bash", "-c", "service mysql start && service zabbix-server start && nginx -g 'daemon off;'"]
