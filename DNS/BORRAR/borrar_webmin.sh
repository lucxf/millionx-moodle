#!/bin/bash

# Detener el servicio de Webmin
sudo systemctl stop webmin

# Desinstalar Webmin
sudo apt remove --purge -y webmin

# Eliminar el repositorio de Webmin
sudo add-apt-repository --remove "deb [arch=amd64] http://download.webmin.com/download/repository sarge contrib"

# Eliminar la clave GPG de Webmin
sudo apt-key del JCameron

# Limpiar cualquier paquete obsoleto y dependencias innecesarias
sudo apt autoremove -y
sudo apt autoclean

# Opcional: cerrar el puerto de Webmin en el firewall
sudo ufw deny 10000/tcp

# Verificar el estado del firewall
sudo ufw status

echo "Webmin ha sido desinstalado correctamente."

