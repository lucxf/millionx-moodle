# Usar la imagen base de Zabbix Server MySQL
FROM zabbix/zabbix-server-mysql:ubuntu-4.4-latest

# Instalar Apache, PHP y los módulos necesarios
RUN apt-get update && \
    apt-get install -y apache2 php php-mysqli php-gd php-xml php-bcmath php-ldap zabbix-frontend-php && \
    rm -rf /var/lib/apt/lists/*

# Habilitar el módulo de PHP en Apache
RUN a2enmod php7.4

# Copiar la configuración personalizada de Apache para Zabbix Web
COPY ./zabbix-web.conf /etc/apache2/sites-available/000-default.conf

# Configurar la base de datos para Zabbix Web
COPY ./zabbix.conf.php /usr/share/zabbix/conf/zabbix.conf.php

# Habilitar el servicio Apache para que inicie al arrancar el contenedor
RUN systemctl enable apache2

# Exponer el puerto 80 para acceder a Zabbix Web
EXPOSE 80

# Comando para iniciar Apache y Zabbix Server
CMD ["bash", "-c", "service apache2 start && /usr/sbin/zabbix_server"]
