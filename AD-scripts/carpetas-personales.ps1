# Ruta del CSV
$csvPath = "C:\MillionX\usuarios.csv"
$rutaBase = "Z:\Usuarios"
$quotaPredeterminadaGB = 7 # Cuota predeterminada en GB

try {
    # Comprobar si el módulo FSRM está disponible
    if (-not (Get-Module -Name FileServerResourceManager -ListAvailable)) {
        try {
            Import-Module FileServerResourceManager -ErrorAction Stop
            Write-Host "Módulo FileServerResourceManager importado correctamente." -ForegroundColor Green
        } catch {
            Write-Warning "No se pudo cargar el módulo FileServerResourceManager. Las cuotas no se aplicarán."
            Write-Warning "Para instalar este módulo, ejecuta: Install-WindowsFeature -Name FS-Resource-Manager -IncludeManagementTools"
        }
    } else {
        Import-Module FileServerResourceManager
    }

    # Verificar si el archivo CSV existe
    if (-not (Test-Path -Path $csvPath)) {
        throw "El archivo CSV no existe en la ruta: $csvPath"
    }

    # Crear carpeta base si no existe y deshabilitar herencia
    if (-not (Test-Path -Path $rutaBase)) {
        New-Item -Path $rutaBase -ItemType Directory -Force | Out-Null
        Write-Host "Carpeta base creada: $rutaBase" -ForegroundColor Green
    }

    # Deshabilitar herencia en la carpeta base (Z:\Usuarios)
    $aclBase = Get-Acl -Path $rutaBase
    $aclBase.SetAccessRuleProtection($true, $false) # Deshabilitar herencia, no copiar permisos heredados
    $aclBase.Access | ForEach-Object {
        $aclBase.RemoveAccessRuleSpecific($_)
    }
    # Agregar permisos para Administradores en la carpeta base
    $adminSid = New-Object System.Security.Principal.SecurityIdentifier("S-1-5-32-544")
    $permAdminBase = New-Object System.Security.AccessControl.FileSystemAccessRule(
        $adminSid,
        "FullControl",
        "ContainerInherit,ObjectInherit",
        "None",
        "Allow"
    )
    $aclBase.AddAccessRule($permAdminBase)
    Set-Acl -Path $rutaBase -AclObject $aclBase -ErrorAction Stop
    Write-Host "Herencia deshabilitada y permisos aplicados en la carpeta base: $rutaBase" -ForegroundColor Green

    # Importar los usuarios
    $usuarios = Import-Csv -Path $csvPath -Encoding UTF8
    foreach ($usuario in $usuarios) {
        $samAccount = $usuario.SamAccountName

        # Validar que SamAccountName no esté vacío
        if ([string]::IsNullOrEmpty($samAccount)) {
            Write-Warning "SamAccountName está vacío o no definido en el CSV."
            continue
        }

        # Validar si el usuario existe y obtener su SID
        try {
            $userSid = (New-Object System.Security.Principal.NTAccount($samAccount)).Translate([System.Security.Principal.SecurityIdentifier])
            Write-Host "Usuario $samAccount válido. SID: $($userSid.Value)" -ForegroundColor Cyan
        }
        catch {
            Write-Warning "El usuario $samAccount no se pudo resolver. Detalle: $($_.Exception.Message)"
            continue
        }

        $rutaCarpeta = Join-Path -Path $rutaBase -ChildPath $samAccount

        # Crear carpeta si no existe
        if (-not (Test-Path -Path $rutaCarpeta)) {
            New-Item -Path $rutaCarpeta -ItemType Directory -Force | Out-Null
            Write-Host "Carpeta creada: $rutaCarpeta" -ForegroundColor Green
        }

        # Obtener la ACL actual y deshabilitar la herencia
        $acl = Get-Acl -Path $rutaCarpeta
        $acl.SetAccessRuleProtection($true, $false) # Deshabilitar herencia, no copiar permisos heredados

        # Eliminar todos los permisos existentes
        $acl.Access | ForEach-Object {
            $acl.RemoveAccessRuleSpecific($_)
        }

        # Agregar permisos exclusivos para el usuario
        $permUsuario = New-Object System.Security.AccessControl.FileSystemAccessRule(
            $samAccount,
            "FullControl",
            "ContainerInherit,ObjectInherit",
            "None",
            "Allow"
        )
        $acl.AddAccessRule($permUsuario)

        # Agregar permisos para el grupo Administradores usando SID
        $adminSid = New-Object System.Security.Principal.SecurityIdentifier("S-1-5-32-544")
        $permAdmin = New-Object System.Security.AccessControl.FileSystemAccessRule(
            $adminSid,
            "FullControl",
            "ContainerInherit,ObjectInherit",
            "None",
            "Allow"
        )
        $acl.AddAccessRule($permAdmin)

        # Aplicar la nueva ACL
        try {
            Set-Acl -Path $rutaCarpeta -AclObject $acl -ErrorAction Stop
            Write-Host "Permisos aplicados: $samAccount y Administradores tienen control total en $rutaCarpeta" -ForegroundColor Green

            # Breve retraso para asegurar que los permisos se propaguen
            Start-Sleep -Milliseconds 500

            # Verificar que los permisos se aplicaron correctamente usando SIDs
            $aclVerificada = Get-Acl -Path $rutaCarpeta
            Write-Host "Permisos actuales en ${rutaCarpeta}:" -ForegroundColor Cyan
            $aclVerificada.Access | ForEach-Object {
                Write-Host "  Identidad: $($_.IdentityReference), Derechos: $($_.FileSystemRights)" -ForegroundColor Cyan
            }

            $permisosUsuario = $aclVerificada.Access | Where-Object { $_.IdentityReference.Translate([System.Security.Principal.SecurityIdentifier]).Value -eq $userSid.Value }
            $permisosAdmin = $aclVerificada.Access | Where-Object { $_.IdentityReference.Translate([System.Security.Principal.SecurityIdentifier]).Value -eq "S-1-5-32-544" }
            if (-not $permisosUsuario) {
                Write-Warning "Los permisos para $samAccount (SID: $($userSid.Value)) no se encontraron en $rutaCarpeta"
            }
            if (-not $permisosAdmin) {
                Write-Warning "Los permisos para Administradores (SID: S-1-5-32-544) no se encontraron en $rutaCarpeta"
            }
            if ($permisosUsuario -and $permisosAdmin) {
                Write-Host "Verificación exitosa: Permisos aplicados correctamente para $samAccount y Administradores en $rutaCarpeta" -ForegroundColor Green
            }
        }
        catch {
            Write-Warning "Error al aplicar permisos para $samAccount. Detalle: $($_.Exception.Message)"
            continue
        }

        # Aplicar cuota a la carpeta
        if (Get-Module -Name FileServerResourceManager) {
            try {
                # Determinar el tamaño de la cuota (usar predeterminado o personalizado del CSV)
                $cuotaGB = $quotaPredeterminadaGB
                if ($usuario.PSObject.Properties.Match('QuotaGB').Count -gt 0 -and -not [string]::IsNullOrEmpty($usuario.QuotaGB)) {
                    $cuotaGB = [int]$usuario.QuotaGB
                }
                
                # Convertir GB a bytes
                $cuotaBytes = $cuotaGB * 1GB
                
                # Comprobar si ya existe una cuota para esta carpeta
                $cuotaExistente = Get-FsrmQuota -Path $rutaCarpeta -ErrorAction SilentlyContinue
                
                if ($cuotaExistente) {
                    # Actualizar la cuota existente
                    Set-FsrmQuota -Path $rutaCarpeta -Size $cuotaBytes
                    Write-Host "Cuota actualizada para ${rutaCarpeta}: $cuotaGB GB" -ForegroundColor Yellow
                } else {
                    # Definir las acciones por separado
                    $action85 = New-FsrmAction -Type Email -MailTo "admin@tudominio.local" -Subject "Advertencia: Cuota al 85% para $samAccount"
                    $action95Admin = New-FsrmAction -Type Email -MailTo "admin@tudominio.local" -Subject "Crítico: Cuota al 95% para $samAccount"
                    $action95User = New-FsrmAction -Type Email -MailTo "$samAccount@tudominio.local" -Subject "Tu carpeta personal está casi llena"

                    # Crear los umbrales con una sola acción por umbral
                    $threshold85 = New-FsrmQuotaThreshold -Percentage 85 -Action $action85
                    $threshold95 = New-FsrmQuotaThreshold -Percentage 95 -Action $action95Admin
                    
                    # Crear una nueva cuota con los umbrales
                    New-FsrmQuota -Path $rutaCarpeta -Size $cuotaBytes -Threshold @($threshold85, $threshold95)
                    Write-Host "Cuota creada para ${rutaCarpeta}: $cuotaGB GB" -ForegroundColor Green
                }
            } catch {
                Write-Warning "Error al establecer la cuota para $samAccount. Detalle: $($_.Exception.Message)"
            }
        }

        # Crear el recurso compartido
        try {
            if (-not (Get-SmbShare -Name $samAccount -ErrorAction SilentlyContinue)) {
                New-SmbShare -Name $samAccount -Path $rutaCarpeta -FullAccess $samAccount -ErrorAction Stop
                Write-Host "Recurso compartido creado: $samAccount" -ForegroundColor Green
            }
            else {
                Write-Host "El recurso compartido $samAccount ya existe, omitiendo creación." -ForegroundColor Cyan
            }
        }
        catch {
            Write-Warning "No se pudo crear el recurso compartido para $samAccount. Detalle: $($_.Exception.Message)"
        }
    }

    Write-Host "`nProceso completado. Se han creado las carpetas, aplicado permisos, establecido cuotas y compartido recursos." -ForegroundColor Green
}
catch {
    Write-Error "Error general en el script: $($_.Exception.Message)"
}
finally {
    # Limpiar sesiones SMB y credenciales en caché para evitar problemas de autenticación
    Write-Host "Limpiando sesiones SMB y credenciales en caché..." -ForegroundColor Yellow
    net use * /delete /y | Out-Null
}