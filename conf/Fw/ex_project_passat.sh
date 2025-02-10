
#        /$$   /$$             /$$                        /$$$$$$ /$$$$$$$$       /$$$$$$$$ /$$      /$$
#       | $$  /$$/            | $$                       |_  $$_/|__  $$__/      | $$_____/| $$  /$ | $$
#       | $$ /$$/   /$$$$$$$ /$$$$$$   /$$   /$$  /$$$$$$$ | $$     | $$         | $$      | $$ /$$$| $$
#       | $$$$$/   /$$_____/|_  $$_/  | $$  | $$ /$$_____/ | $$     | $$         | $$$$$   | $$/$$ $$ $$
#       | $$  $$  | $$        | $$    | $$  | $$|  $$$$$$  | $$     | $$         | $$__/   | $$$$_  $$$$
#       | $$\  $$ | $$        | $$ /$$| $$  | $$ \____  $$ | $$     | $$         | $$      | $$$/ \  $$$
#       | $$ \  $$|  $$$$$$$  |  $$$$/|  $$$$$$/ /$$$$$$$//$$$$$$   | $$         | $$      | $$/   \  $$
#       |__/  \__/ \_______/   \___/   \______/ |_______/|______/   |__/         |__/      |__/     \__/

#=========================================  VARIABLES  =================================================

#!/bin/bash

#        RED 10  DMZ    RED 20 BKP      RED 30 DPT
reds=("172.18.0.0/16" "172.19.0.0/16" "10.0.0.0/20")
targetes=("ens33" "ens37" "ens38")
#            ODOO   WORDPRESS
#portsAcces=("5000" "7000")
#portsServeis=("6089" "80")
#              ODOO     WORDPRESS
#srvsServeis=("172.18.10.4" "172.18.10.3")

contador=0

# Reds i targetes de red
red10="172.18.0.0/16"
vlan10="ens33"

red20="172.19.0.0/16"
vlan20="ens37"

red30="10.0.0.0/20"
vlan30="ens38"

# IP's
srvwordpress="172.18.10.4"
srvodoo="172.18.10.3"
srvzabbix="100.27.71.66"
srvBKP="172.19.20.3"
NAS="172.19.20.3"

# Mac's
macLluc="00:15:5D:00:14:14"

macOdoo="00:0C:29:EA:9B:F6"
macWordpress="00:0C:29:BE:AB:B6"
macBKP="00:0C:29:6A:A6:A0"

#================================================  PREPARACIÓ PREVIA  ===================================================

# Borro regles inicials
iptables -F
# Set a 0 els contadors
iptables -X
# Borro regles de cadenes
iptables -Z
# Borro reglas NAT inicials
iptables -t nat -F


# Politca per defecte DROP
iptables -P INPUT   DROP
iptables -P OUTPUT  DROP
iptables -P FORWARD DROP

# Permeto trames per la interficie de loopback

iptables -A OUTPUT -o lo -j ACCEPT
iptables -A INPUT  -i lo -j ACCEPT

#==================================================  SSH  ============================================================
# Permetre ssh des de VLAN30 al router
iptables -A INPUT  -i $vlan30 -p tcp --dport 22 -m mac --mac-source $macLluc -j ACCEPT
iptables -A OUTPUT -o $vlan30 -p tcp --sport 22 -j ACCEPT

# Per a que accedeixi Jose Luis
# Permetre ssh des de VLAN30 al router
iptables -A INPUT  -i $vlan30 -p tcp --dport 22 -j ACCEPT
iptables -A OUTPUT -o $vlan30 -p tcp --sport 22 -j ACCEPT

#===================================================  ENRUTAMENT  ======================================================

# APLIQUEM NAT

# Faig un bucle que indiqui que quan es vulgui arribar a una red s' envii per la seva tarjeta corresponent

num_reds="${#reds[@]}"

while [[ $contador -lt $num_reds ]]
do
        red="${reds[$contador]}"
        targeta="${targetes[$contador]}"
        iptables -t nat -A POSTROUTING -d $red -o $targeta -j MASQUERADE
        # vaig sumant 1 al contador quan arribi a 3 no entrarà (només tenim 3 reds)
        contador=$((contador + 1))
done

# quan Ip desti = red 10 --> envia per la tarjeta de la vlan 10
# quan Ip desti = red 20 --> envia per la tarjeta de la vlan 20
# quan Ip desti = red 30 --> envia per la tarjeta de la vlan 30

# Si no es cumpleix cap norma anterior envia directament a la vlan30 per sortir a internet
iptables -t nat -A POSTROUTING -o $vlan30 -j MASQUERADE

#========================================  FER PUBLIC L' ACCÉS ALS SERVEIS  ============================================

# PREROUTING

# http://10.0.10.22:5000 --> tradueix a --> http://172.18.10.3:8069
iptables -t nat -A PREROUTING -i $vlan30 -p tcp --dport 5000 -j DNAT --to-destination $srvodoo:8069
# http://10.0.10.22:7000 --> tradueix a --> http://172.18.10.4:80
iptables -t nat -A PREROUTING -i $vlan30 -p tcp --dport 7000 -j DNAT --to-destination $srvwordpress:80

# Permetre el forwarding dels ports mapejats

iptables -A FORWARD -i $vlan30 -s $red30 -p tcp --dport 8069 -d $srvodoo -j ACCEPT
iptables -A FORWARD -o $vlan30 -d $red30 -p tcp --sport 8069 -s $srvodoo -j ACCEPT

