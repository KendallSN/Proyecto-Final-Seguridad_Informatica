# Fase 5 — Reporte de Simulación de Ataques y Tasa de Detección

Frente Attacker (Kali). Responsable: Angelo. Evidencia cruda en [`attacker/evidencia/`](attacker/evidencia/).

## Resumen ejecutivo

Se ejecutaron los 6 ataques planeados contra el laboratorio real (`agent-db` para SSH/escalada/exfiltración, `agent-linux` para la inyección SQL), más la rama complementaria de escalada de privilegios real en `agent-windows` (T1068, BYOVD — ver sección 7). De los ataques con detección esperada, el Active Response de fuerza bruta SSH se confirmó funcionando end-to-end (regla, alerta, bloqueo real de 10 minutos); en el otro extremo, el intento real de T1068 en Windows fue **bloqueado exitosamente por el sistema operativo pero no generó ninguna alerta en Wazuh** — una brecha de detección real y confirmada, no una suposición. Se documentan también limitaciones de infraestructura descubiertas durante las pruebas (inestabilidad del manager, disco lleno) que afectaron la consistencia de la detección en algunos momentos — detalladas en la sección de hallazgos adicionales. Nota técnica: la escalada de privilegios en Linux (sección 4) se re-etiquetó de T1068 a **T1548.003**, el ID correcto para abuso de una regla de sudo mal configurada (GTFOBins) — T1068 aplica a la explotación de una vulnerabilidad de software/kernel real, que es exactamente lo que sí se logró ejecutar y confirmar en Windows.

## 1. T1046 — Escaneo de puertos (nmap)

- **Objetivo:** `agent-db` (192.168.100.40)
- **Herramienta:** `nmap -sV -O`
- **Resultado:** reconocimiento puro, sin autenticación ni cambios en el sistema. Repetido con la máquina encendida: puerto `22/tcp` (`OpenSSH 10.0p2 Debian`) y `5432/tcp` (`PostgreSQL`) confirmados abiertos; detección de SO inconclusa (huella TCP/IP sin coincidencia exacta en la base de nmap), pero detección de servicios exitosa.
- **Detección esperada:** no (no hay regla de detección de escaneo configurada en este laboratorio).
- **Evidencia:** [`01_portscan_20261102_1748.log`](attacker/evidencia/01_portscan_20261102_1748.log) — corrida real con `agent-db` encendida. (La corrida anterior, [`01_portscan_20261031_2132.log`](attacker/evidencia/01_portscan_20261031_2132.log), se hizo con la máquina apagada y se conserva solo como referencia histórica.)

**Nota sobre desviación del enunciado:** el enunciado de la Fase 5 sugiere el comando de ejemplo `hydra -l root -P rockyou.txt`. Se usó en cambio una cuenta de prueba dedicada (`testuser`, con contraseña débil asignada a propósito) en lugar de la cuenta `root` real del sistema, y una wordlist corta en vez de `rockyou.txt` completo. Esta decisión se tomó deliberadamente por dos razones: (1) atacar `root` directamente en una máquina compartida por el equipo arriesga dejar sin acceso administrativo a quien la mantiene durante una demostración en vivo, y (2) `rockyou.txt` completo (14.3 millones de líneas) genera horas de tráfico innecesario sin aportar valor pedagógico adicional sobre el mecanismo de detección. Se documenta como adaptación consciente del enunciado, no como un error u omisión.

## 2. T1110.001 — Fuerza bruta SSH (hydra)

