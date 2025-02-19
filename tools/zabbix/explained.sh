#!/bin/bash

#############################################
# SECTION 1: INITIAL SETUP AND VARIABLES
#############################################

# Create log directory and file
LOGFILE="/var/log/Project/zabbix_installation.log"
mkdir -p "$(dirname $LOGFILE)"  # Create log directory if it doesn't exist

# Define color codes for terminal output
green="32m"   # Success messages
red="31m"     # Error messages
yellow="33m"  # Warning messages
blue="34m"    # Information messages
magenta="35m" # Highlight messages
cyan="36m"    # Secondary information
white="37m"   # Normal text
reset="0m"    # Reset text color to default

# Configuration variables
MYSQL_ROOT_PASSWORD="your_root_password"    # MySQL root user password
ZABBIX_DB_PASSWORD="your_zabbix_password"   # Zabbix database user password
DOMAIN_NAME="example.com"                   # Your server's domain name
LISTEN_PORT="8080"                          # Port for Zabbix web interface

#############################################
# SECTION 2: LOGGING FUNCTIONS
#############################################

# Function: Log error messages and exit script
# Parameters: $1 - Error message to log
# Actions: 
#   1. Logs to file and terminal
#   2. Displays in red
#   3. Calls cleanup
#   4. Exits with error code 1
log_error() {
    echo "$(date) - ERROR: $1" | tee -a $LOGFILE
    echo -e "\033[$red$(date) - ERROR: $1\033[0m"
    cleanup
    exit 1
}

# Function: Log informational messages
# Parameters: $1 - Info message to log
# Actions:
#   1. Logs to file and terminal
#   2. Displays in green
log_info() {
    echo "$(date) - INFO: $1" | tee -a $LOGFILE
    echo -e "\033[$green$(date) - INFO: $1\033[0m"
}

#############################################
# SECTION 3: CLEANUP FUNCTION
#############################################

# Function: Clean up system in case of failure
# Actions:
#   1. Stops all services
#   2. Removes Zabbix packages
#   3. Removes MySQL if installed by this script
#   4. Cleans up repositories and packages
cleanup() {
    log_info "Starting cleanup process..."
    
    # Stop all related services gracefully
    systemctl stop zabbix-server zabbix-agent nginx php8.3-fpm mysql 2>/dev/null || true
    
    # Remove all Zabbix-related packages
    apt-get remove --purge -y zabbix-server-mysql zabbix-frontend-php \
        zabbix-nginx-conf zabbix-sql-scripts zabbix-agent 2>/dev/null || true
    
    # Remove MySQL only if we installed it
    if [ -f "/var/lib/mysql/.installed_by_zabbix" ]; then
        log_info "Removing MySQL server..."
        apt-get remove --purge -y mysql-server mysql-client 2>/dev/null || true
        rm -rf /var/lib/mysql
        rm -rf /etc/mysql
    fi
    
    # Clean up Zabbix repository files
    rm -f /etc/apt/sources.list.d/zabbix.list
    rm -f zabbix-release_latest_7.2+ubuntu24.04_all.deb
    
    # Clean up package manager
    apt-get autoremove -y
    apt-get clean
    
    log_info "Cleanup completed"
}

#############################################
# SECTION 4: MYSQL MANAGEMENT FUNCTIONS
#############################################

# Function: Check MySQL installation status
# Returns: 
#   0 - MySQL is installed and accessible
#   1 - MySQL is not installed or not accessible
check_mysql_installation() {
    # Check if MySQL service is running
    if systemctl is-active --quiet mysql; then
        log_info "MySQL is already installed and running"
        
        # Try to connect without password first (default installation state)
        if mysql -u root -e "SELECT 1" &>/dev/null; then
            log_info "MySQL root access without password successful"
            return 0
        # Try to connect with provided password
        elif mysql -u root -p"${MYSQL_ROOT_PASSWORD}" -e "SELECT 1" &>/dev/null; then
            log_info "MySQL root access with provided password successful"
            return 0
        else
            # Cannot connect with or without password
            log_error "MySQL is installed but cannot access with provided credentials. Please provide correct MySQL root password in MYSQL_ROOT_PASSWORD variable"
        fi
    else
        log_info "MySQL is not running or not installed"
        return 1
    fi
}

