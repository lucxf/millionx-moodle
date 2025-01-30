#!/bin/bash

NicExt=
vlan20=
vlan60=

RedInterconexio="192.168.60.0/24"
RedDMZ="192.168.20.0/24"

reds=($RedInterconexio $RedDMZ)
targetes=($vlan60 $vlan20)
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
iptables -t nat -A POSTROUTING -d $RedInterconexio -o $vlan60 -j MASQUERADE
# quan Ip desti = red DMZ --> envia per la tarjeta de la vlan 20
iptables -t nat -A POSTROUTING -d $RedDMZ          -o $vlan20   -j MASQUERADE
# Si no es cumpleix cap norma anterior envia directament a la vlan30 per sortir a internet
iptables -t nat -A POSTROUTING                     -o $NicExt   -j MASQUERADE
