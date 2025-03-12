#!/bin/bash

NicExt="ens33"
vlan20="ens38"
vlan60="ens37"

RedInterconexio="192.168.60.0/24"
RedDMZ="192.168.20.0/24"

# VPN
p_VPN_web="51820"
p_VPN_udp_traffic="51821"
vpn_server="192.168.20.5"

# puerto_dnserver_visible="2333"
# dnsserver="192.168.20.241"
# puerto_dnserver_original="10000"

# Dirección IP de la interfaz ens33
IP_NicExt="172.30.10.13"

# Borramos reglas por defecto
iptables -F
iptables -t nat -F
iptables -X
iptables -Z

# Por defecto todo ACCEPT de momento
iptables -P INPUT   ACCEPT
iptables -P OUTPUT  ACCEPT
iptables -P FORWARD ACCEPT

# Aplicamos NAT
iptables -t nat -A POSTROUTING -s $RedDMZ          -o $NicExt -j MASQUERADE
iptables -t nat -A POSTROUTING -s $RedInterconexio -o $NicExt -j MASQUERADE

###################################################################################
###################################################################################

# VPN
# Prerouting de la VPN
iptables -t nat -A PREROUTING -i $NicExt -p tcp --dport 51821 -j DNAT --to-destination 192.168.40.2:51821

iptables -t nat -A PREROUTING -i $NicExt -p udp --dport 51820 -j DNAT --to-destination 192.168.40.2:51820

# Permetre el forwarding dels ports mapejats
iptables -A FORWARD -i $NicExt -p udp --dport $p_VPN_udp_traffic  -j ACCEPT
iptables -A FORWARD -o $NicExt -p udp --sport $p_VPN_udp_traffic  -j ACCEPT

iptables -A FORWARD -i $NicExt -p tcp --dport $p_VPN_web          -j ACCEPT
iptables -A FORWARD -o $NicExt -p tcp --sport $p_VPN_web          -j ACCEPT
# # Mapeo puertos DNS Server

# iptables -t nat -A PREROUTING -i $NicExt -p tcp --dport $puerto_dnserver_visible -j DNAT --to-destination $dnsserver:$puerto_dnserver_original

# iptables -A FORWARD -i $NicExt -p tcp --dport $puerto_dnserver_original -j ACCEPT
# iptables -A FORWARD -o $NicExt -p tcp --sport $puerto_dnserver_original -j ACCEPT

