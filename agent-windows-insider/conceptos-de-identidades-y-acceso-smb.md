---
tipo: investigacion
estado: borrador
fecha: 2026-11-02
tags:
  - ciberseguridad
  - smb
  - cuentas
---

# Conceptos de identidades y acceso SMB

## Archivos y acceso por red

- **SMB (Server Message Block):** protocolo para acceder a archivos y carpetas compartidos por red. En este laboratorio publica el recurso `Laboratorio`.
- **NTFS (New Technology File System):** sistema de archivos de Windows que almacena archivos, carpetas y sus permisos. Sus restricciones se aplican tanto al acceso local como al realizado por SMB.
- **Recurso compartido:** carpeta publicada para acceder desde otros equipos. El nombre compartido puede ser diferente del nombre de la carpeta física.
- **Ruta UNC:** dirección de un recurso de red con formato `\\servidor\recurso\carpeta`, por ejemplo `\\192.168.100.30\Laboratorio\comun`.

## Usuarios y grupos

- **Active Directory (AD):** servicio que administra identidades y grupos del dominio. AD DS es el rol de Windows Server que lo implementa.
- **Dominio:** conjunto de identidades administradas de forma centralizada. Aquí es `lab.local`; `LAB` es su nombre corto.
- **Usuario:** identidad que se autentica mediante credenciales, por ejemplo `LAB\agent-windows`.
- **Grupo de seguridad:** conjunto de identidades al que se conceden permisos. Agregar o retirar usuarios del grupo cambia el acceso que reciben mediante él.
- **SID:** identificador de seguridad usado por Windows en las asignaciones de permisos. Renombrar una cuenta conserva su SID; eliminarla y crear otra con el mismo nombre genera uno distinto.
- **Autenticación y autorización:** la autenticación comprueba la identidad; la autorización determina qué acciones puede realizar.

## Permisos y herencia

- **ACL:** lista de control de acceso de un recurso. Contiene entradas que conceden o deniegan permisos.
- **ACE:** entrada individual de una ACL que relaciona una identidad con determinados permisos.
- **Herencia:** propagación de permisos desde una carpeta hacia sus archivos y subcarpetas. Una ACL protegida impide recibir permisos heredados del padre.
- **Permiso efectivo:** acceso final tras evaluar las asignaciones del usuario y sus grupos. Por SMB deben permitir la operación tanto los permisos del recurso compartido como los NTFS.

| Permiso          | Nivel | Qué permite                                                           |
| ---------------- | ----- | --------------------------------------------------------------------- |
| `Read`           | SMB   | Leer y listar contenido, sujeto a NTFS                                |
| `Change`         | SMB   | Leer, crear, modificar y eliminar contenido, sujeto a NTFS            |
| `Full`           | SMB   | Nivel máximo de acceso del recurso compartido; NTFS sigue aplicándose |
| `ReadAndExecute` | NTFS  | Leer, listar y ejecutar archivos                                      |
| `Modify`         | NTFS  | Leer, escribir, ejecutar y eliminar contenido                         |
| `FullControl`    | NTFS  | Control total, incluido cambiar permisos y propietario                |

En esta configuración, `Modify` se hereda solo al contenido. La carpeta superior tiene lectura y escritura sin permiso de eliminación, para proteger la estructura.
