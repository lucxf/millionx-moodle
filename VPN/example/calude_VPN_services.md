Para permitir que solo la gente con VPN pueda acceder por SSH a una máquina de administración, necesitaré modificar algunas reglas en tu firewall. Aquí están los cambios necesarios:

```bash
#/bin/bash

# Targetas
vlan40="ens33"
NicExt="ens37"

targetes=($NicExt $vlan40)

#Redes
RedAdministracio="192.168.40.0/24"

# Puertos
p_SSH="22"
p_http="80"
p_https="443"
p_DNS="53"
p_VPN_web="51820"
p_VPN_udp_traffic="51821"

# Maquines
vpn_server="192.168.40.2"
RedVpn="10.8.0.0/24"

#=================== PROXMOX VARIABLES ====================#

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

#======================= ICMP =======================#

# ROUTER
for targeta in ${targetes[@]};
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

# # ROUTER
iptables -A OUTPUT -o $NicExt -p udp --dport $p_DNS -j ACCEPT
iptables -A INPUT  -i $NicExt -p udp --sport $p_DNS -j ACCEPT

# # VLAN40
iptables -A FORWARD -i $vlan40 -o $NicExt -p udp --dport $p_DNS -j ACCEPT
iptables -A FORWARD -i $NicExt -o $vlan40 -p udp --sport $p_DNS -j ACCEPT

#================ UPDATE/UPGRADE ====================#

# ROUTER (mirar como hacer que solo se a los repos, no a otro lado)
iptables -A OUTPUT -o $NicExt -p tcp -m multiport --dports $p_http,$p_https -j ACCEPT
iptables -A INPUT  -i $NicExt -p tcp -m multiport --sports $p_http,$p_https -j ACCEPT

# VLAN40 (Permito el forwarding de tramas desde la VLAN40)
iptables -A FORWARD -i $vlan40 -o $NicExt -p tcp -m multiport --dports $p_http,$p_https -j ACCEPT
iptables -A FORWARD -i $NicExt -o $vlan40 -p tcp -m multiport --sports $p_http,$p_https -j ACCEPT

#======================= VPN =======================#

# VPN traffic
iptables -t nat -A PREROUTING  -i $NicExt -p udp --dport $p_VPN_udp_traffic -j DNAT --to-destination $vpn_server:$p_VPN_udp_traffic

iptables -A FORWARD -i $NicExt -o $vlan40 -d $RedAdministracio -p udp --dport $p_VPN_udp_traffic -j ACCEPT
iptables -A FORWARD -i $vlan40 -o $NicExt -s $RedAdministracio -p udp --sport $p_VPN_udp_traffic -j ACCEPT

#======================= SSH ADMINISTRACION VPN =======================#

# Permitir SSH solo desde la red VPN hacia las máquinas de administración
iptables -A FORWARD -i $NicExt -o $vlan40 -d $RedAdministracio -s $RedVpn -p tcp --dport $p_SSH -j ACCEPT
iptables -A FORWARD -i $vlan40 -o $NicExt -s $RedAdministracio -d $RedVpn -p tcp --sport $p_SSH -j ACCEPT

# IMPORTANTE: Eliminar reglas de acceso SSH directo desde el exterior (las comento)
# iptables -A INPUT  -i $NicExt -p tcp --dport $p_SSH -j ACCEPT
# iptables -A OUTPUT -o $NicExt -p tcp --sport $p_SSH -j ACCEPT

# Mantener SSH para la administración local desde VLAN40
iptables -A INPUT  -i $vlan40 -p tcp --sport $p_SSH -j ACCEPT
iptables -A OUTPUT -o $vlan40 -p tcp --dport $p_SSH -j ACCEPT

# Bloquear explícitamente cualquier intento de SSH desde el exterior que no venga de la VPN
iptables -A FORWARD -i $NicExt -o $vlan40 -p tcp --dport $p_SSH -m state --state NEW -j DROP

#=============== TRAFICO LOOPBACK ===================#

# Permitir tráfico local (loopback)
iptables -A INPUT -i lo -j ACCEPT
iptables -A OUTPUT -o lo -j ACCEPT

#======================= PROXMOX =======================#

# Prerouting de proxmox
iptables -t nat -A PREROUTING -i $NicExt -p tcp --dport $p_Proxmox_visible_1 -j DNAT --to-destination $proxmox1:$p_Proxmox_original
iptables -t nat -A PREROUTING -i $NicExt -p tcp --dport $p_Proxmox_visible_2 -j DNAT --to-destination $proxmox2:$p_Proxmox_original
iptables -t nat -A PREROUTING -i $NicExt -p tcp --dport $p_Proxmox_visible_3 -j DNAT --to-destination $proxmox3:$p_Proxmox_original
iptables -t nat -A PREROUTING -i $NicExt -p tcp --dport $p_Proxmox_visible_4 -j DNAT --to-destination $proxmox4:$p_Proxmox_original

iptables -A FORWARD -i $vlan40 -o $NicExt -p tcp --sport $p_Proxmox_original -j ACCEPT

iptables -A FORWARD -i $NicExt -o $vlan40 -p tcp --dport $p_Proxmox_visible_1 -j ACCEPT
iptables -A FORWARD -i $NicExt -o $vlan40 -p tcp --dport $p_Proxmox_visible_2 -j ACCEPT
iptables -A FORWARD -i $NicExt -o $vlan40 -p tcp --dport $p_Proxmox_visible_3 -j ACCEPT
iptables -A FORWARD -i $NicExt -o $vlan40 -p tcp --dport $p_Proxmox_visible_4 -j ACCEPT

```

