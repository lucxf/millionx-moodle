#!/bin/bash

config_zabbix_php_nginx() {
    local config_file="/etc/zabbix/nginx.conf"

    # Verificar si el archivo existe
    if [ ! -f "$config_file" ]; then
        log_error "El archivo $config_file no existe."
        exit 1
    fi

    # Log de inicio de configuración
    log_info "Configurando $config_file: descomentando y configurando listen y server_name..."

    # Usar sed para descomentar y configurar las directivas listen y server_name
    if sudo sed -i 's/^# listen 8080;/listen 8080;/' "$config_file" && \
       sudo sed -i 's/^# server_name example.com;/server_name example.com;/' "$config_file"; then
        log_info "La configuración de listen y server_name se ha actualizado correctamente en $config_file."
    else
        log_error "Error al modificar las directivas listen y server_name en $config_file."
        exit 1
    fi
}

start_zabbix_services() {
    log_info "Reiniciando los servicios de Zabbix, Nginx y PHP-FPM..."

    # Reiniciar los servicios
    if sudo systemctl restart zabbix-server zabbix-agent nginx php8.3-fpm; then
        log_info "Los servicios de Zabbix, Nginx y PHP-FPM han sido reiniciados correctamente."
    else
        log_error "Error al reiniciar los servicios de Zabbix, Nginx y PHP-FPM."
        exit 1
    fi

    log_info "Habilitando los servicios de Zabbix, Nginx y PHP-FPM para que se inicien al arranque..."

    # Habilitar los servicios
    if sudo systemctl enable zabbix-server zabbix-agent nginx php8.3-fpm; then
        log_info "Los servicios de Zabbix, Nginx y PHP-FPM se han habilitado correctamente para el inicio automático."
    else
        log_error "Error al habilitar los servicios de Zabbix, Nginx y PHP-FPM para el inicio automático."
        exit 1
    fi
}
