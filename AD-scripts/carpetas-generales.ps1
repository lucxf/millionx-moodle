# Variables de grupos (ajusta los nombres si son distintos)
$grupoAdmins = "Administrators"    # O "Administradores" si el sistema está en español
$grupoEscuela = "gEscuela"
$grupoAlumnos = "gAlumnos"
$grupoProfesores = "gProfesores"

# Ruta principal
$basePath = "Z:\Escuela"

try {
    # Crear carpeta base si no existe y deshabilitar herencia
    if (-not (Test-Path -Path $basePath)) {
        New-Item -ItemType Directory -Path $basePath -Force | Out-Null
        Write-Host "Carpeta base creada: $basePath" -ForegroundColor Green
    }

    # Deshabilitar herencia en la carpeta base
    $aclBase = Get-Acl -Path $basePath
    $aclBase.SetAccessRuleProtection($true, $false) # Deshabilitar herencia sin copiar permisos heredados
    $aclBase.Access | ForEach-Object {
        $aclBase.RemoveAccessRuleSpecific($_)
    }

    # Agregar permisos para Administradores en la carpeta base
    $reglaAdminsBase = New-Object System.Security.AccessControl.FileSystemAccessRule(
        $grupoAdmins,
        "FullControl",
        "ContainerInherit,ObjectInherit",
        "None",
        "Allow"
    )
    $aclBase.AddAccessRule($reglaAdminsBase)
    Set-Acl -Path $basePath -AclObject $aclBase -ErrorAction Stop
    Write-Host "Herencia deshabilitada y permisos iniciales aplicados en la carpeta base: $basePath" -ForegroundColor Green

    # Crear subcarpetas
    $pathAlumnos = "$basePath\Alumnos"
    $pathProfesores = "$basePath\Profesores"

    if (-not (Test-Path -Path $pathAlumnos)) {
        New-Item -ItemType Directory -Path $pathAlumnos -Force | Out-Null
        Write-Host "Carpeta creada: $pathAlumnos" -ForegroundColor Green
    }

    if (-not (Test-Path -Path $pathProfesores)) {
        New-Item -ItemType Directory -Path $pathProfesores -Force | Out-Null
        Write-Host "Carpeta creada: $pathProfesores" -ForegroundColor Green
    }

    # Función para asignar permisos
    function Set-Permissions($path, $grupoLectura, $grupoModifica) {
        try {
            $acl = Get-Acl -Path $path

            # Quitar herencia
            $acl.SetAccessRuleProtection($true, $false)
            $acl.Access | ForEach-Object {
                $acl.RemoveAccessRuleSpecific($_)
            }

            # Permisos para administradores
            $reglaAdmins = New-Object System.Security.AccessControl.FileSystemAccessRule(
                $grupoAdmins,
                "FullControl",
                "ContainerInherit,ObjectInherit",
                "None",
                "Allow"
            )
            $acl.AddAccessRule($reglaAdmins)

            # Permisos de lectura
            if ($grupoLectura) {
                $reglaLectura = New-Object System.Security.AccessControl.FileSystemAccessRule(
                    $grupoLectura,
                    "ReadAndExecute",
                    "ContainerInherit,ObjectInherit",
                    "None",
                    "Allow"
                )
                $acl.AddAccessRule($reglaLectura)
            }

            # Permisos de modificación
            if ($grupoModifica) {
                $reglaModifica = New-Object System.Security.AccessControl.FileSystemAccessRule(
                    $grupoModifica,
                    "Modify",
                    "ContainerInherit,ObjectInherit",
                    "None",
                    "Allow"
                )
                $acl.AddAccessRule($reglaModifica)
            }

            # Aplicar los permisos
            Set-Acl -Path $path -AclObject $acl -ErrorAction Stop
            Write-Host "Permisos aplicados en $path" -ForegroundColor Green

            # Verificación con IdentityReference.Value
            $aclVerificada = Get-Acl -Path $path
            $permisosAdmins = $aclVerificada.Access | Where-Object { $_.IdentityReference.Value -like "*\$grupoAdmins" }
            if (-not $permisosAdmins) {
                Write-Warning "Los permisos para $grupoAdmins no se aplicaron correctamente en $path"
            }
            if ($grupoLectura) {
                $permisosLectura = $aclVerificada.Access | Where-Object { $_.IdentityReference.Value -like "*\$grupoLectura" }
                if (-not $permisosLectura) {
                    Write-Warning "Los permisos de lectura para $grupoLectura no se aplicaron correctamente en $path"
                }
            }
            if ($grupoModifica) {
                $permisosModifica = $aclVerificada.Access | Where-Object { $_.IdentityReference.Value -like "*\$grupoModifica" }
                if (-not $permisosModifica) {
                    Write-Warning "Los permisos de modificación para $grupoModifica no se aplicaron correctamente en $path"
                }
            }
        }
        catch {
            Write-Warning "Error al aplicar permisos en $path. Detalle: $($_.Exception.Message)"
        }
    }

    # Aplicar permisos a las carpetas
    Set-Permissions -path $basePath -grupoLectura $grupoEscuela -grupoModifica $null
    Set-Permissions -path $pathAlumnos -grupoLectura $null -grupoModifica $grupoAlumnos
    Set-Permissions -path $pathProfesores -grupoLectura $null -grupoModifica $grupoProfesores

    # Compartir la carpeta Escuela
    try {
        if (-not (Get-SmbShare -Name "Escuela" -ErrorAction SilentlyContinue)) {
            New-SmbShare -Name "Escuela" -Path $basePath -FullAccess $grupoAdmins -ReadAccess $grupoEscuela -ErrorAction Stop
            Write-Host "Recurso compartido 'Escuela' creado con éxito." -ForegroundColor Green
        }
        else {
            Write-Host "El recurso compartido 'Escuela' ya existe, omitiendo creación." -ForegroundColor Cyan
        }
    }
    catch {
        Write-Warning "Error al crear el recurso compartido 'Escuela'. Detalle: $($_.Exception.Message)"
    }

    Write-Host "`nProceso completado. Se han creado las carpetas, aplicado permisos y compartido la carpeta Escuela." -ForegroundColor Green
}
catch {
    Write-Error "Error general en el script: $($_.Exception.Message)"
}
finally {
    # Limpiar sesiones SMB y credenciales en caché
    Write-Host "Limpiando sesiones SMB y credenciales en caché..." -ForegroundColor Yellow
    net use * /delete /y | Out-Null
}