# Function: Secure MySQL installation
# Actions:
#   1. Sets root password
#   2. Removes anonymous users
#   3. Disables remote root login
#   4. Removes test database
secure_mysql() {
    log_info "Securing MySQL installation..."
    
    # Try to secure MySQL without password first (fresh installation)
    if mysql -u root <<EOF
ALTER USER 'root'@'localhost' IDENTIFIED WITH mysql_native_password BY '${MYSQL_ROOT_PASSWORD}';
DELETE FROM mysql.user WHERE User='';
DELETE FROM mysql.user WHERE User='root' AND Host NOT IN ('localhost', '127.0.0.1', '::1');
DROP DATABASE IF EXISTS test;
DELETE FROM mysql.db WHERE Db='test' OR Db='test\\_%';
FLUSH PRIVILEGES;
EOF
    then
        log_info "MySQL secured successfully"
        return 0
    else
        # If failed, try with the provided password (existing installation)
        if mysql -u root -p"${MYSQL_ROOT_PASSWORD}" <<EOF
DELETE FROM mysql.user WHERE User='';
DELETE FROM mysql.user WHERE User='root' AND Host NOT IN ('localhost', '127.0.0.1', '::1');
DROP DATABASE IF EXISTS test;
DELETE FROM mysql.db WHERE Db='test' OR Db='test\\_%';
FLUSH PRIVILEGES;
EOF
        then
            log_info "MySQL secured successfully with provided password"
            return 0
        else
            log_error "Failed to secure MySQL. Please check your MySQL root password"
        fi
    fi
}

#############################################
# SECTION 5: MAIN INSTALLATION PROCESS
#############################################

# Check if script is run as root
if [ "$EUID" -ne 0 ]; then 
    log_error "Please run as root (sudo -s)"
fi

