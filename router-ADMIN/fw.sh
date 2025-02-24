#/bin/bash

vlan40="ens33"
NicExt="ens37"

RedAdministracio="192.168.40.0/24"

puerto_Proxmox_visible_1="4731"
puerto_Proxmox_visible_2="4732"
puerto_Proxmox_visible_3="4733"
puerto_Proxmox_visible_4="4734"
puerto_vpn_visible="51821"
puerto_nas_visible="10001"
puerto_ubundesk_visible="51830"

puerto_vpn_original="51821"
puerto_nas_original="10000"
puerto_Proxmox_original="8006"

proxmox1="192.168.40.10"
proxmox2="192.168.40.11"
proxmox3="192.168.40.12"
proxmox4="192.168.40.13"
nas="192.168.40.14"
vpn_admin_server="192.168.40.222"
ubuntu_desktop="192.168.40.223"

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
iptables -t nat -A POSTROUTING -o $NicExt -j MASQUERADE

# Temporal, hay que borrar el PREROUTING
# ########################################################################################################

# PREROUTING (puertos mapeados)
iptables -t nat -A PREROUTING -i $NicExt -p tcp --dport $puerto_Proxmox_visible_1 -j DNAT --to-destination $proxmox1:$puerto_Proxmox_original
iptables -t nat -A PREROUTING -i $NicExt -p tcp --dport $puerto_Proxmox_visible_2 -j DNAT --to-destination $proxmox2:$puerto_Proxmox_original
iptables -t nat -A PREROUTING -i $NicExt -p tcp --dport $puerto_Proxmox_visible_3 -j DNAT --to-destination $proxmox3:$puerto_Proxmox_original
iptables -t nat -A PREROUTING -i $NicExt -p tcp --dport $puerto_Proxmox_visible_4 -j DNAT --to-destination $proxmox4:$puerto_Proxmox_original

iptables -t nat -A PREROUTING -i $NicExt -p tcp --dport 4000 -j DNAT --to-destination $proxmox1:22

#iptables -t nat -A PREROUTING -i $NicExt -p tcp --dport $puerto_ubundesk_visible -j DNAT --to-destination $ubuntu_desktop:$puerto_ubundesk_original

iptables -t nat -A PREROUTING -i $NicExt -p udp --dport $puerto_vpn_visible -j DNAT --to-destination $vpn_admin_server:$puerto_vpn_original



# Permetre el forwarding dels ports mapejats

iptables -A FORWARD -i $NicExt -p tcp --dport $puerto_Proxmox_original -j ACCEPT
iptables -A FORWARD -o $NicExt -p tcp --sport $puerto_Proxmox_original -j ACCEPT

iptables -A FORWARD -i $NicExt -p udp --dport $puerto_vpn_original -j ACCEPT
iptables -A FORWARD -o $NicExt -p udp --sport $puerto_vpn_original -j ACCEPT

iptables -A FORWARD -i $NicExt -p tcp --dport $puerto_nas_original -j ACCEPT
iptables -A FORWARD -o $NicExt -p tcp --sport $puerto_nas_original -j ACCEPT

