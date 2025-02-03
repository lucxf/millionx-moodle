$NombreSwitch = "switch0"
# la vlan 1 por defecto recive el nombre de el switch
$NombreNuevo = "vlan1"
# Nombre de la interfaz de salida
$NombreAdaptador = "ethswitch"

# Creamos el switch virtual
New-VMSwitch -name $NombreSwitch -NetAdapterName $NombreAdaptador -AllowManagementOS $true

# Añadimos una targeta a este switch
# Red LAN
Add-VMNetworkAdapter -ManagementOS -Name "vlan3" -SwitchName $NombreSwitch -Passthru | Set-VMNetworkAdapterVlan -Access -VlanId 3
# Red DMZ
Add-VMNetworkAdapter -ManagementOS -Name "vlan20" -SwitchName $NombreSwitch -Passthru | Set-VMNetworkAdapterVlan -Access -VlanId 20
# Red de administración
Add-VMNetworkAdapter -ManagementOS -Name "vlan40" -SwitchName $NombreSwitch -Passthru | Set-VMNetworkAdapterVlan -Access -VlanId 40
# Red Inrterconexion 2
Add-VMNetworkAdapter -ManagementOS -Name "vlan60" -SwitchName $NombreSwitch -Passthru | Set-VMNetworkAdapterVlan -Access -VlanId 60

Get-VMNetworkAdapter -ManagementOS -Name $NombreSwitch | Rename-VMNetworkAdapter -NewName $NombreNuevo

#Switch que sale al exterior
$NombreSwitchExterior = "switch1"
# Nombre de la interfaz de salida
$NombreAdaptadorSalida = "ethsalida"

New-VMSwitch -name $NombreSwitchExterior -NetAdapterName $NombreAdaptadorSalida -AllowManagementOS $true

# Añadimos una targeta a este switch
# Red de salida
Add-VMNetworkAdapter -ManagementOS -Name "vlan2" -SwitchName $NombreSwitch -Passthru | Set-VMNetworkAdapterVlan -Access -VlanId 2
# Red de interconexión
Add-VMNetworkAdapter -ManagementOS -Name "vlan10" -SwitchName $NombreSwitch -Passthru | Set-VMNetworkAdapterVlan -Access -VlanId 10

Get-VMNetworkAdapter -ManagementOS -Name $NombreSwitchExterior | Rename-VMNetworkAdapter -NewName $NombreNuevo


#Get-VMSwitch -Name *
#Get-VMNetworkAdapter -all
#Get-VMNetworkAdapterVlan -ManagementOS