# Main installation block with error handling
{
    #------------------------------------
    # Step 1: MySQL Setup
    #------------------------------------
    # Check and install MySQL if needed
    if ! check_mysql_installation; then
        log_info "Installing MySQL Server..."
        apt update || log_error "Failed to update package list"
        apt install -y mysql-server || log_error "Failed to install MySQL server"
        
        # Mark MySQL as installed by this script
        touch "/var/lib/mysql/.installed_by_zabbix"
        
        # Ensure MySQL is running
        systemctl start mysql || log_error "Failed to start MySQL service"
    fi
    
    # Secure MySQL installation
    secure_mysql
    
    #------------------------------------
    # Step 2: System Locale Setup
    #------------------------------------
    log_info "Configuring locales..."
    apt-get install -y locales || log_error "Failed to install locales"
    locale-gen en_US.UTF-8 || log_error "Failed to generate locale"
    update-locale LANG=en_US.UTF-8 LC_ALL=en_US.UTF-8 || log_error "Failed to update locale"
    export LANG=en_US.UTF-8
    export LC_ALL=en_US.UTF-8

    #------------------------------------
    # Step 3: Zabbix Repository Setup
    #------------------------------------
    log_info "Installing Zabbix repository..."
    wget https://repo.zabbix.com/zabbix/7.2/release/ubuntu/pool/main/z/zabbix-release/zabbix-release_latest_7.2+ubuntu24.04_all.deb || \
        log_error "Failed to download Zabbix repository"
    dpkg -i zabbix-release_latest_7.2+ubuntu24.04_all.deb || log_error "Failed to install Zabbix repository"
    apt update || log_error "Failed to update package list"

    #------------------------------------
    # Step 4: Zabbix Components Installation
    #------------------------------------
    log_info "Installing Zabbix components..."
    apt install -y zabbix-server-mysql zabbix-frontend-php \
        zabbix-nginx-conf zabbix-sql-scripts zabbix-agent || \
        log_error "Failed to install Zabbix components"

    #------------------------------------
    # Step 5: Database Configuration
    #------------------------------------
    log_info "Configuring MySQL database..."
    mysql -uroot -p"${MYSQL_ROOT_PASSWORD}" <<EOF || log_error "Failed to configure Zabbix database"
create database zabbix character set utf8mb4 collate utf8mb4_bin;
create user zabbix@localhost identified by '${ZABBIX_DB_PASSWORD}';
grant all privileges on zabbix.* to zabbix@localhost;
set global log_bin_trust_function_creators = 1;
EOF

    # Import Zabbix schema
    log_info "Importing initial schema..."
    zcat /usr/share/zabbix/sql-scripts/mysql/server.sql.gz | \
        mysql --default-character-set=utf8mb4 -uzabbix -p"${ZABBIX_DB_PASSWORD}" zabbix || \
        log_error "Failed to import schema"

    # Configure MySQL settings
    log_info "Configuring function creators..."
    mysql -uroot -p"${MYSQL_ROOT_PASSWORD}" <<EOF || log_error "Failed to configure MySQL settings"
set global log_bin_trust_function_creators = 0;
EOF

    #------------------------------------
    # Step 6: Zabbix Server Configuration
    #------------------------------------
    log_info "Configuring Zabbix server..."
    sed -i "s/# DBPassword=/DBPassword=${ZABBIX_DB_PASSWORD}/" /etc/zabbix/zabbix_server.conf || \
        log_error "Failed to configure Zabbix server"

    #------------------------------------
    # Step 7: PHP Configuration
    #------------------------------------
    log_info "Configuring PHP..."
    cat > /etc/php/8.3/fpm/conf.d/99-zabbix.ini <<EOF || log_error "Failed to configure PHP"
[PHP]
max_execution_time = 300
memory_limit = 128M
post_max_size = 16M
upload_max_filesize = 2M
max_input_time = 300
date.timezone = UTC
EOF

    #------------------------------------
    # Step 8: Nginx Configuration
    #------------------------------------
    log_info "Configuring Nginx..."
    sed -i "s/# listen/listen ${LISTEN_PORT}/" /etc/zabbix/nginx.conf || \
        log_error "Failed to configure Nginx port"
    sed -i "s/# server_name/server_name ${DOMAIN_NAME}/" /etc/zabbix/nginx.conf || \
        log_error "Failed to configure Nginx server name"

    #------------------------------------
    # Step 9: Service Management
    #------------------------------------
    log_info "Starting services..."
    systemctl restart mysql || log_error "Failed to start MySQL"
    systemctl enable mysql || log_error "Failed to enable MySQL"
    systemctl restart zabbix-server zabbix-agent nginx php8.3-fpm || \
        log_error "Failed to start Zabbix services"
    systemctl enable zabbix-server zabbix-agent nginx php8.3-fpm || \
        log_error "Failed to enable Zabbix services"

    #------------------------------------
    # Step 10: Installation Complete
    #------------------------------------
    echo -e "\033[$green Installation completed successfully!\033[0m"
    echo -e "Please access Zabbix UI at:\033[$green http://${DOMAIN_NAME}:${LISTEN_PORT}\033[0m"
    echo -e "\033[$green Default credentials:\033[0m"
    echo -e "Username: \033[$green Admin\033[0m"
    echo -e "Password: \033[$green zabbix\033[0m"
    echo -e "MySQL root password:\033[$green ${MYSQL_ROOT_PASSWORD}\033[0m"
    echo -e "Zabbix database password:\033[$green ${ZABBIX_DB_PASSWORD}\033[0m"
    echo -e "\033[$red Please save these passwords in a secure location.\033[0m"

} || {
    # Error handler for the entire installation block
    log_error "Installation failed. Check the log file at $LOGFILE for details"
}