## Explicación de los cambios realizados:

1. **Eliminé las reglas de acceso SSH directo desde el exterior:**
   ```bash
   # iptables -A INPUT  -i $NicExt -p tcp --dport $p_SSH -j ACCEPT
   # iptables -A OUTPUT -o $NicExt -p tcp --sport $p_SSH -j ACCEPT
   ```
   Estas reglas permitían acceso SSH directo al router desde cualquier dirección externa, lo cual ahora bloqueamos.

2. **Agregué una regla explícita para bloquear intentos de SSH desde el exterior:**
   ```bash
   iptables -A FORWARD -i $NicExt -o $vlan40 -p tcp --dport $p_SSH -m state --state NEW -j DROP
   ```
   Esta regla bloquea específicamente cualquier conexión SSH nueva desde el exterior hacia la red de administración.

3. **Mantuve las reglas existentes de VPN que ya estaban bien configuradas:**
   ```bash
   iptables -A FORWARD -i $NicExt -o $vlan40 -d $RedAdministracio -s $RedVpn -p tcp --dport $p_SSH -j ACCEPT
   iptables -A FORWARD -i $vlan40 -o $NicExt -s $RedAdministracio -d $RedVpn -p tcp --sport $p_SSH -j ACCEPT
   ```
   Estas reglas permiten conexiones SSH solo desde la red VPN (10.8.0.0/24) hacia la red de administración.

4. **Mantuve el acceso SSH local desde la VLAN40:**
   ```bash
   iptables -A INPUT  -i $vlan40 -p tcp --sport $p_SSH -j ACCEPT
   iptables -A OUTPUT -o $vlan40 -p tcp --dport $p_SSH -j ACCEPT
   ```
   Esto permite que el tráfico SSH siga funcionando dentro de la red de administración.

### Explicación del funcionamiento:

Con estos cambios, solo los usuarios conectados a través de la VPN podrán iniciar conexiones SSH a las máquinas de la red de administración. El flujo funcionará así:

1. El usuario primero se conecta a la VPN, obteniendo una IP dentro del rango 10.8.0.0/24
2. Una vez conectado a la VPN, sus intentos de conexión SSH a máquinas en 192.168.40.0/24 serán permitidos
3. Cualquier intento de conexión SSH desde fuera que no provenga de una IP de la VPN será bloqueado

Estos cambios mantienen la seguridad de tu red mientras permiten un acceso controlado a través de la VPN. La mayor ventaja de este enfoque es que solo las personas que tienen credenciales de la VPN podrán intentar acceder por SSH, agregando una capa adicional de seguridad.