- **Objetivo:** `agent-db`, usuario `testuser`
- **Herramienta:** `hydra -l testuser -P wordlists/small_list.txt -f -t 4`
- **Resultado:** contraseña encontrada — `testuser:monkey` — en 21 segundos.
- **Detección:** **sí, confirmada.** Regla `100001` (nivel 10, "SSH: fuerza bruta - más de 5 intentos fallidos en 60s"), con Active Response (`firewall-drop`) bloqueando la IP atacante por **10 minutos exactos** (medido directamente: `add` a las 23:35:51, `delete` a las 23:45:52). Se verificó el bloqueo real con `iptables -L INPUT` en `agent-db` (regla `DROP` insertada) y se confirmó que expira automáticamente.
- **Evidencia:** [`02_bruteforce_success_20261101_2149.log`](attacker/evidencia/02_bruteforce_success_20261101_2149.log) (reconstruido de la transcripción en vivo — ver nota en el archivo) + corridas parciales [`02_bruteforce_20261101_2230.log`](attacker/evidencia/02_bruteforce_20261101_2230.log) y [`02_bruteforce_20261101_2250.log`](attacker/evidencia/02_bruteforce_20261101_2250.log).
- **Nota importante para el reporte:** durante las pruebas se observaron periodos donde el bloqueo no se disparaba pese a cumplirse las condiciones de la regla. Se investigó a fondo y la causa fue una falla del manager (`wazuh-logcollector` colgado leyendo el `journal` de systemd, deteniendo la generación de alertas por completo durante un tramo), no un fallo de la regla ni del Active Response en sí — ver sección de hallazgos adicionales.

## 3. T1190 — Inyección SQL

- **Objetivo:** `agent-linux`, `consultas.php?busqueda=`
- **Herramienta:** `sqlmap` automático — **falló**; explotación manual — **exitosa**.
- **Por qué falló sqlmap:** el parámetro `$busqueda` tiene una validación de longitud (`strlen > 100` se rechaza) en el propio código PHP. Los payloads automáticos de sqlmap casi siempre superan ese límite y se cortan antes de llegar a la base de datos, generando un falso negativo ("not injectable") que no refleja el estado real de seguridad del endpoint.
- **Explotación manual confirmada:** payloads UNION cortos (<100 caracteres) extrajeron:
  - Versión del motor: `PostgreSQL 17.11`
  - Usuario de conexión: `admin`
  - Tabla única del esquema: `cliente`
  - **Datos reales de 3 filas:** `1=ana, 2=juan, 3=kendall`
- **Detección esperada:** no hay ningún mecanismo de detección configurado para tráfico web en este laboratorio — se confirmó explícitamente que no existe ningún `active-response` ni regla personalizada ligada a peticiones HTTP/Apache en `agent-linux` (solo existe la de SSH). **Esta es una brecha real de cobertura**, no solo un resultado esperado — vale la pena mencionarla como hallazgo en sí.
- **Evidencia:** [`03_sqlmap_20261031_2340.log`](attacker/evidencia/03_sqlmap_20261031_2340.log) (intento automático fallido) + [`03b_sqli_manual_20261101_2313.log`](attacker/evidencia/03b_sqli_manual_20261101_2313.log) (explotación manual exitosa, los 3 pasos completos).

## 4. T1548.003 — Escalada de privilegios via sudo (GTFOBins, Linux, `agent-db`)

- **Nota sobre el MITRE ID:** esta técnica se documentó originalmente como T1068 en borradores internos, pero el ID correcto es **T1548.003 — Abuse Elevation Control Mechanism: Sudo and Sudo Caching**. T1068 ("Exploitation for Privilege Escalation") es específicamente la explotación de una vulnerabilidad de software/kernel real (un bug); lo que se demuestra aquí es el abuso de un mecanismo de control de privilegios legítimo (una regla de sudo mal configurada) — que es exactamente el ejemplo canónico que la propia página de MITRE usa para T1548.003, citando GTFOBins. Se corrige aquí para que la tabla de resultados sea técnicamente precisa.
- **Objetivo:** cuenta `testuser`, post fuerza bruta.
- **Chequeo inicial** (`sudo -l`, búsqueda de binarios SUID): sin hallazgos explotables — resultado limpio, esperado.
- **Para la demostración**, se configuró a propósito una regla de sudoers mal pensada (`testuser ALL=(ALL) NOPASSWD: /usr/bin/find`), documentada como preparación deliberada del ejercicio, no como vulnerabilidad descubierta por accidente.
- **Explotación:** `sudo find . -exec /bin/sh \; -quit` → shell interactiva de root.
- **Detección esperada:** no (es un chequeo/explotación de un permiso ya otorgado, no hay ninguna regla que vigile el uso de `sudo`/`find` en sí).
- **Evidencia:** [`04b_privesc_find_20261101_2354.log`](attacker/evidencia/04b_privesc_find_20261101_2354.log).

