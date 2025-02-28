#/bin/bash

vlan40="ens33"
NicExt="ens37"

RedAdministracio="192.168.40.0/24"

# Proxmox
p_Proxmox_original="8006"

p_Proxmox_visible_1="4731"
p_Proxmox_visible_2="4732"
p_Proxmox_visible_3="4733"
p_Proxmox_visible_4="4734"

proxmox1="192.168.40.10"
proxmox2="192.168.40.11"
proxmox3="192.168.40.12"
proxmox4="192.168.40.13"

# VPN
p_VPN_web="51820"
p_VPN_udp_traffic="51821"
vpn_server="192.168.40.111"

# NAS
p_nas_visible="10001"
p_nas_original="10000"
nas="192.168.40.14"


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

# Temporal, hay que borrar el PREROUTING
# ########################################################################################################

# PREROUTING (prts mapeados)

# Prerouting de proxmox
iptables -t nat -A PREROUTING -i $NicExt -p tcp --dport $p_Proxmox_visible_1 -j DNAT --to-destination $proxmox1:$p_Proxmox_original
iptables -t nat -A PREROUTING -i $NicExt -p tcp --dport $p_Proxmox_visible_2 -j DNAT --to-destination $proxmox2:$p_Proxmox_original
iptables -t nat -A PREROUTING -i $NicExt -p tcp --dport $p_Proxmox_visible_3 -j DNAT --to-destination $proxmox3:$p_Proxmox_original
iptables -t nat -A PREROUTING -i $NicExt -p tcp --dport $p_Proxmox_visible_4 -j DNAT --to-destination $proxmox4:$p_Proxmox_original

# Permito ssh al proxomox1
iptables -t nat -A PREROUTING -i $NicExt -p tcp --dport 4000                 -j DNAT --to-destination $proxmox1:22

# Prerouting de la VPN
# Interfaz web TCP
iptables -t nat -A PREROUTING -i $NicExt -p tcp --dport $p_VPN_web           -j DNAT --to-destination $vpn_server:$p_VPN_web
# Tunel VPN UDP
iptables -t nat -A PREROUTING -i $NicExt -p udp --dport $p_VPN_udp_traffic   -j DNAT --to-destination $vpn_server:$p_VPN_udp_traffic

##############################################################################################

# Permetre el forwarding dels ports mapejats
iptables -A FORWARD -i $NicExt -p tcp --dport $p_Proxmox_original -j ACCEPT
iptables -A FORWARD -o $NicExt -p tcp --sport $p_Proxmox_original -j ACCEPT

iptables -A FORWARD -i $NicExt -p udp --dport $p_VPN_udp_traffic  -j ACCEPT
iptables -A FORWARD -o $NicExt -p udp --sport $p_VPN_udp_traffic  -j ACCEPT

iptables -A FORWARD -i $NicExt -p tcp --dport $p_VPN_web          -j ACCEPT
iptables -A FORWARD -o $NicExt -p tcp --sport $p_VPN_web          -j ACCEPT

# iptables -A FORWARD -i $NicExt -p tcp --dport $p_nas_original -j ACCEPT
# iptables -A FORWARD -o $NicExt -p tcp --sport $p_nas_original -j ACCEPT

