---
tipo: formato
estado: completado
fecha: 2026-11-02
tags:
  - ciberseguridad
  - active-directory
  - smb
  - powershell
---

# Administración de cuentas y permisos

Procedimientos para administrar cuentas y permisos desde PowerShell elevado en `agent-windows`. Los bloques presentan operaciones alternativas; no constituyen un registro de ejecución de todas ellas. Ajustar las variables antes de utilizarlos.

## Preparación

```powershell
$ErrorActionPreference = 'Stop'
Import-Module ActiveDirectory
$cuenta = 'nuevo-lab'
$grupo = 'SMB-Nuevo-Lectura'
$ruta = Join-Path 'C:\Laboratorio\Compartido' $cuenta
$ou = 'OU=Laboratorio,DC=lab,DC=local'
$identidadGrupo = "LAB\$grupo"
$identidadUsuario = "LAB\$cuenta"
```

## Crear, modificar o eliminar usuarios

Crear una cuenta y habilitarla después de asignar la contraseña:

```powershell
New-ADUser -Name $cuenta -SamAccountName $cuenta -UserPrincipalName "$cuenta@lab.local" -Path $ou -Enabled $false
Set-ADAccountPassword -Identity $cuenta -Reset -NewPassword (Read-Host 'Contraseña' -AsSecureString)
Enable-ADAccount -Identity $cuenta
```

Modificar descripción o restablecer la contraseña:

```powershell
Set-ADUser -Identity $cuenta -Description 'Acceso SMB del laboratorio'
Set-ADAccountPassword -Identity $cuenta -Reset -NewPassword (Read-Host 'Nueva contraseña' -AsSecureString)
```