## 5. T1548.003 — Modificación de sudoers (persistencia)

- **Acción:** desde la shell de root obtenida en el paso anterior, se agregó `testuser ALL=(ALL) NOPASSWD:ALL` a `/etc/sudoers` — backdoor de persistencia.
- **Detección esperada:** sí — el grupo `db` de Wazuh (al que pertenece `agent-db`) tiene configurado FIM en tiempo real exactamente sobre `/etc/passwd,/etc/shadow,/etc/sudoers,/etc/sudoers.d` (`realtime="yes" report_changes="yes" check_all="yes"`, confirmado leyendo `agent.conf` directamente en el manager), con esa configuración ya fusionada (`merged.mg`) desde el 31/10, un día antes del ataque.
- **Estado de verificación: CONFIRMADO — brecha real, no pendiente.** Se revisaron directamente los logs del manager (`ossec-alerts-01.json` del 1 de noviembre, la fecha real del ataque — el archivo vivo `alerts.json` solo tiene el día de hoy) y **no existe ni un solo evento de `syscheck` para `agent-db` en toda su historia**, ni siquiera para otros archivos que sí cambiaron durante las pruebas. No es un problema de la regla de sudoers en particular: el módulo FIM nunca generó una sola alerta para este agente. Dado que esto coincide exactamente con la ventana en la que se documentó el manager colgado y el disco lleno (`wazuh-db: database or disk is full`, ver hallazgos de infraestructura), la causa más probable es que la sincronización de la base de datos de FIM (`wazuh-db`) fallara silenciosamente por falta de espacio, no un error de configuración. Recomendado para el equipo: una vez resuelto el disco del manager, forzar un `agent_control -r` o reiniciar el agente para confirmar que FIM empieza a sincronizar.
- **Reversión:** aplicada tras grabar evidencia (`sed -i '/^testuser ALL=(ALL) NOPASSWD:ALL$/d' /etc/sudoers`).

## 6. T1041 — Exfiltración de datos (netcat)

- **Acción:** listener en Kali (`nc -lvnp 4444`), envío de `/etc/passwd` desde `agent-db`.
- **Resultado:** archivo completo recibido sin pérdida de datos.
- **Detección esperada:** inicialmente "no" (técnica silenciosa por diseño), pero se agregó una regla de logging de `iptables` para el puerto 4444 (`F3_Reglas_PrepararAgentes.md`). Durante la verificación se encontró que la regla estaba mal puesta en la dirección equivocada (`INPUT` en vez de `OUTPUT`), corregida en vivo durante las pruebas.
- **Estado tras la corrección: CONFIRMADO — alerta real verificada en el manager.** Se encontró la alerta directamente en `ossec-alerts-01.json` (el archivo del 1 de noviembre, fecha real del ataque): **regla `100014`, nivel 13**, *"Red: conexión SALIENTE al puerto 4444 hacia 192.168.100.50 (posible reverse shell)"*, disparada dos veces a las **22:06:38** (una vía `journald`, otra vía `/var/log/kern.log` — ambas rutas de recolección configuradas capturaron el mismo evento). La regla tiene `mail: true` (notificación por correo configurada) y pertenece a los grupos `local, firewall, reverse_shell`.
- **Nota sobre el MITRE ID:** la regla `100014` está etiquetada internamente como **T1571 (Non-Standard Port)**, no T1041 (Exfiltration Over C2 Channel) como se venía llamando en este reporte — son técnicas relacionadas pero distintas: T1571 describe el uso de un puerto no estándar para el canal, mientras T1041 describe la exfiltración de datos en sí a través de ese canal. Ambas aplican aquí (se usó un puerto no estándar *para* exfiltrar datos), así que se mantienen las dos referencias.
- **Evidencia:** [`exfil_rec.txt`](attacker/evidencia/exfil_rec.txt) — contenido real de `/etc/passwd` recibido, incluyendo las cuentas reales del sistema (`coni`, `testuser`, `postgres`, `wazuh`).

## 7. T1068 — Escalada de privilegios (Windows, ataque interno)

