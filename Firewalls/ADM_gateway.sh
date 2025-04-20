#/bin/bash

#     _______       __             __          _     
#    / ____/ |     / /  ____ _____/ /___ ___  (_)___ 
#   / /_   | | /| / /  / __ `/ __  / __ `__ \/ / __ \
#  / __/   | |/ |/ /  / /_/ / /_/ / / / / / / / / / /
# /_/      |__/|__/   \__,_/\__,_/_/ /_/ /_/_/_/ /_/ 
                                                   
# Targetas
vlan40="ens33"
NicExt="ens37"

targetas=($NicExt $vlan40)

#Redes
RedAdministracio="192.168.40.0/24"
RedVpn="10.8.0.0/24"

# Puertos
p_SSH="22"
p_http="80"
p_https="443"
p_DNS="53"
p_VPN_udp_traffic="51820"

# Maquines
vpn_server="192.168.40.2"

#=================== BORRADO DE REGLAS ANTIGUAS ==================#

# Borramos reglas por defecto
iptables -F
# Borro todas las reglas NAT
iptables -t nat -F
# Borro reglas de filtrado
iptables -X
iptables -Z

iptables -P INPUT   DROP
iptables -P OUTPUT  DROP
iptables -P FORWARD DROP

#=================== NAT ====================#

# Si Ip origen = Exterior y Ip destino = Red de administarcion lo envio al a VLAN40
iptables -t nat -A POSTROUTING -d $RedAdministracio -o $vlan40 -j MASQUERADE
# Si Ip origen = Red de administarcion y Ip destino = Exterior lo envio a la tarjeta externa
iptables -t nat -A POSTROUTING -s $RedAdministracio -o $NicExt -j MASQUERADE

#======================= ICMP =======================#

# ROUTER
for targeta in ${targetas[@]};
do
    iptables -A INPUT  -i $targeta -p icmp --icmp-type echo-request -j ACCEPT
    iptables -A OUTPUT -o $targeta -p icmp --icmp-type echo-reply   -j ACCEPT
    iptables -A INPUT  -i $targeta -p icmp --icmp-type echo-reply   -j ACCEPT
    iptables -A OUTPUT -o $targeta -p icmp --icmp-type echo-request -j ACCEPT
done

# VLAN40 (permito forwarding de tramas ICMP)
iptables -A FORWARD -d $RedAdministracio -p icmp --icmp-type echo-request -j ACCEPT
iptables -A FORWARD -s $RedAdministracio -p icmp --icmp-type echo-reply   -j ACCEPT
iptables -A FORWARD -d $RedAdministracio -p icmp --icmp-type echo-reply   -j ACCEPT
iptables -A FORWARD -s $RedAdministracio -p icmp --icmp-type echo-request -j ACCEPT

#======================= DNS =======================#

# ROUTER --> Exterior
iptables -A OUTPUT -o $NicExt -p udp --dport $p_DNS -j ACCEPT
iptables -A INPUT  -i $NicExt -p udp --sport $p_DNS -j ACCEPT

# VLAN40 --> Exterior
iptables -A FORWARD -i $vlan40 -o $NicExt -p udp --dport $p_DNS -j ACCEPT
iptables -A FORWARD -i $NicExt -o $vlan40 -p udp --sport $p_DNS -j ACCEPT

iptables -A FORWARD -i $vlan40 -o $NicExt -p tcp --dport $p_DNS -j ACCEPT
iptables -A FORWARD -i $NicExt -o $vlan40 -p tcp --sport $p_DNS -j ACCEPT
#================ UPDATE/UPGRADE ====================#

# ROUTER (mirar como hacer que solo se a los repos, no a otro lado)
iptables -A OUTPUT -o $NicExt -p tcp -m multiport --dports $p_http,$p_https -j ACCEPT
iptables -A INPUT  -i $NicExt -p tcp -m multiport --sports $p_http,$p_https -j ACCEPT

# VLAN40 (Permito el forwarding de tramas desde la VLAN40)
iptables -A FORWARD -i $vlan40 -o $NicExt -p tcp -m multiport --dports $p_http,$p_https -j ACCEPT
iptables -A FORWARD -i $NicExt -o $vlan40 -p tcp -m multiport --sports $p_http,$p_https -j ACCEPT

#======================= VPN =======================#

# VPN traffic
# 172.30.10.21:21820/udp == 192.168.40.2:51820/udp
iptables -t nat -A PREROUTING  -i $NicExt -p udp --dport $p_VPN_udp_traffic -j DNAT --to-destination $vpn_server:$p_VPN_udp_traffic
# Permito el forwarding de las tramas por el puerto indicado hacia el servidor VPN
iptables -A FORWARD -i $NicExt -o $vlan40 -d $vpn_server -p udp --dport $p_VPN_udp_traffic -j ACCEPT
iptables -A FORWARD -i $vlan40 -o $NicExt -s $vpn_server -p udp --sport $p_VPN_udp_traffic -j ACCEPT

#======================= SSH =======================#
# Permito SSH hacia el router
iptables -A INPUT  -i $NicExt -p tcp --dport $p_SSH -j ACCEPT
iptables -A OUTPUT -o $NicExt -p tcp --sport $p_SSH -j ACCEPT
# Permito SSH desde el Router hacia la VLAN40
iptables -A INPUT  -i $vlan40 -p tcp --sport $p_SSH -j ACCEPT
iptables -A OUTPUT -o $vlan40 -p tcp --dport $p_SSH -j ACCEPT

#=============== TRAFICO LOOPBACK ===================#

# Permitir tráfico local (loopback)
iptables -A INPUT -i lo -j ACCEPT
iptables -A OUTPUT -o lo -j ACCEPT
