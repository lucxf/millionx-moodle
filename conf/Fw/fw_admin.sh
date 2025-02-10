#/bin/bash

vlan40="ens33"
NicExt="ens37"

RedAdministracio="192.168.40.0/24"

p_visible_prox1="4731"
p_visible_prox2="4732"
p_visible_prox3="4733"
p_visible_prox4="4734"

p_interno_proxmox="8006"

proxmox1="192.168.40.10"
proxmox2="192.168.40.11"
proxmox3="192.168.40.12"
proxmox4="192.168.40.13"

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

# Se ha de borrar devido a que es una solucion temporal
# PREROUTING
iptables -t nat -A PREROUTING -i $NicExt -p tcp --dport $p_visible_prox1 -j DNAT --to-destination $proxmox1:$p_interno_proxmox
iptables -t nat -A PREROUTING -i $NicExt -p tcp --dport $p_visible_prox2 -j DNAT --to-destination $proxmox2:$p_interno_proxmox
iptables -t nat -A PREROUTING -i $NicExt -p tcp --dport $p_visible_prox3 -j DNAT --to-destination $proxmox3:$p_interno_proxmox
iptables -t nat -A PREROUTING -i $NicExt -p tcp --dport $p_visible_prox4 -j DNAT --to-destination $proxmox4:$p_interno_proxmox

# Permetre el forwarding dels ports mapejats

iptables -A FORWARD -i $NicExt -p tcp --dport $puerto_Proxmox_original -j ACCEPT
iptables -A FORWARD -o $NicExt -p tcp --sport $puerto_Proxmox_original -j ACCEPT
