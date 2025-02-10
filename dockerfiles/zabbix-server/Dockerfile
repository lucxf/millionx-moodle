FROM nginx:latest

RUN wget https://repo.zabbix.com/zabbix/7.0/ubuntu/pool/main/z/zabbix-release/zabbix-release_latest_7.0+ubuntu24.04_all.deb
RUN dpkg -i zabbix-release_latest_7.0+ubuntu24.04_all.deb
RUN apt update -y && apt upgrade -y

RUN apt install zabbix-server-mysql zabbix-frontend-php zabbix-nginx-conf zabbix-sql-scripts zabbix-agent -y

