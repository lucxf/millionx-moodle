#!/bin/bash

RedInterna=192.168.6.0/24
NicExt=ens33

wg_port=51820
wireguardWeb=51821
wireguardSRV=192.168.6.20

# Borramos todas las reglas por defecto
iptables -F
iptables -t nat -F
iptables -X
iptables -Z

# Establecemos las políticas por defecto a ACCEPT
iptables -P INPUT   ACCEPT
iptables -P OUTPUT  ACCEPT
iptables -P FORWARD ACCEPT

# aplica NAT a todo aquello que salga de la red interna
iptables -t nat -A POSTROUTING -s $RedInterna -o $NicExt -j MASQUERADE

# Mapeamos puertos del wireguard
iptables -t nat -A PREROUTING -i $NicExt -p tcp --dport $wireguardWeb -j DNAT --to-destination $wireguardSRV:$wireguardWeb

# Hacer el forwarding del puerto del wireguard 51820 udp

iptables -A FORWARD -i $NicExt -p udp --dport $wg_port -j ACCEPT
iptables -A FORWARD -o $NicExt -p udp --sport $wg_port -j ACCEPT