iptables -A FORWARD -i $vlan30 -s $red30 -p tcp --dport 80 -d $srvwordpress -j ACCEPT
iptables -A FORWARD -o $vlan30 -d $red30 -p tcp --sport 80 -s $srvwordpress -j ACCEPT

# Permetre la entrada de les trames al router en si

iptables -A INPUT -i $vlan30 -s $red30 -p tcp --dport 7000 -j ACCEPT
iptables -A OUTPUT -o $vlan30 -d $red30 -p tcp --sport 7000 -j ACCEPT

iptables -A INPUT -i $vlan30 -s $red30 -p tcp --dport 5000 -j ACCEPT
iptables -A OUTPUT -o $vlan30 -d $red30 -p tcp --sport 5000 -j ACCEPT

#==========================================  UPDATE & UPGRADE & INSTALL  ================================================

# VLAN 10
iptables -A FORWARD -i $vlan10 -o $vlan30 -p tcp -m multiport --dports 80,443 -j ACCEPT
iptables -A FORWARD -i $vlan30 -o $vlan10 -p tcp -m multiport --sports 80,443 -j ACCEPT

# VLAN 20
iptables -A FORWARD -i $vlan20 -o $vlan30 -p tcp -m multiport --dports 80,443 -j ACCEPT
iptables -A FORWARD -i $vlan30 -o $vlan20 -p tcp -m multiport --sports 80,443 -j ACCEPT

# ROUTER
iptables -A OUTPUT -o $vlan30 -p tcp -m multiport --dports 80,443 -j ACCEPT
iptables -A INPUT -i $vlan30 -p tcp -m multiport --sports 80,443 -j ACCEPT

#=====================================  ICMP  ===========================================================================

# Permeto des de qualsevol origen a qualsevol desti ICMP

iptables -A INPUT  -p icmp --icmp-type echo-request -j ACCEPT
iptables -A OUTPUT -p icmp --icmp-type echo-reply -j ACCEPT

iptables -A INPUT  -p icmp --icmp-type echo-reply -j ACCEPT
iptables -A OUTPUT -p icmp --icmp-type echo-request -j ACCEPT

iptables -A FORWARD -p icmp --icmp-type echo-request -j ACCEPT
iptables -A FORWARD -p icmp --icmp-type echo-reply -j ACCEPT

iptables -A FORWARD -p icmp --icmp-type echo-request -j ACCEPT
iptables -A FORWARD -p icmp --icmp-type echo-reply -j ACCEPT

#===================================================  DNS  ==============================================================

# DES DE VLAN 10

iptables -A FORWARD -i $vlan10 -o $vlan30 -p udp --dport 53 -j ACCEPT
iptables -A FORWARD -o $vlan10 -i $vlan30 -p udp --sport 53 -j ACCEPT

# DES DE VLAN 20

iptables -A FORWARD -i $vlan20 -o $vlan30 -p udp --dport 53 -j ACCEPT
iptables -A FORWARD -o $vlan20 -i $vlan30 -p udp --sport 53 -j ACCEPT

# DES DE VLAN 30

#iptables -A OUTPUT -o $vlan30 -p udp --dport 53 -j ACCEPT
#iptables -A INPUT -i $vlan30 -p udp --sport 53 -j ACCEPT

#==================================================  ZABBIX  ============================================================


# Zabbix utilitza el port 10051, hem de permetre que les maquines es connectin a ell
#(pendent a restringir amb mac)

# Odoo ---> SRV ZABBIX
iptables -A FORWARD -i $vlan10 -o $vlan30 -p tcp --dport 10051 -m mac --mac-source $macOdoo -d $srvzabbix  -j ACCEPT
iptables -A FORWARD -i $vlan30 -o $vlan10 -p tcp --sport 10051 -s $srvzabbix -j ACCEPT

# Wordpress --> SRV ZABBIX
iptables -A FORWARD -i $vlan10 -o $vlan30 -p tcp --dport 10051 -m mac --mac-source $macWordpress -d $srvzabbix -j ACCEPT
iptables -A FORWARD -i $vlan30 -o $vlan10 -p tcp --sport 10051 -s $srvzabbix -j ACCEPT

# WindowsBKP --> SRV ZABBIX
iptables -A FORWARD -i $vlan20 -o $vlan30 -p tcp --dport 10051 -m mac --mac-source $macBKP -d $srvzabbix  -j ACCEPT
iptables -A FORWARD -i $vlan30 -o $vlan20 -p tcp --sport 10051 -s $srvzabbix -j ACCEPT

# Router --> SRV ZABBIX
iptables -A OUTPUT -o $vlan30 -p tcp --dport 10051 -d $srvzabbix -j ACCEPT
iptables -A INPUT -i $vlan30 -p tcp --sport 10051 -s $srvzabbix -j ACCEPT

# NAS --> SRV ZABBIX
iptables -A FORWARD -i $vlan20 -o $vlan30 -p tcp --dport 10051 -s $NAS -d $srvzabbix -j ACCEPT
iptables -A FORWARD -i $vlan30 -o $vlan20 -p tcp --sport 10051 -s $srvzabbix -j ACCEPT

#==================================================  CONNEXIO A MSSQL  ============================================================

# SQL SERVER Utilitza el port 1433 per a connectar-se
# Permetrem forward per a que des de la vlan 20 podem accedir a mssql

iptables -A FORWARD -i $vlan20 -o $vlan10 -p tcp --dport 1433 -d $srvodoo -j ACCEPT
iptables -A FORWARD -i $vlan10 -o $vlan20 -p tcp --sport 1433 -s $srvodoo -j ACCEPT


# guardem les normes
iptables-save > /etc/iptables/rules.v4