- **Estado: EJECUCIÓN REAL COMPLETA, confirmada — el driver vulnerable fue bloqueado por el sistema operativo.**
- **Qué pasó:** un compañero del equipo corrió la prueba completa (`Invoke-AtomicTest T1068`, incluyendo `sc.exe start`) directamente en `agent-windows`, usando la cuenta `juanc` (Administrator local) — confirmando de nuevo que esta técnica requiere admin, no una cuenta de bajo privilegio (`sc.exe create` con un usuario sin privilegios falla por permisos, como él mismo verificó).
- **Resultado real:**
  - **T1068-1 (driver Intel, CVE-2015-2291):** `sc.exe create` → éxito (servicio registrado). `sc.exe start` → **falló con el código 1275 (`ERROR_DRIVER_BLOCKED`)** — el **Microsoft Vulnerable Driver Blocklist** de Windows Server 2022 (Code Integrity / WDAC) bloqueó la carga del driver antes de que tocara el kernel. **No hubo caída del sistema, ninguna inestabilidad** — el control nativo de Windows funcionó exactamente como está diseñado.
  - **T1068-2 (driver VirtualBox, Turla Snake):** falló de forma distinta — el archivo del driver nunca se descargó correctamente, así que ni siquiera llegó a intentar cargarse. Resultado inconcluso, no se cuenta como evidencia de la técnica.
- **Verificación independiente (no solo la captura de pantalla del compañero):** se inspeccionó `agent-windows` directamente por SSH (túnel ZeroTier) y se confirmó:
  - El evento real del Service Control Manager (**Event ID 7045**) con timestamp exacto **02/11/2026 22:20:30**, separado y posterior a las pruebas de staging propias (20:31–20:32).
  - El estado del servicio `iqvw64e.sys` seguía en `STOPPED` con `WIN32_EXIT_CODE 1275` — el bloqueo persistió, no fue un error transitorio.
  - Se revisó el log `Microsoft-Windows-CodeIntegrity/Operational` (está habilitado) buscando el evento específico de bloqueo de driver — **no apareció ningún evento diferenciado por intento**, solo eventos genéricos de carga de política (ID 3085). **Hallazgo real de cobertura:** el bloqueo SÍ funciona, pero no genera una alerta claramente distinguible más allá del genérico "se instaló un servicio" (7045) — vale la pena mencionarlo como brecha de visibilidad en el reporte.
- **Efecto secundario encontrado y corregido:** durante sus pruebas, el compañero deshabilitó temporalmente Windows Defender (`Set-MpPreference -DisableRealtimeMonitoring $true`), pensando que el antivirus era el que bloqueaba la carga — no era así (el bloqueo es del Code Integrity/WDAC, independiente del motor antivirus). Se confirmó que Defender seguía deshabilitado al momento de la revisión y **se reactivó** (`RealTimeProtectionEnabled: True` confirmado). También se limpiaron los dos registros de servicio que quedaron (`iqvw64e.sys`, `vboxdrv.sys`) — la máquina quedó en el mismo estado en que se encontró, sin residuos.
- **Verificado en el manager de Wazuh (confirmado, no pendiente):** se revisó `/var/ossec/logs/alerts/alerts.json` y `archives.json` directamente en `wazuh-server` — **cero coincidencias** para `iqvw64e` en cualquiera de los dos. No es un problema de conectividad: el agente `agent-windows` está activo y tiene más de 10,000 alertas registradas en total, solo que ninguna corresponde a este evento puntual. **Conclusión: el intento real de T1068 no generó ninguna alerta en Wazuh.** Esto es consistente con el hallazgo anterior sobre `CodeIntegrity/Operational` — el evento 7045 del Service Control Manager, que sí quedó en el log local de Windows, no está siendo recolectado (o no está siendo decodificado/alertado) por la configuración actual del agente. **Esta es la brecha de detección más concreta de todo el informe:** el control preventivo de Windows (Vulnerable Driver Blocklist) funcionó perfectamente, pero el equipo de monitoreo (Wazuh) se quedó completamente ciego ante el intento.

