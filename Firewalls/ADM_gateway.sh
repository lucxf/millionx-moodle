#/bin/bash

# Targetas
vlan40="ens33"
NicExt="ens37"

#Redes
RedAdministracio="192.168.40.0/24"

# Puertos
p_ssh="22"
p_http="80"
p_https="443"
p_DNS="53"
p_VPN_web="51820"
p_VPN_udp_traffic="51821"

# Maquines
vpn_server="192.168.40.2"

# MACs SSH
mac_Lluc=" 74:56:3C:07:E7:2A"
mac_Eric=""
mac_Marc=""
mac_Ania=""

macs_ssh=($mac_Lluc)

#=================== BORRADO DE REGLAS ANTIGUAS ==================#

# Borramos reglas por defecto
iptables -F
# Borro todas las reglas NAT
iptables -t nat -F
# Borro reglas de filtrado
iptables -X
iptables -Z
# Por defecto todo ACCEPT de momento
iptables -P INPUT   DROP
iptables -P OUTPUT  DROP
iptables -P FORWARD DROP

#=================== NAT ====================#

# Si Ip origen = Exterior y Ip destino = Red de administarcion lo envio al a VLAN40
iptables -t nat -A POSTROUTING -d $RedAdministracio -o $vlan40 -j MASQUERADE
# Si Ip origen = Red de administarcion y Ip destino = Exterior lo envio a la tarjeta externa
iptables -t nat -A POSTROUTING -s $RedAdministracio -o $NicExt -j MASQUERADE

#================ UPDATE/UPGRADE ====================#

# ROUTER (mirar como hacer que solo se a los repos, no a otro lado)
iptables -A OUTPUT -o $NicExt -p tcp -m multiport --dports $p_http,$p_https -j ACCEPT
iptables -A INPUT  -i $NicExt -p tcp -m multiport --dports $p_http,$p_https -j ACCEPT

# VLAN40 (Permito el forwarding de tramas desde la VLAN40)
iptables -A FORWARD -i $vlan40 -o $NicExt -p tcp -m multiport --dports $p_http,$p_https -j ACCEPT
iptables -A FORWARD -i $NicExt -o $vlan40 -p tcp -m multiport --dports $p_http,$p_https -j ACCEPT

#======================= ICMP =======================#

iptables -A INPUT  -p icmp --icmp-type echo-request -j ACCEPT
iptables -A OUTPUT -p icmp --icmp-type echo-reply   -j ACCEPT

iptables -A OUTPUT -p icmp --icmp-type echo-request -j ACCEPT
iptables -A INPUT  -p icmp --icmp-type echo-reply   -j ACCEPT

iptables -A FORWARD -p icmp --icmp-type echo-request -j ACCEPT
iptables -A FORWARD -p icmp --icmp-type echo-reply   -j ACCEPT

#======================= DNS =======================#

# ROUTER
iptables -A OUTPUT -o $NicExt -p udp --dport $p_DNS -j ACCEPT
iptables -A INPUT  -i $NicExt -p udp --sport $p_DNS -j ACCEPT

# VLAN40
iptables -A FORWARD -i $vlan40 -o $NicExt -p udp --dport $p_DNS -j ACCEPT
iptables -A FORWARD -i $NicExt -o $vlan40 -p udp --sport $p_DNS -j ACCEPT

#======================= VPN =======================#

# VPN web config
iptbales -t nat -A PREROUTING  -i $NicExt     -p tcp --dport $p_VPN_web -j DNAT --to-destination $vpn_server:$p_VPN_web

iptbales -A FORWARD -i $NicExt -o $vlan40 -d $RedAdministracio -p tcp --dport $p_VPN_web -j ACCEPT
iptables -A FORWARD -i $vlan40 -o $NicExt -s $RedAdministracio -p tcp --sport $p_VPN_web -j ACCEPT

# VPN traffic
iptables -t nat -A PREROUTING -i $NicExt -p udp --dport $p_VPN_udp_traffic -j DNAT --to-destination $vpn_server:$p_VPN_udp_traffic

iptables -A FORWARD -i $NicExt -o $vlan40 -d $RedAdministracio -p udp --dport $p_VPN_udp_traffic -j ACCEPT
iptables -A FORWARD -i $vlan40 -o $NicExt -s $RedAdministracio -p udp --sport $p_VPN_udp_traffic -j ACCEPT

#======================= SSH =======================#

for mac in ${macs_ssh[@]}; 
do
    iptables -A INPUT  -i $NicExt -p tcp --dport $p_SSH -m mac --mac-source $mac -j ACCEPT
    iptables -A OUTPUT -o $NicExt -p tcp --sport $p_SSH -m mac --mac-source $mac -j ACCEPT
done