---
tipo: actividad
estado: borrador
fecha: 2026-11-02
tags:
  - ciberseguridad
  - windows-server
  - zerotier
---

# Configuración DNS del cliente

El cliente utiliza `192.168.100.30` como DNS del laboratorio a través de ZeroTier. No se adjuntó una captura ni un resultado de resolución DNS.

## Configuración manual en Windows

1. Ejecutar `ncpa.cpl`.
2. Abrir las propiedades del adaptador ZeroTier.
3. Seleccionar `Protocolo de Internet versión 4 (TCP/IPv4)`.
4. Asignar `192.168.100.30` como servidor DNS.

## Configuración por comandos en Windows

```powershell
$ZT = (Get-NetAdapter | Where-Object {$_.Name -like "*ZeroTier*"} | Select-Object -First 1).Name
Set-DnsClientServerAddress -InterfaceAlias $ZT -ServerAddresses ("192.168.100.30")
ipconfig /flushdns
```

## Configuración propuesta para Linux

Para escribir el servidor DNS en `/etc/resolv.conf`, se anotó este comando, que requiere permisos de escritura sobre el archivo:

```bash
echo "nameserver 192.168.100.30" | tee /etc/resolv.conf > /dev/null
```

Este comando sobrescribe el contenido del archivo. No consta una ejecución ni una comprobación posterior en Linux.
