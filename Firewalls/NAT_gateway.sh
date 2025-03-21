#!/bin/bash

# Targetas
NicExt="ens33"
vlan20="ens38"
# 60 es la interconnexion
vlan60="ens37"

targetes=($NicExt $vlan20 $vlan60)
# Redes
RedInterconexio="192.168.60.0/24"
RedDMZ="192.168.20.0/24"
Red_LAN="10.0.0.0/8"

redes=($RedInterconexio $RedDMZ $RedLAN)
# Puertos
p_SSH="22"
p_DNS="53"
p_http="80"
p_https="443"
p_VPN_udp_traffic="51821"

# Maquines
vpn_server="192.168.20.12"

#=================== BORRADO DE REGLAS ====================#

# Borramos reglas por defecto
iptables -F
iptables -t nat -F
iptables -X
iptables -Z
# Por defecto todo ACCEPT de momento
iptables -P INPUT   DROP
iptables -P OUTPUT  DROP
iptables -P FORWARD DROP

#=================== NAT ====================#

# Aplicamos NAT
iptables -t nat -A POSTROUTING -s $RedDMZ          -o $NicExt -j MASQUERADE
iptables -t nat -A POSTROUTING -s $RedInterconexio -o $NicExt -j MASQUERADE
iptables -t nat -A POSTROUTING -d $Red_LAN         -o $vlan60 -j MASQUERADE
iptables -t nat -A POSTROUTING -d $RedInterconexio -o $vlan60 -j MASQUERADE

#======================= ICMP =======================#

# ROUTER
for targeta in ${targetes[@]};
do
    iptables -A INPUT  -i $targeta -p icmp --icmp-type echo-request -j ACCEPT
    iptables -A OUTPUT -o $targeta -p icmp --icmp-type echo-reply   -j ACCEPT
    iptables -A INPUT  -i $targeta -p icmp --icmp-type echo-reply   -j ACCEPT
    iptables -A OUTPUT -o $targeta -p icmp --icmp-type echo-request -j ACCEPT
done

# VLAN20 y VLAN3
for red in ${redes[@]};
do
    iptables -A FORWARD -d $red -p icmp --icmp-type echo-request -j ACCEPT
    iptables -A FORWARD -s $red -p icmp --icmp-type echo-reply   -j ACCEPT
    iptables -A FORWARD -d $red -p icmp --icmp-type echo-reply   -j ACCEPT
    iptables -A FORWARD -s $red -p icmp --icmp-type echo-request -j ACCEPT
done

#======================= DNS =======================#

# # ROUTER
iptables -A OUTPUT -o $NicExt -p udp --dport $p_DNS -j ACCEPT
iptables -A INPUT  -i $NicExt -p udp --sport $p_DNS -j ACCEPT

# Falta habilitar al SRV DNS propio
# VLAN20
iptables -A FORWARD -i $vlan20 -o $NicExt -p udp --dport $p_DNS -j ACCEPT
iptables -A FORWARD -i $NicExt -o $vlan20 -p udp --sport $p_DNS -j ACCEPT

# # VLAN60
iptables -A FORWARD -i $vlan60 -o $NicExt -p udp --dport $p_DNS -j ACCEPT
iptables -A FORWARD -i $NicExt -o $vlan60 -p udp --sport $p_DNS -j ACCEPT

#================ UPDATE/UPGRADE ====================#

# ROUTER (mirar como hacer que solo se a los repos, no a otro lado)
iptables -A OUTPUT -o $NicExt -p tcp -m multiport --dports $p_http,$p_https -j ACCEPT
iptables -A INPUT  -i $NicExt -p tcp -m multiport --sports $p_http,$p_https -j ACCEPT
# Falta comprovar si funciona
# vlan20
iptables -A FORWARD -i $vlan20 -o $NicExt -p tcp -m multiport --dports $p_http,$p_https -j ACCEPT
iptables -A FORWARD -i $NicExt -o $vlan20 -p tcp -m multiport --sports $p_http,$p_https -j ACCEPT

# vlan60
iptables -A FORWARD -i $vlan60 -o $NicExt -p tcp -m multiport --dports $p_http,$p_https -j ACCEPT
iptables -A FORWARD -i $NicExt -o $vlan60 -p tcp -m multiport --sports $p_http,$p_https -j ACCEPT

#======================= VPN =======================#

# VPN traffic
iptables -t nat -A PREROUTING  -i $NicExt -p udp --dport $p_VPN_udp_traffic -j DNAT --to-destination $vpn_server:$p_VPN_udp_traffic

iptables -A FORWARD -i $NicExt -o $vlan20 -d $RedDMZ -p udp --dport $p_VPN_udp_traffic -j ACCEPT
iptables -A FORWARD -i $vlan20 -o $NicExt -s $RedDMZ -p udp --sport $p_VPN_udp_traffic -j ACCEPT

#======================= SSH =======================#

iptables -A INPUT  -i $NicExt -p tcp --dport $p_SSH -j ACCEPT
iptables -A OUTPUT -o $NicExt -p tcp --sport $p_SSH -j ACCEPT

iptables -A INPUT  -i $vlan20 -p tcp --sport $p_SSH -j ACCEPT
iptables -A OUTPUT -o $vlan20 -p tcp --dport $p_SSH -j ACCEPT

iptables -A INPUT  -i $vlan60 -p tcp --sport $p_SSH -j ACCEPT
iptables -A OUTPUT -o $vlan60 -p tcp --dport $p_SSH -j ACCEPT

#=============== TRAFICO LOOPBACK ===================#

# Permitir tráfico local (loopback)
iptables -A INPUT  -i lo -j ACCEPT
iptables -A OUTPUT -o lo -j ACCEPT
