#/bin/bash

vlan40=
vlan60=

RedInterconexio="192.168.60.0/24"
RedAdministracio="192.168.40.0/24"

reds=($RedInterconexio $RedAdministracio)
targetes=($vlan60 $vlan40)

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
iptables -t nat -A POSTROUTING -d $RedAdministracio -o $vlan40   -j MASQUERADE
