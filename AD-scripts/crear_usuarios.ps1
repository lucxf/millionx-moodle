# Script para crear estructura de Active Directory según CSV
# Ubicación: C:\MillionX\CreateADStructure.ps1

# Importar el módulo de Active Directory si no está cargado
if (-not (Get-Module -Name ActiveDirectory)) {
    try {
        Import-Module ActiveDirectory -ErrorAction Stop
    } catch {
        Write-Error "No se pudo cargar el módulo ActiveDirectory. Asegúrate de que está instalado y que ejecutas como administrador."
        exit 1
    }
}

# Configuración
$csvPath = "C:\MillionX\usuarios.csv"
$defaultPassword = "202425aA."

# Comprueba si existe el archivo CSV
if (-not (Test-Path $csvPath)) {
    Write-Error "No se encuentra el archivo CSV en la ruta especificada: $csvPath"
    exit 1
}

# Importar datos del CSV
try {
    $usuarios = Import-Csv -Path $csvPath -Delimiter ','
    Write-Host "CSV importado correctamente con $($usuarios.Count) usuarios." -ForegroundColor Green
} catch {
    Write-Error "Error al importar el CSV: $_"
    exit 1
}

# Funciones
function Create-OUIfNotExists {
    param ([string]$ouPath)
    try {
        $ouExists = Get-ADOrganizationalUnit -Identity $ouPath -ErrorAction SilentlyContinue
        if (-not $ouExists) {
            $ouName = ($ouPath -split ',')[0] -replace 'OU=', ''
            $parentPath = $ouPath -replace "^OU=$ouName,", ''
            Write-Host "Creando OU: ${ouName} en ${parentPath}" -ForegroundColor Yellow
            New-ADOrganizationalUnit -Name $ouName -Path $parentPath -ProtectedFromAccidentalDeletion $false
        } else {
            Set-ADOrganizationalUnit -Identity $ouPath -ProtectedFromAccidentalDeletion $false
        }
    } catch {
        Write-Error "Error al crear o actualizar la OU ${ouPath} : $_"
    }
}

function Test-OUExists {
    param ([string]$ouPath)
    try {
        return (Get-ADOrganizationalUnit -Identity $ouPath -ErrorAction SilentlyContinue) -ne $null
    } catch {
        return $false
    }
}

function Create-GroupIfNotExists {
    param (
        [string]$groupName,
        [string]$ouPath
    )
    try {
        $groupExists = Get-ADGroup -Filter "Name -eq '$groupName'" -ErrorAction SilentlyContinue
        if (-not $groupExists) {
            Write-Host "Creando grupo: ${groupName} en ${ouPath}" -ForegroundColor Yellow
            New-ADGroup -Name $groupName -GroupScope Global -GroupCategory Security -Path $ouPath
            Write-Host "Grupo ${groupName} creado correctamente." -ForegroundColor Green
        } else {
            Write-Host "Grupo ${groupName} ya existe." -ForegroundColor Cyan
        }
    } catch {
        Write-Error "Error al crear el grupo ${groupName} : $_"
    }
}

function Get-DomainComponents {
    try {
        return (Get-ADDomain).DistinguishedName
    } catch {
        Write-Error "Error al obtener información del dominio: $_"
        return "DC=millionx,DC=local"
    }
}

# Obtener componente de dominio
$domainComponents = Get-DomainComponents

# Crear todas las OUs necesarias
$ouPaths = @()
foreach ($ou in ($usuarios | ForEach-Object { $_.OU } | Sort-Object -Unique)) {
    $ouLevels = ($ou -split ',(?=OU=)').Count
    $ouPaths += [PSCustomObject]@{
        Path = $ou
        Levels = $ouLevels
    }
}
$ouPaths = $ouPaths | Sort-Object -Property Levels

foreach ($ouItem in $ouPaths) {
    $ouPath = $ouItem.Path
    $ouComponents = $ouPath -split ',(?=OU=|DC=)'
    $currentPath = ($ouComponents | Where-Object { $_ -like "DC=*" }) -join ','
    $ouComponents = @($ouComponents | Where-Object { $_ -like "OU=*" })

    for ($i = $ouComponents.Count - 1; $i -ge 0; $i--) {
        $component = $ouComponents[$i]
        $fullPath = "$component,$currentPath"

        if (-not (Test-OUExists -ouPath $fullPath)) {
            $ouName = $component -replace 'OU=', ''
            $parentPath = $currentPath
            Write-Host "Creando OU jerárquica: ${ouName} en ${parentPath}" -ForegroundColor Yellow
            New-ADOrganizationalUnit -Name $ouName -Path $parentPath -ProtectedFromAccidentalDeletion $false
        }

        $currentPath = $fullPath
    }
}

# Crear grupos en OUs específicas
$allGroups = @()
$usuarios | ForEach-Object {
    if ($_.Grupos) {
        $groups = $_.Grupos -split ','
        $allGroups += $groups
    }
}
$uniqueGroups = $allGroups | Where-Object { $_ -ne "" } | Sort-Object -Unique

Write-Host "Creando grupos de seguridad en sus respectivas OUs..." -ForegroundColor Yellow

