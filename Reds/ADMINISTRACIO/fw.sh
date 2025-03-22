#/bin/bash

vlan40="ens33"
NicExt="ens37"

RedAdministracio="192.168.40.0/24"

# VPN
p_VPN_web="51820"
p_VPN_udp_traffic="51821"
vpn_server="192.168.40.2"


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
iptables -t nat -A POSTROUTING -d $RedAdministracio -o $vlan40 -j MASQUERADE
# quan Ip desti = red Interconnexio --> envia per la tarjeta de la red interconnexio NicExt
iptables -t nat -A POSTROUTING -o $NicExt                      -j MASQUERADE

# ########################################################################################################

# PREROUTING (prts mapeados)

# Prerouting de la VPN
iptables -t nat -A PREROUTING -i $NicExt -p tcp --dport 51821 -j DNAT --to-destination 192.168.40.2:51821

iptables -t nat -A PREROUTING -i $NicExt -p udp --dport 51820 -j DNAT --to-destination 192.168.40.2:51820
##############################################################################################

# Permetre el forwarding dels ports mapejats
iptables -A FORWARD -i $NicExt -p udp --dport $p_VPN_udp_traffic  -j ACCEPT
iptables -A FORWARD -o $NicExt -p udp --sport $p_VPN_udp_traffic  -j ACCEPT

iptables -A FORWARD -i $NicExt -p tcp --dport $p_VPN_web          -j ACCEPT
iptables -A FORWARD -o $NicExt -p tcp --sport $p_VPN_web          -j ACCEPT