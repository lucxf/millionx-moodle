#!/bin/bash

# Archivo de log
LOGFILE="/var/log/Project/bind_installation.log"
# Zona DNS
DOMAIN=$1
NS1=$2
NS2=$3
NS3=$4
IP=$5
USER=$6
ZONE_FILE="/etc/bind/$DOMAIN"

# Función para escribir errores en el log y mostrar el mensaje en rojo
log_error() {
    # Registrar el error en el archivo de log
    echo "$(date) - ERROR: $1" | tee -a $LOGFILE
    # Mostrar el error en la terminal en rojo
    echo -e "\033[31m$(date) - ERROR: $1\033[0m"
    # Detener la ejecución del script
    exit 1
}

# Crear el directorio de logs si no existe
mkdir -p /var/log/Project

# Comenzamos la instalación de BIND DNS
echo -e "\033[34mInstalando BIND DNS...\033[0m"
if ! sudo apt update -y && sudo apt upgrade -y; then
    log_error "Error al ejecutar 'apt update' o 'apt upgrade'."
fi

if ! sudo apt install -y bind9 bind9utils bind9-doc; then
    log_error "Error al instalar BIND DNS (bind9)."
fi

# Configuración de la zona DNS

# Creamos el archivo de zona para '$DOMAIN'
echo -e "\033[34mCreando el archivo de zona DNS para $DOMAIN...\033[0m"

# Comprobamos si ya existe el archivo de zona
if [ -f $ZONE_FILE ]; then
    log_error "El archivo de zona '$ZONE_FILE' ya existe. Por favor, elimina el archivo o revisa permisos."
fi

cat << EOF | sudo tee $ZONE_FILE > /dev/null
\$TTL 38400  ; Tiempo (seg) de vida por defecto (TTL)
$DOMAIN. IN SOA ns1.$DOMAIN. $USER.$DOMAIN. (
    2023110701 ; Serial
    10800      ; Refresh
    3600       ; Retry
    604800     ; Expire
    38400      ; Minimum TTL
)

; Servidores DNS
$DOMAIN. IN NS ns1.$DOMAIN.
$DOMAIN. IN NS ns2.$DOMAIN.
$DOMAIN. IN NS ns3.$DOMAIN.
$DOMAIN. IN A $IP
; Direcciones IP
ns1.$DOMAIN. IN A $NS1
ns2.$DOMAIN. IN A $NS2
ns3.$DOMAIN. IN A $NS3
www.$DOMAIN. IN A $IP
moodle.$DOMAIN. IN A $IP
zabbix.$DOMAIN. IN A $IP
grafana.$DOMAIN. IN A $IP
nextcloud.$DOMAIN. IN A $IP
webmin-dns.$DOMAIN. IN A $IP
EOF

if [ $? -ne 0 ]; then
    log_error "Error al crear el archivo de zona '$ZONE_FILE'."
fi

# Configuración de BIND para que reconozca la nueva zona

# Configuración en 'named.conf.local'
echo -e "\033[34mConfigurando el archivo de zonas en named.conf.local...\033[0m"

if ! sudo bash -c "cat <<EOF > /etc/bind/named.conf.local
zone \"$DOMAIN.\" {
    type master;
    file \"/etc/bind/$DOMAIN\";
};
EOF"; then
    log_error "Error al configurar la zona en '/etc/bind/named.conf.local'."
fi

# Configuración de BIND (named.conf.options)
echo -e "\033[34mConfigurando las opciones de BIND...\033[0m"
cat <<EOF | sudo tee /etc/bind/named.conf.options > /dev/null
options {
    directory "/var/cache/bind";

    forwarders {
        1.1.1.1;
        8.8.8.8;
    };

    dnssec-validation auto;
    listen-on { any; };
    listen-on-v6 { any; };
    allow-query { any; };
};
EOF

if [ $? -ne 0 ]; then
    log_error "Error al crear el archivo de opciones de BIND '/etc/bind/named.conf.options'."
fi

# Verificamos si el servicio BIND está corriendo, si no lo está, lo iniciamos
echo -e "\033[34mVerificando si BIND está activo...\033[0m"
if ! sudo systemctl is-active --quiet bind9; then
    echo -e "\033[34mIniciando el servicio BIND...\033[0m"
    if ! sudo systemctl start bind9; then
        log_error "No se pudo iniciar BIND DNS."
    fi
else
    echo -e "\033[32mBIND ya está activo.\033[0m"
fi

# Recargamos BIND para que cargue la nueva configuración
echo -e "\033[34mRecargando BIND...\033[0m"
if ! sudo systemctl reload bind9; then
    log_error "Error al recargar BIND después de añadir la zona."
fi

# Comprobamos si la zona está configurada correctamente
echo -e "\033[34mVerificando la zona DNS...\033[0m"
if ! sudo named-checkzone $DOMAIN /etc/bind/$DOMAIN; then
    log_error "Error al comprobar la zona DNS con 'named-checkzone'."
fi

# Habilitamos el firewall para permitir tráfico en el puerto 53 (DNS)
echo -e "\033[34mConfigurando el firewall para permitir tráfico DNS...\033[0m"
if ! sudo ufw allow 53/tcp && sudo ufw allow 53/udp; then
    log_error "Error al permitir el tráfico DNS en el firewall."
fi

# Activamos y recargamos el firewall
echo -e "\033[34mHabilitando y recargando el firewall...\033[0m"
if ! sudo ufw enable; then
    log_error "Error al habilitar el firewall."
fi

if ! sudo ufw reload; then
    log_error "Error al recargar el firewall."
fi

# Verificamos el estado del firewall
echo -e "\033[34mVerificando el estado del firewall...\033[0m"
if ! sudo ufw status; then
    log_error "Error al verificar el estado del firewall."
fi

echo -e "\033[32mInstalación y configuración de BIND DNS completada con éxito.\033[0m"

# Fin del script
exit 0