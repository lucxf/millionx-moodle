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

# quan Ip desti = red LAN --> envia per la tarjeta de la vlan 3
iptables -t nat -A POSTROUTING -d $RedLAN           -o $vlan3   -j MASQUERADE
# Por defecto que lo envie a interconexion
iptables -t nat -A POSTROUTING                      -o $vlan60   -j MASQUERADE