#!/bin/bash

#     _______       __   __________  ____  _   ___________    __ 
#    / ____/ |     / /  / ____/ __ \/ __ \/ | / /_  __/   |  / / 
#   / /_   | | /| / /  / /_  / /_/ / / / /  |/ / / / / /| | / /  
#  / __/   | |/ |/ /  / __/ / _, _/ /_/ / /|  / / / / ___ |/ /___
# /_/      |__/|__/  /_/   /_/ |_|\____/_/ |_/ /_/ /_/  |_/_____/
                                                               
# Targetas
NicExt="ens33"
vlan20="ens38"
# 60 es la interconnexion
vlan60="ens37"

targetes=($NicExt $vlan20 $vlan60)
# Redes
RedInterconexio="192.168.60.0/24"
RedDMZ="192.168.20.0/24"
RedLAN="10.0.0.0/8"

redes=($RedInterconexio $RedDMZ $RedLAN)
# Puertos
p_SSH="22"
p_DNS="53"
p_http="80"
p_https="443"
p_VPN_udp_traffic_DMZ="51820"
p_VPN_udp_traffic_LAN="51821"
p_VPN_udp_traffic_LAN_router_LAN="51820"
# Maquines
vpn_server_DMZ="192.168.20.2"
router_LAN="192.168.60.2"
dns_server="192.168.20.5"
# Servicios y puertos de acceso
moodle_srv="192.168.20.10"
monitoring_srv="192.168.20.11"
nextcloud_srv="192.168.20.12"

p_access_moodle="8080"
p_access_zabbix="8080"
p_access_nextcloud="700"
p_access_grafana="3030"

#=================== BORRADO DE REGLAS ====================#

# Borramos reglas por defecto
iptables -F
iptables -t nat -F
iptables -X
iptables -Z

iptables -P INPUT   DROP
iptables -P OUTPUT  DROP
iptables -P FORWARD DROP

#=================== NAT ====================#

# Aplicamos NAT
iptables -t nat -A POSTROUTING -s $RedDMZ          -o $NicExt -j MASQUERADE
iptables -t nat -A POSTROUTING -s $RedInterconexio -o $NicExt -j MASQUERADE
iptables -t nat -A POSTROUTING -d $RedLAN          -o $vlan60 -j MASQUERADE
iptables -t nat -A POSTROUTING -d $RedInterconexio -o $vlan60 -j MASQUERADE
iptables -t nat -A POSTROUTING -d $RedDMZ          -o $vlan20 -j MASQUERADE

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
# Router
# 172.30.10.13:53/udp /tcp ---> 192.168.20.5:53 /udp /tcp (Servidor DNS LAN)
iptables -t nat -i $NicExt -A PREROUTING -p udp --dport $p_DNS -j DNAT --to-destination $dns_server:$p_DNS
iptables -t nat -i $NicExt -A PREROUTING -p tcp --dport $p_DNS -j DNAT --to-destination $dns_server:$p_DNS

# Router --> exterior
# UDP
iptables -A OUTPUT -o $NicExt -p udp --dport $p_DNS -j ACCEPT
iptables -A INPUT  -i $NicExt -p udp --sport $p_DNS -j ACCEPT
# TCP
iptables -A OUTPUT -o $NicExt -p tcp --dport $p_DNS -j ACCEPT
iptables -A INPUT  -i $NicExt -p tcp --sport $p_DNS -j ACCEPT

# Router --> DMZ
# UDP
iptables -A OUTPUT -o $vlan20 -p udp --dport $p_DNS -j ACCEPT
iptables -A INPUT  -i $vlan20 -p udp --sport $p_DNS -j ACCEPT
# TCP
iptables -A OUTPUT -o $vlan20 -p tcp --dport $p_DNS -j ACCEPT
iptables -A INPUT  -i $vlan20 -p tcp --sport $p_DNS -j ACCEPT

# Exterior --> Serivdor DNS
# TCP
iptables -A FORWARD -i $NicExt -o $vlan20 -p tcp -m multiport -d $dns_server --dports $p_DNS -j ACCEPT
iptables -A FORWARD -i $vlan20 -o $NicExt -p tcp -m multiport -s $dns_server --sports $p_DNS -j ACCEPT
# UDP
iptables -A FORWARD -i $NicExt -o $vlan20 -p udp -m multiport -d $dns_server --dports $p_DNS -j ACCEPT
iptables -A FORWARD -i $vlan20 -o $NicExt -p udp -m multiport -s $dns_server --sports $p_DNS -j ACCEPT

# Vlan60 ---> Vlan20
# TCP
iptables -A FORWARD -i $vlan60 -o $vlan20 -p tcp -m multiport -d $dns_server --dports $p_DNS -j ACCEPT
iptables -A FORWARD -i $vlan20 -o $vlan60 -p tcp -m multiport -s $dns_server --sports $p_DNS -j ACCEPT
# UDP
iptables -A FORWARD -i $vlan60 -o $vlan20 -p udp -m multiport -d $dns_server --dports $p_DNS -j ACCEPT
iptables -A FORWARD -i $vlan20 -o $vlan60 -p udp -m multiport -s $dns_server --sports $p_DNS -j ACCEPT

