#/bin/bash

vlan40="ens33"
NicExt="ens37"

RedAdministracio="192.168.40.0/24"

puerto_Proxmox_visible="4731"
puerto_Proxmox_original="8006"

proxmox1="192.168.40.11"
proxmox2="192.168.40.12"
proxmox3="192.168.40.13"
proxmox4="192.168.40.14"
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
iptables -t nat -A POSTROUTING -d $RedAdministracio -o $vlan40   -j MASQUERADE
# quan Ip desti = red Interconnexio --> envia per la tarjeta de la red interconnexio NicExt
iptables -t nat -A POSTROUTING                      -o $NicExt -j MASQUERADE

red10="172.18.0.0/16"
vlan10="ens33"

red20="172.19.0.0/16"
vlan20="ens37"

red30="10.0.0.0/20"
vlan30="ens38"

srvwordpress="172.18.10.4"
srvodoo="172.18.10.3"

# PREROUTING

iptables -t nat -A PREROUTING -i $NicExt -p tcp --dport $puerto_Proxmox_visible -j DNAT --to-destination $proxmox1:$puerto_Proxmox_original
iptables -t nat -A PREROUTING -i $NicExt -p tcp --dport $puerto_Proxmox_visible -j DNAT --to-destination $proxmox2:$puerto_Proxmox_original
iptables -t nat -A PREROUTING -i $NicExt -p tcp --dport $puerto_Proxmox_visible -j DNAT --to-destination $proxmox3:$puerto_Proxmox_original
iptables -t nat -A PREROUTING -i $NicExt -p tcp --dport $puerto_Proxmox_visible -j DNAT --to-destination $proxmox4:$puerto_Proxmox_original