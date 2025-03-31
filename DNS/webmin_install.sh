#!/bin/bash

# Archivo de log
LOGFILE="/var/log/Project/webmin_installation.log"

# Función para escribir errores en el log y mostrar el mensaje en rojo
log_error() {
    # Registrar el error en el archivo de log
    echo "$(date) - ERROR: $1" | tee -a $LOGFILE
    # Mostrar el error en la terminal en rojo
    echo -e "\033[31m$(date) - ERROR: $1\033[0m"
    # Detener la ejecución del script
    exit 1
}

# Antes de instalar la herramienta, actualizamos los paquetes disponibles en los repositorios
echo -e "\033[34mActualizando los paquetes disponibles en los repositorios...\033[0m"
if ! sudo apt update -y && sudo apt upgrade -y; then
    log_error "Error al ejecutar 'apt update' o 'apt upgrade'."
fi

# Instalamos las dependencias necesarias
echo -e "\033[34mInstalando dependencias necesarias...\033[0m"
if ! sudo apt install software-properties-common apt-transport-https -y; then
    log_error "Error al ejecutar 'apt install' para dependencias."
fi

# Habilitamos el repositorio de Webmin
echo -e "\033[34mAñadiendo la clave GPG del repositorio de Webmin...\033[0m"
if ! sudo wget -q http://www.webmin.com/jcameron-key.asc -O- | sudo apt-key add -; then
    log_error "Error al añadir la clave GPG de Webmin."
fi

# Agregamos el repositorio de Webmin manualmente
echo -e "\033[34mAñadiendo el repositorio de Webmin...\033[0m"
if ! sudo add-apt-repository "deb [arch=amd64] http://download.webmin.com/download/repository sarge contrib"; then
    log_error "Error al agregar el repositorio de Webmin."
fi

# Instalamos Webmin
echo -e "\033[34mInstalando Webmin...\033[0m"
if ! sudo apt install webmin -y; then
    log_error "Error al instalar Webmin."
fi


# Comprobamos la versión de Webmin
echo -e "\033[34mComprobando la versión de Webmin...\033[0m"
if ! dpkg -l | grep webmin; then
    log_error "Error al verificar la versión de Webmin."
fi

# Abrimos el firewall en el puerto que usaremos para Webmin
echo -e "\033[34mAbriendo el puerto 10000/tcp en el firewall...\033[0m"
if ! sudo ufw allow 10000/tcp; then
    log_error "Error al abrir el puerto 10000/tcp en el firewall."
fi

# Actualizamos el firewall
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

# Mensaje de éxito en verde
echo -e "\033[32mWebmin instalado correctamente\033[0m"