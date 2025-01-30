NicExt=
NicDMZ=
NicINTER=

RedInterconexio=
RedDMZ=

reds=

contador=0
# Borramos reglas por defecto
iptables -F
# Borro todas las reglas NAT
iptables -t nat -F
# Borro reglas de filtrado
iptables -X
iptables -Z

iptables -P INPUT DROP
iptables -P OUTPUT DROP
iptables -P FORWARD DROP