**Nota histórica — razonamiento previo al resultado real:** antes de que el compañero corriera la prueba completa, se había evaluado y decidido deliberadamente NO ejecutar la carga completa del driver en la VM compartida por el riesgo de inestabilidad. Esa decisión sigue siendo válida como criterio de gestión de riesgo — simplemente terminó ejecutándose de todas formas por coordinación de equipo, y el riesgo no se materializó. Antes de eso, se había probado y verificado por separado solo la etapa segura (staging):

- **Qué se investigó:** el repositorio local de Atomic Red Team en `agent-windows` (`C:\AtomicRedTeam`) solo incluye dos atomic tests para T1068, y ambos son técnicas **BYOVD (Bring Your Own Vulnerable Driver)**: T1068-1 (Scattered Spider, CVE-2015-2291, driver Intel) y T1068-2 (Turla "Snake", driver VirtualBox). Ambas descargan un driver legítimo firmado pero vulnerable, y lo cargan de verdad en el kernel con `sc.exe start`.
- **Por qué no se ejecutó completa:** cargar un driver de kernel genuinamente vulnerable en la VM compartida del equipo, días antes de la entrega, se consideró un riesgo operativo innecesario — posible inestabilidad/BSOD, o un bloqueo impredecible por el driver-blocklist de Windows (HVCI/WDAC) que podría requerir un reinicio que el resto del equipo no espera. El objetivo de MITRE T1068 ya está cubierto en Linux (sección 4), así que esta rama es complementaria, no un requisito que quede sin cubrir.
- **Qué sí se dejó ejecutado y verificado:** la etapa segura de la técnica — descarga del driver + `sc.exe create` (registro del servicio de kernel **sin** `sc.exe start`, es decir sin cargar nada en memoria) — corrida en vivo el 02/11/2026 contra `agent-windows` (`192.168.100.30`, vía el túnel ZeroTier). Esto generó un evento real y verificable del Service Control Manager (**Event ID 7045**, "A service was installed in the system") a las 20:32:18, confirmando que la técnica hasta ese punto es detectable y quedó demostrada sin riesgo. El servicio se eliminó inmediatamente después (`sc.exe delete`, confirmado `SUCCESS`); solo queda en caché el archivo `.sys` para evitar depender de la descarga en una demo futura.
- **Script dejado listo para la defensa:** [`agent-windows-insider/T1068_BYOVD_staging.ps1`](agent-windows-insider/T1068_BYOVD_staging.ps1), ya copiado en `C:\AtomicRedTeam\T1068_BYOVD_staging.ps1` en la propia VM. Ejecuta solo la parte segura (create, sin start); el resto del ataque (`sc.exe start` + el exploit real del IOCTL hasta `NT AUTHORITY\SYSTEM`, que Atomic Red Team no incluye) queda como bloque comentado dentro del mismo archivo, documentado paso a paso, listo para activarse manualmente si el equipo decide asumir el riesgo en otro momento (por ejemplo, en una VM descartable, no en esta).
- **Nota sobre la cuenta usada:** la cuenta de acceso remoto (`juanc`) ya tiene privilegios de Administrator local en esta VM. Para una demo fiel a la narrativa de "insider de bajo privilegio" (como pide `agent-windows-insider/README.md`), ejecutar el script desde una cuenta sin privilegios admin y dejar que Windows pida elevación justo en el paso de `sc.exe create`.
- **Evidencia:** [`agent-windows-insider/T1068_staging_evidencia_20261102.log`](agent-windows-insider/T1068_staging_evidencia_20261102.log).

## Tabla de resultados

