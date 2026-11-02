---
tipo: actividad
estado: completado
fecha: 2026-11-02
tags:
  - ciberseguridad
  - smb
  - verificacion
  - windows-server
---

# Verificación de accesos SMB

Registro de las comprobaciones de acceso al recurso `Laboratorio`. Los resultados corresponden a la configuración verificada en el laboratorio.

## Registro de verificación

### Comprobación inicial de conexión y escritura

Con `LAB\usuario-prueba` se estableció una conexión al recurso `Laboratorio`:

```powershell
net use \\192.168.100.30\Laboratorio /user:LAB\usuario-prueba *
Get-ChildItem -LiteralPath '\\192.168.100.30\Laboratorio'
New-Item -Path '\\192.168.100.30\Laboratorio\prueba escritura.txt' -ItemType File -ErrorAction Stop
```

![Conexión SMB completada y creación de prueba escritura.txt denegada para usuario-prueba](../../Adjuntos/prueba-conexion.png)

La consola confirma la conexión con «Se ha completado el comando correctamente». El intento de crear `prueba escritura.txt` en la raíz del recurso devuelve `PermissionDenied`, `UnauthorizedAccessException` y `NewItemUnauthorizedAccessError`.

![Detalle del acceso denegado al crear un archivo en la raíz de Laboratorio](../../Adjuntos/prueba-creacion.png)

Estas capturas documentan autenticación correcta y escritura denegada en la raíz. El listado no muestra elementos visibles; por sí solo no acredita lectura de archivos. La comprobación posterior amplía la evidencia de lectura y comprueba la edición permitida en `comun`.

### Comprobación posterior del acceso global

La configuración se aplicó y comprobó el 2026-10-31, con confirmación de funcionamiento.

- Las seis cuentas están habilitadas. Se conservaron sus contraseñas y la cuenta administrativa `LAB\juanc`.
- `agent-windows` tiene lectura y modificación de contenido en todo `Laboratorio` mediante `SMB-Recursos-Escritura`.
- `usuario-prueba` tiene lectura en todos los recursos mediante `SMB-Recursos-Lectura` y conserva edición en `comun` mediante `SMB-Comun-Escritura`.
- Los demás usuarios conservan sus accesos por carpeta y en `comun`.
- Se verificaron grupos, ACL, cifrado SMB y enumeración basada en acceso. Las sesiones SMB antiguas se renovaron para incorporar los grupos nuevos.

## Archivos de comprobación

Con la identidad autenticada `LAB\agent-windows` se creó, editó y leyó un archivo en cada ubicación:

| Ubicación             | Resultado |
| --------------------- | --------- |
| Raíz de `Laboratorio` | Correcto  |
| `agent-db`            | Correcto  |
| `agent-linux`         | Correcto  |
| `agent-windows`       | Correcto  |
| `comun`               | Correcto  |
| `minpriv`             | Correcto  |
| `usuario-prueba`      | Correcto  |
| `wazuh-server`        | Correcto  |

Los ocho archivos se llaman `verificacion-agent-windows-1aa6d001b6b94897b632c5076a369b2f.txt` y permanecen en el recurso. Su propietario es `LAB\agent-windows`.

Con `usuario-prueba` se comprobó lectura de los ocho archivos, escritura denegada fuera de `comun` y edición permitida dentro de ella. Después de renovar la conexión, desde `192.168.100.31` se listaron todas las carpetas y se leyeron los ocho archivos por SMB.

El archivo anterior `comun\hola-usuario-prueba.txt` conservó su contenido.

## Evidencias

- ACL anteriores y resultados actuales: `C:\Laboratorio\Evidencias\smb-acceso-global-20261101-012136`.
- Las carpetas de la migración anterior siguen recuperables en `C:\Laboratorio\_papelera\smb-anterior-20261101-004749`.
- Las comprobaciones anteriores de aislamiento de `agent-windows` y `usuario-prueba` quedan sustituidas por el alcance global autorizado descrito en esta bitácora.

