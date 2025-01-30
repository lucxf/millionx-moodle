#/bin/bash

vlan3=
vlan60=

RedInterconexio="192.168.60.0/24"
RedLAN="10.0.0.0/8"

reds=($RedInterconexio $RedLAN)
targetes=($vlan60 $vlan3)

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

# quan Ip desti = red Interconnexio --> envia per la tarjeta de la red interconnexio vlan60
iptables -t nat -A POSTROUTING -d $RedInterconexio  -o $vlan60 -j MASQUERADE
# quan Ip desti = red Administracio --> envia per la tarjeta de la vlan 40
iptables -t nat -A POSTROUTING -d $RedLAN           -o $vlan3   -j MASQUERADE
