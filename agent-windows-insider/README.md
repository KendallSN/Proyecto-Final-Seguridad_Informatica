# agent-windows — Guía de instalación

VM Windows del laboratorio: Active Directory + carpeta compartida (SMB), agente Wazuh, y objetivo de la demostración de escalada de privilegios como ataque interno (insider).

|               |                        |
| ------------- | ---------------------- |
| SO            | Windows Server 2022    |
| Rol           | Active Directory + SMB |
| RAM / vCPU    | 4 GB / 2               |
| IP (ZeroTier) | 192.168.100.30         |

## 1. Instalación base

1. Instalar Windows Server 2022 en VirtualBox (o usuario local si no da tiempo de levantar AD completo — ver nota al final).
2. Agregar el rol **Active Directory Domain Services** desde el Administrador del servidor (`Server Manager → Add Roles and Features → AD DS`), promover el servidor a controlador de dominio.
3. Configurar la carpeta compartida (SMB): `Server Manager → File and Storage Services → Shares`, crear el recurso compartido que use el equipo para la demostración.

## 2. Unirse a la red del equipo (ZeroTier)

1. Descargar e instalar ZeroTier One para Windows: https://www.zerotier.com/download/
2. Unirse a la red del equipo desde la GUI (ícono en la bandeja del sistema → Join Network) o por línea de comandos (PowerShell como administrador):
   
   ```powershell
   zerotier-cli join <ID de red del equipo>
   ```
3. Pedir a quien administra la red que autorice el nodo en `my.zerotier.com → Members`.

**DNS:** igual que en las VMs Linux del laboratorio, la red ZeroTier puede intentar publicar un DNS para sus miembros. Si la resolución de nombres falla después de unirse, revisar la configuración DNS del adaptador ZeroTier en `Panel de control → Centro de redes y recursos compartidos → Cambiar configuración del adaptador`, y fijar manualmente un DNS real (por ejemplo 1.1.1.1) si hace falta.

## 3. Archivo hosts

Igual que las VMs Linux, `agent-windows` referencia a `wazuh-server` por nombre, no por IP fija. Editar (como administrador) `C:\Windows\System32\drivers\etc\hosts` y agregar:

```
<IP de ZeroTier de wazuh-server>    wazuh-server
```

## 4. Instalación del agente Wazuh

PowerShell como Administrador:

```powershell
Invoke-WebRequest -Uri https://packages.wazuh.com/4.x/windows/wazuh-agent-4.9.0-1.msi -OutFile wazuh-agent.msi
.\wazuh-agent.msi /q WAZUH_MANAGER='wazuh-server' WAZUH_AGENT_NAME='agent-windows'
NET START WazuhSvc
```

Confirmar que el servicio corre: `Get-Service WazuhSvc`.

### Logs que debe recolectar

Verificar que el `ossec.conf` del agente (o del manager, según cómo esté centralizada la configuración) recolecte los canales de Windows Event Log necesarios para las reglas de Fase 3:

- **Security** — login (4624/4625), creación de cuentas (4720).
- **System**
- **Application**

### FIM

El manager vigila `C:\Windows\System32` por integridad de archivos (ver arquitectura, sección 3) — no requiere configuración adicional del lado del agente más allá de que el servicio esté activo.

## 5. Preparar la demostración de escalada de privilegios (T1068, ataque interno)

Esta VM es el objetivo del segundo enfoque de T1068 del equipo (el primero es nativo de Linux, en `agent-linux` — ver `attacker/README.md`). Se documenta como **ataque interno (insider)**: se ejecuta directamente en la máquina, no de forma remota desde Kali.

1. **Cuenta de prueba de bajo privilegio:** crear un usuario local o de dominio sin privilegios administrativos, separado de la cuenta de administrador del sistema — es la cuenta "comprometida" desde la que se demuestra el intento de escalada. No usar la cuenta admin para esto.
2. **Acceso para la demostración:** si hay acceso remoto disponible (RDP o SSH con el servidor OpenSSH de Windows habilitado), correr la prueba por ahí; si no, se ejecuta localmente en la consola de la VM durante la grabación.
3. **Instalar Invoke-AtomicRedTeam** (PowerShell como Administrador):
   
   ```powershell
   IEX (IWR 'https://raw.githubusercontent.com/redcanaryco/invoke-atomicredteam/master/install-atomicredteam.ps1' -UseBasicParsing)
   Install-AtomicRedTeam -getAtomics
   ```
4. **Ejecutar la técnica T1068** con la cuenta de bajo privilegio:
   
   ```powershell
   Invoke-AtomicTest T1068
   ```
   
   Revisar antes los detalles del test en https://github.com/redcanaryco/atomic-red-team/blob/master/atomics/T1068/T1068.md — confirmar qué hace exactamente antes de correrlo, y documentar el resultado (si escaló o no, y qué alerta generó Wazuh si la hubo) para el reporte de Fase 5.

## Referencias

- Wazuh, instalación de agente en Windows: https://documentation.wazuh.com/4.x/installation-guide/wazuh-agent/wazuh-agent-package-windows.html
- Invoke-AtomicRedTeam: https://github.com/redcanaryco/invoke-atomicredteam
- Atomic Red Team, técnica T1068: https://github.com/redcanaryco/atomic-red-team/blob/master/atomics/T1068/T1068.md
- ZeroTier para Windows: https://www.zerotier.com/download/
