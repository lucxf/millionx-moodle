#/bin/bash

vlan3="ens37"
vlan60="ens33"

RedInterconexio="192.168.60.0/24"
RedLAN="10.0.0.0/8"

# Borramos reglas por defecto
iptables -F
# Borro todas las reglas NAT
iptables -t nat -F
# Borro reglas de filtrado
iptables -X
iptables -Z

# Por defecto todo ACCEPT de momento
iptables -P INPUT   ACCEPT
iptables -P OUTPUT  ACCEPT
iptables -P FORWARD ACCEPT

##########################################################################################################

# APLIQUEM NAT

iptables -t nat -A POSTROUTING -s $RedLAN -o $vlan60 -j MASQUERADE