# Vlan20 ---> NicExt
# TCP
iptables -A FORWARD -i $vlan20 -o $NicExt -p tcp -m multiport --dports $p_DNS -j ACCEPT
iptables -A FORWARD -i $NicExt -o $vlan20 -p tcp -m multiport --sports $p_DNS -j ACCEPT
# UDP
iptables -A FORWARD -i $vlan20 -o $NicExt -p udp -m multiport --dports $p_DNS -j ACCEPT
iptables -A FORWARD -i $NicExt -o $vlan20 -p udp -m multiport --sports $p_DNS -j ACCEPT

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

#======================= SERVICES WEB ACCESS =======================#

# Exterior --> Router
iptables -A INPUT  -i $NicExt -p tcp -m multiport --dports $p_http,$p_https -j ACCEPT
iptables -A OUTPUT -o $NicExt -p tcp -m multiport --sports $p_http,$p_https -j ACCEPT

# Exterior --> DMZ
# Nextcloud
iptables -A INPUT  -i $vlan20 -p tcp --sport $p_access_nextcloud -j ACCEPT
iptables -A OUTPUT -o $vlan20 -p tcp --dport $p_access_nextcloud -j ACCEPT

iptables -A FORWARD -i $NicExt -o $vlan20 -d $nextcloud_srv -p tcp --dport $p_access_nextcloud -j ACCEPT
iptables -A FORWARD -i $vlan20 -o $NicExt -s $nextcloud_srv -p tcp --sport $p_access_nextcloud -j ACCEPT
# Zabbix
iptables -A INPUT  -i $vlan20 -p tcp --sport $p_access_zabbix -j ACCEPT
iptables -A OUTPUT -o $vlan20 -p tcp --dport $p_access_zabbix -j ACCEPT

iptables -A FORWARD -i $NicExt -o $vlan20 -d $monitoring_srv -p tcp --dport $p_access_zabbix -j ACCEPT
iptables -A FORWARD -i $vlan20 -o $NicExt -s $monitoring_srv -p tcp --sport $p_access_zabbix -j ACCEPT
# Grafana
iptables -A INPUT  -i $vlan20 -p tcp --sport $p_access_grafana -j ACCEPT
iptables -A OUTPUT -o $vlan20 -p tcp --dport $p_access_grafana -j ACCEPT

iptables -A FORWARD -i $NicExt -o $vlan20 -d $monitoring_srv -p tcp --dport $p_access_grafana -j ACCEPT
iptables -A FORWARD -i $vlan20 -o $NicExt -s $monitoring_srv -p tcp --sport $p_access_grafana -j ACCEPT
# Moodle
iptables -A INPUT  -i $vlan20 -p tcp --sport $p_access_moodle -j ACCEPT
iptables -A OUTPUT -o $vlan20 -p tcp --dport $p_access_moodle -j ACCEPT

iptables -A FORWARD -i $NicExt -o $vlan20 -d $moodle_srv -p tcp --dport $p_access_moodle -j ACCEPT
iptables -A FORWARD -i $vlan20 -o $NicExt -s $moodle_srv -p tcp --sport $p_access_moodle -j ACCEPT
#======================= VPN =======================#

# VPN traffic DMZ
# 172.30.10.13:51820/udp == 192.168.20.2:51820/udp
iptables -t nat -A PREROUTING  -i $NicExt -p udp --dport $p_VPN_udp_traffic_DMZ -j DNAT --to-destination $vpn_server_DMZ:$p_VPN_udp_traffic_DMZ
# Permito el forwarding de tramas por el puerto hacia el serivdor VPN
iptables -A FORWARD -i $NicExt -o $vlan20 -d $vpn_server_DMZ -p udp --dport $p_VPN_udp_traffic_DMZ -j ACCEPT
iptables -A FORWARD -i $vlan20 -o $NicExt -s $vpn_server_DMZ -p udp --sport $p_VPN_udp_traffic_DMZ -j ACCEPT

# VPN traffic LAN
# Como el 51821/udp está ocupado uso el 51821/udp (se ha de cambiar en el archivo peer)
# 172.30.10.13:51821/udp == 192.168.20.2:51820/udp
iptables -t nat -A PREROUTING -p udp --dport $p_VPN_udp_traffic_LAN -j DNAT --to-destination $router_LAN:$p_VPN_udp_traffic_LAN_router_LAN
# Permito el forwarding de tramas por el puerto hacia el serivdor VPN
iptables -A FORWARD -i $NicExt -o $vlan60 -p udp -d $router_LAN --dport $p_VPN_udp_traffic_LAN_router_LAN -j ACCEPT
iptables -A FORWARD -i $vlan60 -o $NicExt -p udp -s $router_LAN --sport $p_VPN_udp_traffic_LAN_router_LAN -j ACCEPT

#======================= SSH =======================#
# Permitimos SSH al router
iptables -A INPUT  -i $NicExt -p tcp --dport $p_SSH -j ACCEPT
iptables -A OUTPUT -o $NicExt -p tcp --sport $p_SSH -j ACCEPT
# Permitir ssh hacie el router de la red LAN
iptables -A OUTPUT -o $vlan60 -p tcp -d $router_LAN --dport $p_SSH -j ACCEPT
iptables -A INPUT  -i $vlan60 -p tcp -s $router_LAN --sport $p_SSH -j ACCEPT

#=============== TRAFICO LOOPBACK ===================#

# Permitir tráfico local (loopback)
iptables -A INPUT  -i lo -j ACCEPT
iptables -A OUTPUT -o lo -j ACCEPT