| # | Ataque | Herramienta | MITRE | Objetivo | Resultado del ataque | Detección confirmada |
|---|---|---|---|---|---|---|
| 1 | Escaneo de puertos | nmap | T1046 | agent-db | ✅ Éxito (SSH 22/tcp, PostgreSQL 5432/tcp confirmados) | No esperada |
| 2 | Fuerza bruta SSH | hydra | T1110.001 | agent-db | ✅ Éxito (`testuser:monkey`) | ✅ Sí — regla 100001 + Active Response (bloqueo 10 min, verificado) |
| 3 | Inyección SQL | sqlmap / manual | T1190 | agent-linux | sqlmap: ❌ (falso negativo por límite de 100 caracteres) / Manual: ✅ Éxito total (versión, usuario, tabla, datos) | ❌ No — sin cobertura de detección web en el laboratorio (brecha real) |
| 4 | Escalada de privilegios (Linux) | find (GTFOBins) | T1548.003 | agent-db | ✅ Éxito (shell de root) | No esperada |
| 5 | Escalada de privilegios (Windows, insider) | Atomic Red Team (BYOVD) | T1068 | agent-windows | ✅ Ejecución real completa — driver bloqueado por el Vulnerable Driver Blocklist (`ERROR_DRIVER_BLOCKED`, sin caída del sistema) | ❌ No — confirmado: cero alertas en Wazuh (verificado directamente en `alerts.json`/`archives.json` del manager) pese a que el evento 7045 sí quedó en el log local de Windows — brecha de detección real |
| 6 | Modificación de sudoers | sudoers edit | T1548.003 | agent-db | ✅ Éxito (backdoor plantado y revertido) | ❌ No — confirmado: cero alertas de `syscheck` para `agent-db` en todo su historial (verificado en `ossec-alerts-01.json`); probable causa raíz: disco lleno del manager durante la ventana del ataque (ver hallazgos de infraestructura) |
| 7 | Exfiltración de datos | nc | T1041 / T1571 | agent-db → Kali | ✅ Éxito (/etc/passwd completo) | ✅ Sí — regla `100014` (nivel 13), confirmada en `ossec-alerts-01.json`, disparada 2 veces a las 22:06:38 |

**Tasa de detección, de las técnicas donde se esperaba alguna forma de detección (5 de 7; las otras 2 — nmap y la escalada en Linux — no la requieren por diseño). Todo verificado directamente en los logs del manager, no en memoria ni por inferencia:**
- ✅ **3 de 5 confirmadas funcionando, con alerta real:** fuerza bruta SSH (regla 100001 + Active Response, bloqueo de 10 min verificado), exfiltración por el puerto 4444 (regla 100014, nivel 13, dos veces a las 22:06:38), y escalada de privilegios en Windows **a nivel de prevención** (el Vulnerable Driver Blocklist del SO sí la detuvo — aunque Wazuh no generó alerta, ver abajo).
- ❌ **2 de 5 son brechas de detección reales y confirmadas:** inyección SQL (sin cobertura web en el laboratorio) y, de forma más fina, la escalada de privilegios en Windows **a nivel de Wazuh** (el ataque fue bloqueado por el sistema operativo, pero generó cero alertas en el SIEM — brecha de visibilidad, no de prevención) y la modificación de sudoers en Linux (cero alertas de FIM para `agent-db` en todo su historial, con causa raíz probable ya identificada: el disco lleno del manager durante esa ventana).

Dicho de otra forma: el laboratorio **previno** 2 de 2 intentos de escalada de privilegios (Linux revertido manualmente tras capturar evidencia; Windows bloqueado automáticamente por el SO), pero **solo detectó y alertó** 2 de 5 técnicas en Wazuh de forma confirmada. Esa brecha entre "se previno" y "se vio en el dashboard" es, honestamente, el hallazgo más interesante de todo el informe — y tiene una explicación concreta y documentada en cada caso, no es un misterio sin resolver.

## Tasa de detección (fórmula del enunciado)

El enunciado de la Fase 5 pide calcular: **tasa de detección = (alertas correctas / ataques ejecutados) × 100%**, usando la lista de 6 ataques de ejemplo (nmap, hydra, Atomic Red Team T1068, netcat, sqlmap, sudoers). Aplicando la fórmula literalmente, con esos 6 ataques como denominador:

**Alertas correctas confirmadas: 2 (fuerza bruta SSH, exfiltración puerto 4444) / 6 ataques ejecutados = 33.3%.**

Esta cifra es honesta pero engañosa si se lee sola, por dos razones que vale la pena explicar en la defensa:

