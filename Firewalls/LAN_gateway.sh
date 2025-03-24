#/bin/bash

vlan3="ens37"
vlan60="ens33"

targetes=($vlan3 $vlan60)

RedInterconexio="192.168.60.0/24"
RedLAN="10.0.0.0/8"

vpn_server="10.3.0.3"

p_SSH="22"
p_http="80"
p_https="443"
p_DNS="53"
p_VPN_udp_traffic="51820"

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

iptables -t nat -A POSTROUTING -s $RedLAN -o $vlan60 -j MASQUERADE

#======================= ICMP =======================#

# ROUTER
for targeta in ${targetes[@]};
do
    iptables -A INPUT  -i $targeta -p icmp --icmp-type echo-request -j ACCEPT
    iptables -A OUTPUT -o $targeta -p icmp --icmp-type echo-reply   -j ACCEPT
    iptables -A INPUT  -i $targeta -p icmp --icmp-type echo-reply   -j ACCEPT
    iptables -A OUTPUT -o $targeta -p icmp --icmp-type echo-request -j ACCEPT
done

# vlan3 (permito forwarding de tramas ICMP)
iptables -A FORWARD -p icmp --icmp-type echo-request -j ACCEPT
iptables -A FORWARD -p icmp --icmp-type echo-reply   -j ACCEPT

#======================= DNS =======================#

# ROUTER
iptables -A OUTPUT -o $vlan60 -p udp --dport $p_DNS -j ACCEPT
iptables -A INPUT  -i $vlan60 -p udp --sport $p_DNS -j ACCEPT

# vlan3
iptables -A FORWARD -i $vlan3  -o $vlan60 -p udp --dport $p_DNS -j ACCEPT
iptables -A FORWARD -i $vlan60 -o $vlan3  -p udp --sport $p_DNS -j ACCEPT

#================ UPDATE/UPGRADE ====================#

# ROUTER (mirar como hacer que solo se a los repos, no a otro lado)
iptables -A OUTPUT -o $vlan60 -p tcp -m multiport --dports $p_http,$p_https -j ACCEPT
iptables -A INPUT  -i $vlan60 -p tcp -m multiport --sports $p_http,$p_https -j ACCEPT

# vlan3 (Permito el forwarding de tramas desde la vlan3)
iptables -A FORWARD -i $vlan3 -o $vlan60 -p tcp -m multiport --dports $p_http,$p_https -j ACCEPT
iptables -A FORWARD -i $vlan60 -o $vlan3 -p tcp -m multiport --sports $p_http,$p_https -j ACCEPT

#======================= VPN =======================#

# VPN traffic

iptables -A OUTPUT -o $vlan60 -p udp -m multiport --dports $p_VPN_udp_traffic -j ACCEPT
iptables -A INPUT  -i $vlan60 -p udp -m multiport --sports $p_VPN_udp_traffic -j ACCEPT

iptables -t nat -A PREROUTING  -i $vlan60 -p udp --dport $p_VPN_udp_traffic -j DNAT --to-destination $vpn_server:$p_VPN_udp_traffic

iptables -A FORWARD -i $vlan60 -o $vlan3  -d $RedLAN -p udp --dport $p_VPN_udp_traffic -j ACCEPT
iptables -A FORWARD -i $vlan3  -o $vlan60 -s $RedLAN -p udp --sport $p_VPN_udp_traffic -j ACCEPT

#======================= SSH =======================#

iptables -A INPUT  -i $vlan60 -p tcp --dport $p_SSH -j ACCEPT
iptables -A OUTPUT -o $vlan60 -p tcp --sport $p_SSH -j ACCEPT

iptables -A OUTPUT -o $vlan3 -p tcp --dport $p_SSH -j ACCEPT
iptables -A INPUT  -i $vlan3 -p tcp --sport $p_SSH -j ACCEPT

#=============== TRAFICO LOOPBACK ===================#

# Permitir tráfico local (loopback)
iptables -A INPUT  -i lo -j ACCEPT
iptables -A OUTPUT -o lo -j ACCEPT