La nueva contraseña debe cumplir la política vigente. Windows puede rechazar una clave que contenga el nombre de la cuenta; esto afecta, por ejemplo, a un futuro restablecimiento de `minpriv`. [Política de contraseñas](https://learn.microsoft.com/en-us/windows/win32/secmgmt/strong-password-enforcement-and-passfilt-dll).

Renombrar la cuenta conservando su SID:

```powershell
$id = (Get-ADUser -Identity $cuenta).ObjectGUID
$nuevoNombre = 'usuario-lab'
Set-ADUser -Identity $id -SamAccountName $nuevoNombre -UserPrincipalName "$nuevoNombre@lab.local"
Rename-ADObject -Identity $id -NewName $nuevoNombre
```

Renombrar el usuario no renombra su carpeta. Actualizar las variables antes de continuar con otros ejemplos.

Suspender o eliminar una cuenta:

```powershell
Disable-ADAccount -Identity $cuenta

# Eliminación del objeto AD; solicita confirmación.
Remove-ADUser -Identity $cuenta -Confirm
```

No usar estas operaciones sobre `juanc` ni las cuentas internas del dominio como parte de una limpieza de usuarios SMB.

## Crear, modificar o quitar permisos SMB

Crear un grupo de seguridad, su carpeta y el permiso de lectura:

```powershell
New-ADGroup -Name $grupo -SamAccountName $grupo -Path $ou -GroupScope Global -GroupCategory Security
New-Item -Path $ruta -ItemType Directory
Grant-SmbShareAccess -Name Laboratorio -AccountName $identidadGrupo -AccessRight Read -Force
```

Para un grupo nuevo, permitir también lectura y recorrido de la raíz, solo en esa carpeta:

```powershell
$raiz = 'C:\Laboratorio\Compartido'
$aclRaiz = Get-Acl -LiteralPath $raiz
$aclRaiz.AddAccessRule([System.Security.AccessControl.FileSystemAccessRule]::new($identidadGrupo, 'ReadAndExecute', 'Allow'))
Set-Acl -LiteralPath $raiz -AclObject $aclRaiz
```

Cambiar a modificación o retirar el permiso:

```powershell
# Cambiar: retirar la concesión anterior y asignar la nueva.
Revoke-SmbShareAccess -Name Laboratorio -AccountName $identidadGrupo -Force
Grant-SmbShareAccess -Name Laboratorio -AccountName $identidadGrupo -AccessRight Change -Force

# Quitar todas las concesiones SMB directas de este grupo.
Revoke-SmbShareAccess -Name Laboratorio -AccountName $identidadGrupo -Force
```

Estos comandos afectan al grupo en todo el recurso `Laboratorio`; la carpeta concreta se limita mediante NTFS. [Conceder permisos SMB](https://learn.microsoft.com/en-us/powershell/module/smbshare/grant-smbshareaccess), [retirar permisos SMB](https://learn.microsoft.com/en-us/powershell/module/smbshare/revoke-smbshareaccess).

## Crear, modificar o quitar permisos NTFS

Esta función reemplaza las entradas explícitas de una identidad en la carpeta indicada y conserva las de las demás. El perfil de modificación protege la carpeta superior igual que la configuración actual.

```powershell
function Set-PermisoCarpeta {
    param(
        [Parameter(Mandatory)] [string] $Ruta,
        [Parameter(Mandatory)] [string] $Identidad,
        [ValidateSet('Lectura', 'Modificar', 'Quitar')]
        [string] $Acceso = 'Lectura'
    )

    $acl = Get-Acl -LiteralPath $Ruta
    $sid = ([System.Security.Principal.NTAccount]::new($Identidad)).Translate([System.Security.Principal.SecurityIdentifier])

    foreach ($regla in @($acl.GetAccessRules($true, $false, [System.Security.Principal.SecurityIdentifier]))) {
        if ($regla.IdentityReference.Value -eq $sid.Value) {
            $acl.RemoveAccessRuleSpecific($regla)
        }
    }

    if ($Acceso -eq 'Lectura') {
        $acl.AddAccessRule(
            [System.Security.AccessControl.FileSystemAccessRule]::new(
                $sid, 'ReadAndExecute', 'ContainerInherit,ObjectInherit', 'None', 'Allow'
            )
        )
    } elseif ($Acceso -eq 'Modificar') {
        $acl.AddAccessRule(
            [System.Security.AccessControl.FileSystemAccessRule]::new(
                $sid, 'ReadAndExecute,Write', 'None', 'None', 'Allow'
            )
        )
        $acl.AddAccessRule(
            [System.Security.AccessControl.FileSystemAccessRule]::new(
                $sid, 'Modify', 'ContainerInherit,ObjectInherit', 'InheritOnly', 'Allow'
            )
        )
    }

    Set-Acl -LiteralPath $Ruta -AclObject $acl
}
```

Elegir la operación que corresponda:

```powershell
# Crear o sustituir por lectura.
Set-PermisoCarpeta -Ruta $ruta -Identidad $identidadGrupo -Acceso Lectura

# Cambiar a modificación de contenido.
Set-PermisoCarpeta -Ruta $ruta -Identidad $identidadGrupo -Acceso Modificar

# Quitar las entradas explícitas de ese grupo en esta carpeta.
Set-PermisoCarpeta -Ruta $ruta -Identidad $identidadGrupo -Acceso Quitar

# Si se retira todo acceso del grupo, quitar también su entrada en la raíz.
Set-PermisoCarpeta -Ruta 'C:\Laboratorio\Compartido' -Identidad $identidadGrupo -Acceso Quitar
```

No modifica las ACL explícitas que ya existan en archivos o subcarpetas. Retirar una entrada tampoco elimina accesos concedidos por otros grupos o por herencia.

## Asignar o quitar permisos a un usuario

El método habitual es asignar el usuario al grupo autorizado:

```powershell
# Asignar los permisos del grupo.
Add-ADGroupMember -Identity $grupo -Members $cuenta

# Quitar los permisos que recibe mediante ese grupo.
Remove-ADGroupMember -Identity $grupo -Members $cuenta -Confirm
```

Si se necesita una excepción directa para un usuario, conceder ambos niveles:

```powershell
# Asignación directa de lectura en SMB y en la carpeta.
Grant-SmbShareAccess -Name Laboratorio -AccountName $identidadUsuario -AccessRight Read -Force
Set-PermisoCarpeta -Ruta $ruta -Identidad $identidadUsuario -Acceso Lectura

# Cambiar la excepción directa a modificación de contenido.
Revoke-SmbShareAccess -Name Laboratorio -AccountName $identidadUsuario -Force
Grant-SmbShareAccess -Name Laboratorio -AccountName $identidadUsuario -AccessRight Change -Force
Set-PermisoCarpeta -Ruta $ruta -Identidad $identidadUsuario -Acceso Modificar
```

Para quitar esa excepción directa:

```powershell
Revoke-SmbShareAccess -Name Laboratorio -AccountName $identidadUsuario -Force
Set-PermisoCarpeta -Ruta $ruta -Identidad $identidadUsuario -Acceso Quitar
```

Si el usuario sigue perteneciendo a un grupo autorizado, conservará el acceso de ese grupo. Al cambiar membresías, cerrar su conexión SMB y volver a conectarse para renovar la sesión.

## Consultar las asignaciones

```powershell
Get-ADUser -Identity agent-windows -Properties MemberOf
Get-ADGroupMember -Identity SMB-Agent-Windows
Get-SmbShareAccess -Name Laboratorio
(Get-Acl 'C:\Laboratorio\Compartido\agent-windows').Access | Format-Table IdentityReference,FileSystemRights,InheritanceFlags,PropagationFlags
(Get-Acl 'C:\Laboratorio\Compartido\comun').Access | Format-Table IdentityReference,FileSystemRights,InheritanceFlags,PropagationFlags
Get-SmbSession | Select-Object ClientUserName,ClientComputerName,NumOpens
```

