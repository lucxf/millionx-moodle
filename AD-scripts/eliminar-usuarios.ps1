# Script para eliminar usuarios de Active Directory con interfaz gráfica
# Dominio: millionx.local

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# Verificar si el módulo ActiveDirectory está instalado
if (-not (Get-Module -ListAvailable -Name ActiveDirectory)) {
    $mensaje = "El módulo ActiveDirectory no está instalado. Este script requiere el módulo ActiveDirectory para funcionar."
    [System.Windows.Forms.MessageBox]::Show($mensaje, "Error", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error)
    exit
}

# Crear el formulario principal
$form = New-Object System.Windows.Forms.Form
$form.Text = "Eliminar Usuario - millionx.local"
$form.Size = New-Object System.Drawing.Size(450, 200)
$form.StartPosition = "CenterScreen"
$form.FormBorderStyle = [System.Windows.Forms.FormBorderStyle]::FixedDialog
$form.MaximizeBox = $false

# Etiqueta para instrucciones
$label = New-Object System.Windows.Forms.Label
$label.Location = New-Object System.Drawing.Point(10, 20)
$label.Size = New-Object System.Drawing.Size(430, 20)
$label.Text = "Introduce el User Logon Name del usuario que deseas eliminar:"
$form.Controls.Add($label)

# Campo de texto para el nombre de usuario
$textBox = New-Object System.Windows.Forms.TextBox
$textBox.Location = New-Object System.Drawing.Point(10, 50)
$textBox.Size = New-Object System.Drawing.Size(410, 20)
$form.Controls.Add($textBox)

# Botón para iniciar el proceso de eliminación
$button = New-Object System.Windows.Forms.Button
$button.Location = New-Object System.Drawing.Point(170, 90)
$button.Size = New-Object System.Drawing.Size(100, 30)
$button.Text = "Eliminar"
$button.Add_Click({
    $username = $textBox.Text.Trim()
    
    if ([string]::IsNullOrEmpty($username)) {
        [System.Windows.Forms.MessageBox]::Show("Por favor, introduce un nombre de usuario.", "Error", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Warning)
        return
    }
    
    try {
        # Verificar si el usuario existe en el dominio millionx.local
        $user = Get-ADUser -Filter "SamAccountName -eq '$username'" -Server "millionx.local" -ErrorAction Stop
        
        if ($user -eq $null) {
            [System.Windows.Forms.MessageBox]::Show("El usuario '$username' no existe en el dominio millionx.local.", "Error", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error)
            return
        }
        
        # Mostrar información adicional del usuario para confirmar
        $userInfo = "Nombre: $($user.Name)`nNombre completo: $($user.DisplayName)`nUPN: $($user.UserPrincipalName)"
        
        # Pedir confirmación
        $confirmResult = [System.Windows.Forms.MessageBox]::Show(
            "¿Estás seguro de que deseas eliminar el siguiente usuario del dominio millionx.local?`n`n$userInfo",
            "Confirmar eliminación",
            [System.Windows.Forms.MessageBoxButtons]::YesNo,
            [System.Windows.Forms.MessageBoxIcon]::Question)
            
        if ($confirmResult -eq [System.Windows.Forms.DialogResult]::Yes) {
            # Eliminar el usuario
            Remove-ADUser -Identity $username -Server "millionx.local" -Confirm:$false
            [System.Windows.Forms.MessageBox]::Show("El usuario '$username' ha sido eliminado correctamente del dominio millionx.local.", "Éxito", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information)
            $textBox.Text = ""
        }
    }
    catch {
        [System.Windows.Forms.MessageBox]::Show("Error al procesar la solicitud: $_", "Error", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error)
    }
})
$form.Controls.Add($button)

# Etiqueta para mostrar el dominio
$domainLabel = New-Object System.Windows.Forms.Label
$domainLabel.Location = New-Object System.Drawing.Point(10, 140)
$domainLabel.Size = New-Object System.Drawing.Size(430, 20)
$domainLabel.Text = "Dominio: millionx.local"
$domainLabel.ForeColor = [System.Drawing.Color]::Blue
$form.Controls.Add($domainLabel)

# Mostrar el formulario
$form.ShowDialog()