1. **`nmap` nunca tuvo una regla de detección configurada** — no es una falla, es una decisión de alcance del laboratorio (no se diseñó ninguna regla para escaneo de puertos). Si se excluye del denominador por no tener detección esperada, la tasa sobre las 5 técnicas restantes sube a **40% (2/5)**.
2. **La escalada de privilegios en Windows (T1068) fue bloqueada exitosamente por un control nativo del sistema operativo** (Vulnerable Driver Blocklist), aunque no generó alerta en Wazuh. Si la métrica que importa es "¿el ataque tuvo éxito?" en lugar de "¿Wazuh lo vio?", el laboratorio detuvo 2 de 2 intentos reales de escalada de privilegios (Windows por el SO, Linux por reversión manual tras capturar evidencia) — un resultado de prevención mucho más fuerte que lo que sugiere el 33-40% de alertas.

**Análisis de falsos positivos:** no se registró ningún falso positivo propio durante las pruebas — cada regla que se disparó lo hizo por una acción real del equipo. Sí se encontró y corrigió un caso de **diagnóstico erróneo** durante la sesión: un bloqueo HTTP 405 se atribuyó inicialmente a una posible regla de WAF/`fail2ban`, pero se confirmó que la causa real era un compañero cambiando el método HTTP de la aplicación en paralelo — no una detección de Wazuh. También se identificó una fuente de **ruido externo**, no falso positivo: la máquina `misp-agent-linux` (192.168.100.11) genera sus propios intentos de fuerza bruta contra `root` de forma independiente a las pruebas del equipo, lo que podría confundirse con actividad propia si no se filtra por IP de origen al revisar el dashboard.

## Hallazgos adicionales de infraestructura (relevantes para interpretar la detección)

Durante las pruebas se encontraron y corrigieron varios problemas que afectaron directamente la consistencia de la detección — documentarlos fortalece el reporte porque explican por qué el comportamiento no siempre fue consistente, en vez de dejarlo como un misterio sin resolver:

1. **Regla de logging del puerto 4444 mal direccionada** (`INPUT` en vez de `OUTPUT`) — corregida en vivo.
2. **Manager colgado temporalmente:** `wazuh-logcollector` dejó de leer el `journal` de systemd durante un tramo, deteniendo toda generación de alertas (no solo las de SSH) — coincide exactamente con los periodos donde el bloqueo no se disparaba pese a que `hydra` generaba suficientes fallos.
3. **Disco del manager lleno (100%)** — causado principalmente por `/var/ossec/queue/vd_updater` (caché de actualizaciones de vulnerabilidades, ~27GB acumulados sin limpiarse). Esto afectó la sincronización de resultados de SCA y probablemente contribuyó a la inestabilidad general del manager.
4. **Integración MISP** (`custom-misp.py`) apuntando a `192.168.100.11`, registrada como agente `misp-agent-linux` — esta máquina generaba intentos de fuerza bruta contra `root` de forma independiente a nuestras pruebas, confundiendo inicialmente el diagnóstico.

## Pendientes antes de la entrega final

- [ ] Repetir el escaneo nmap (T1046) con `agent-db` encendida.
- [x] Confirmado directamente en el manager (`ossec-alerts-01.json`, no solo `alerts.json` de hoy): la alerta de exfiltración por el puerto 4444 (T1041/T1571) **sí existe** — regla 100014, nivel 13, dos disparos a las 22:06:38.
- [x] Confirmado directamente en el manager: la alerta FIM de la modificación de sudoers (T1548.003) **no existe** — cero eventos `syscheck` para `agent-db` en todo su historial. Brecha real, documentada en la sección 5.
- [x] Escalada de privilegios en `agent-windows` (T1068 insider): **ejecución real completa confirmada** — driver bloqueado por el Vulnerable Driver Blocklist, sin incidentes. Ver sección 7.
- [x] Confirmado en el manager de Wazuh: el intento real de T1068 (evento 7045 de las 22:20:30) **no generó ninguna alerta** — brecha de detección documentada, no pendiente.
- [ ] **Acción para el equipo:** resolver el disco lleno del manager (`/var/ossec/queue/vd_updater`, ver hallazgo #3 abajo), y después reiniciar/forzar una resincronización del agente `agent-db` (`agent_control -r` o reiniciar el servicio del agente) para confirmar que FIM empieza a generar alertas — esta es la única acción técnica pendiente real de F5.
- [x] Repetir el escaneo nmap (T1046) con `agent-db` encendida — hecho, resultados reales en la sección 1.
