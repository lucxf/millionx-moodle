#!/bin/bash

# Archivo de log
LOGFILE="/var/log/Project/docker_installation.log"

# Función para escribir errores en el log y mostrar el mensaje en rojo
log_error() {
    # Registrar el error en el archivo de log
    echo "$(date) - ERROR: $1" | tee -a $LOGFILE
    # Mostrar el error en la terminal en rojo
    echo -e "\033[31m$(date) - ERROR: $1\033[0m"
    # Detener la ejecución del script
    exit 1
}

# Eliminar archivos de paquetes .deb que ya no se pueden descargar
echo -e "\033[34mLimpiando paquetes obsoletos...\033[0m"
if ! sudo apt-get autoclean -y; then
    log_error "Error al ejecutar 'apt-get autoclean'."
fi

# # Eliminar versiones antiguas de Docker o paquetes conflictivos
# echo -e "\033[34mEliminando versiones antiguas de Docker...\033[0m"
# if ! sudo apt-get remove -y docker docker-engine docker.io containerd runc; then
#     log_error "Error al ejecutar 'apt-get remove' para Docker."
# fi

# Limpiar cualquier paquete obsoleto o dependencias innecesarias
echo -e "\033[34mLimpiando dependencias obsoletas...\033[0m"
if ! sudo apt-get autoremove -y; then
    log_error "Error al ejecutar 'apt-get autoremove'."
fi

# # Actualizar el sistema
# echo -e "\033[34mActualizando el sistema...\033[0m"
# if ! sudo apt update -y && sudo apt upgrade -y; then
#     log_error "Error al ejecutar 'apt update' o 'apt upgrade'."
# fi

# Instalar certificados y herramienta de transferencia de datos
echo -e "\033[34mInstalando certificados y herramientas de transferencia de datos...\033[0m"
if ! sudo apt-get install -y ca-certificates curl; then
    log_error "Error al ejecutar 'apt-get install' para ca-certificates o curl."
fi

# Crear un directorio seguro para llaves de repositorios APT
echo -e "\033[34mCreando directorio para llaves de repositorios...\033[0m"
if ! sudo install -m 0755 -d /etc/apt/keyrings; then
    log_error "Error al crear el directorio '/etc/apt/keyrings'."
fi

# Descargar y guardar la clave GPG de Docker
echo -e "\033[34mDescargando la clave GPG de Docker...\033[0m"
if ! sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc; then
    log_error "Error al descargar la clave GPG de Docker."
fi

# Otorgar permisos de lectura a todos los usuarios para la clave GPG de Docker
echo -e "\033[34mAsignando permisos a la clave GPG de Docker...\033[0m"
if ! sudo chmod a+r /etc/apt/keyrings/docker.asc; then
    log_error "Error al cambiar los permisos de '/etc/apt/keyrings/docker.asc'."
fi

# Agregar el repositorio de Docker a las fuentes de Apt
echo -e "\033[34mAgregando el repositorio de Docker a las fuentes de APT...\033[0m"
if ! echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null; then
    log_error "Error al agregar el repositorio Docker en '/etc/apt/sources.list.d/docker.list'."
fi

# Actualizar lista de paquetes después de agregar el repositorio Docker
echo -e "\033[34mActualizando la lista de paquetes después de agregar Docker...\033[0m"
if ! sudo apt-get update -y; then
    log_error "Error al ejecutar 'apt-get update' después de agregar el repositorio Docker."
fi

# Instalar Docker Engine, CLI, Containerd, Buildx y Compose plugins
echo -e "\033[34mInstalando Docker...\033[0m"
if ! sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin; then
    log_error "Error al ejecutar 'apt-get install' para Docker."
fi

# Verificar que Docker esté correctamente instalado
echo -e "\033[34mVerificando la instalación de Docker...\033[0m"
if ! sudo docker --version; then
    log_error "Docker no se instaló correctamente o el comando 'docker --version' falló."
else
    echo -e "\033[32mDocker se ha instalado correctamente.\033[0m"
fi

echo -e "\033[32mDocker instalado correctamente\033[0m"
