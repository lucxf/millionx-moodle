#!/bin/bash

NicExt="ens33"
vlan20="ens38"
vlan60="ens37"

RedInterconexio="192.168.60.0/24"
RedLAN="10.0.0.0/8"
RedDMZ="192.168.20.0/24"

puerto_dns_visible="2333"
dnsserver="192.168.20.241"
puerto_dns_original="10000"

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

##########################################################################################################

# APLICAMOS NAT

# NAT para las redes
iptables -t nat -A POSTROUTING -d $RedInterconexio -o $vlan60 -j MASQUERADE
iptables -t nat -A POSTROUTING -d $RedLAN -o $vlan60 -j MASQUERADE
iptables -t nat -A POSTROUTING -d $RedDMZ -o $vlan20 -j MASQUERADE

# Redireccionamiento del tráfico de vlan60 a ens33
iptables -t nat -A PREROUTING -i $vlan60 -j DNAT --to-destination $IP_NicExt
iptables -A FORWARD -i $vlan60 -o $NicExt -j ACCEPT
iptables -A FORWARD -i $NicExt -o $vlan60 -j ACCEPT

# Redireccionamiento del tráfico de vlan20 a ens33
iptables -t nat -A PREROUTING -i $vlan20 -j DNAT --to-destination $IP_NicExt
iptables -A FORWARD -i $vlan20 -o $NicExt -j ACCEPT
iptables -A FORWARD -i $NicExt -o $vlan20 -j ACCEPT

# Mapeo puertos DNS Server

iptables -t nat -A PREROUTING -i $NicExt -p tcp --dport $puerto_dns_visible -j DNAT --to-destination $dnsserver:$puerto_dns_original

iptables -A FORWARD -i $NicExt -p tcp --dport $puerto_dns_original -j ACCEPT
iptables -A FORWARD -o $NicExt -p tcp --sport $puerto_dns_original -j ACCEPT