foreach ($group in $uniqueGroups) {
    if ($group -ne "") {
        switch -Wildcard ($group) {
            "gAlumnos*" {
                $targetOU = "OU=Alumnos,OU=Escuela,$domainComponents"
                break
            }
            "gProfesores*" {
                $targetOU = "OU=Profesores,OU=Escuela,$domainComponents"
                break
            }
            "gEscuela" {
                $targetOU = "OU=Escuela,$domainComponents"
                break
            }
            default {
                $targetOU = "OU=Grupos,$domainComponents"
            }
        }

        if (-not (Test-OUExists -ouPath $targetOU)) {
            $ouName = ($targetOU -split '=')[1] -split ',' | Select-Object -First 1
            New-ADOrganizationalUnit -Name $ouName -Path $domainComponents -ProtectedFromAccidentalDeletion $false
        }

        Create-GroupIfNotExists -groupName $group -ouPath $targetOU
    }
}

# Crear usuarios y añadir a grupos
foreach ($usuario in $usuarios) {
    try {
        if (-not (Test-OUExists -ouPath $usuario.OU)) {
            Write-Warning "La OU ${usuario.OU} no existe para el usuario ${usuario.SamAccountName}. Creándola..."
            $ouComponents = $usuario.OU -split ',(?=OU=|DC=)'
            $currentPath = ($ouComponents | Where-Object { $_ -like "DC=*" }) -join ','
            $ouComponents = @($ouComponents | Where-Object { $_ -like "OU=*" })

            for ($i = $ouComponents.Count - 1; $i -ge 0; $i--) {
                $component = $ouComponents[$i]
                $fullPath = "$component,$currentPath"
                if (-not (Test-OUExists -ouPath $fullPath)) {
                    $ouName = $component -replace 'OU=', ''
                    New-ADOrganizationalUnit -Name $ouName -Path $currentPath -ProtectedFromAccidentalDeletion $false
                }
                $currentPath = $fullPath
            }
        }

        $userExists = Get-ADUser -Filter "SamAccountName -eq '$($usuario.SamAccountName)'" -ErrorAction SilentlyContinue

        if (-not $userExists) {
            $securePassword = ConvertTo-SecureString -String $defaultPassword -AsPlainText -Force
            $rutaLocal = "\\WIN-6EN0NS26U5A\$($usuario.SamAccountName)"
            New-ADUser -SamAccountName $usuario.SamAccountName `
                -UserPrincipalName $usuario.UserPrincipalName `
                -Name $usuario.Display_Name `
                -DisplayName $usuario.Display_Name `
                -GivenName $usuario.First_Name `
                -Surname $usuario.Last_Name `
                -Path $usuario.OU `
                -AccountPassword $securePassword `
                -ChangePasswordAtLogon $true `
                -Enabled $true `
                -HomeDirectory $rutaLocal `
                -HomeDrive "Z:" `
                -ErrorAction Stop

            Write-Host "Usuario ${usuario.SamAccountName} creado correctamente." -ForegroundColor Green
        } else {
            Write-Host "El usuario ${usuario.SamAccountName} ya existe. Actualizando información." -ForegroundColor Yellow
            Set-ADUser -Identity $usuario.SamAccountName `
                -UserPrincipalName $usuario.UserPrincipalName `
                -DisplayName $usuario.Display_Name `
                -GivenName $usuario.First_Name `
                -Surname $usuario.Last_Name `
                -HomeDirectory "\\WIN-6EN0NS26U5A\Usuarios\$($usuario.SamAccountName)" `
                -HomeDrive "Z:" `
                -ErrorAction Stop
        }

        if ($usuario.Grupos) {
            $grupos = $usuario.Grupos -split ','
            foreach ($grupo in $grupos) {
                if ($grupo -ne "") {
                    $groupExists = Get-ADGroup -Filter "Name -eq '$grupo'" -ErrorAction SilentlyContinue
                    if (-not $groupExists) {
                        switch -Wildcard ($grupo) {
                            "gAlumnos*" { $groupOU = "OU=Alumnos,OU=Escuela,$domainComponents" }
                            "gProfesores*" { $groupOU = "OU=Profesores,OU=Escuela,$domainComponents" }
                            "gEscuela"    { $groupOU = "OU=Escuela,$domainComponents" }
                            default       { $groupOU = "OU=Grupos,$domainComponents" }
                        }
                        Create-GroupIfNotExists -groupName $grupo -ouPath $groupOU
                    }

                    $isMember = Get-ADGroupMember -Identity $grupo | Where-Object { $_.SamAccountName -eq $usuario.SamAccountName }
                    if (-not $isMember) {
                        Add-ADGroupMember -Identity $grupo -Members $usuario.SamAccountName -ErrorAction SilentlyContinue
                        Write-Host "Usuario ${usuario.SamAccountName} añadido al grupo ${grupo}" -ForegroundColor Cyan
                    }
                }
            }
        }
    } catch {
        Write-Error "Error al procesar el usuario ${usuario.SamAccountName}: $_"
    }
}

Write-Host "`nProceso completado. Se han creado o actualizado todas las OUs, grupos y usuarios según el CSV." -ForegroundColor Green
