#!/bin/bash

NicExt="ens33"
vlan20="ens38"
vlan60="ens37"

RedInterconexio="192.168.60.0/24"
RedDMZ="192.168.20.0/24"

# VPN
# DMZ
p_VPN_web="51820"
p_VPN_udp_traffic="51821"
vpn_server_DMZ="192.168.20.5"
# LAN
p_VPN_web_LAN="3333"
p_VPN_udp_traffic_LAN="2222"
router_LAN="192.168.20.2"
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
iptables -t nat -A PREROUTING -i $NicExt -p tcp --dport $p_VPN_web         -j DNAT --to-destination $vpn_server_DMZ:$p_VPN_web

iptables -t nat -A PREROUTING -i $NicExt -p udp --dport $p_VPN_udp_traffic -j DNAT --to-destination $vpn_server_DMZ:$p_VPN_udp_traffic

# Prerouting de la VPN
iptables -t nat -A PREROUTING -i $NicExt -p tcp --dport $p_VPN_web_LAN         -j DNAT --to-destination $router_LAN:$p_VPN_web

iptables -t nat -A PREROUTING -i $NicExt -p udp --dport $p_VPN_udp_traffic_LAN -j DNAT --to-destination $router_LAN:$p_VPN_udp_traffic

# Permetre el forwarding dels ports mapejats
iptables -A FORWARD -i $NicExt -p udp --dport $p_VPN_udp_traffic  -j ACCEPT
iptables -A FORWARD -o $NicExt -p udp --sport $p_VPN_udp_traffic  -j ACCEPT

iptables -A FORWARD -i $NicExt -p tcp --dport $p_VPN_web          -j ACCEPT
iptables -A FORWARD -o $NicExt -p tcp --sport $p_VPN_web          -j ACCEPT

iptables -A FORWARD -i $NicExt -p udp --dport $p_VPN_udp_traffic_LAN -j ACCEPT
iptables -A FORWARD -o $NicExt -p udp --sport $p_VPN_udp_traffic_LAN -j ACCEPT

iptables -A FORWARD -i $NicExt -p tcp --dport $p_VPN_web_LAN -j ACCEPT
iptables -A FORWARD -o $NicExt -p tcp --sport $p_VPN_web_LAN -j ACCEPT
# # Mapeo puertos DNS Server

# iptables -t nat -A PREROUTING -i $NicExt -p tcp --dport $puerto_dnserver_visible -j DNAT --to-destination $dnsserver:$puerto_dnserver_original

# iptables -A FORWARD -i $NicExt -p tcp --dport $puerto_dnserver_original -j ACCEPT
# iptables -A FORWARD -o $NicExt -p tcp --sport $puerto_dnserver_original -j ACCEPT