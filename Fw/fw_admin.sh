#/bin/bash

vlan40="ens33"
NicExt="ens37"

RedAdministracio="192.168.40.0/24"

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

# quan Ip desti = red Administracio --> envia per la tarjeta de la vlan 40
iptables -t nat -A POSTROUTING -d $RedAdministracio -o $vlan40   -j MASQUERADE
# quan Ip desti = red Interconnexio --> envia per la tarjeta de la red interconnexio NicExt
iptables -t nat -A POSTROUTING                      -o $NicExt -j MASQUERADE