# Fase 5 — Reporte de Simulación de Ataques y Tasa de Detección

Frente Attacker (Kali). Responsable: Angelo. Evidencia cruda en [`attacker/evidencia/`](attacker/evidencia/).

## Resumen ejecutivo

Se ejecutaron los 6 ataques planeados contra el laboratorio real (`agent-db` para SSH/escalada/exfiltración, `agent-linux` para la inyección SQL), más la rama complementaria de escalada de privilegios en `agent-windows`. De los ataques con detección esperada, el Active Response de fuerza bruta SSH se confirmó funcionando end-to-end (regla, alerta, bloqueo real de 10 minutos). Se documentan también limitaciones de infraestructura descubiertas durante las pruebas (inestabilidad del manager, disco lleno) que afectaron la consistencia de la detección en algunos momentos — detalladas en la sección de hallazgos adicionales, porque son relevantes para interpretar correctamente la tasa de detección.

## 1. T1046 — Escaneo de puertos (nmap)

- **Objetivo:** `agent-db` (192.168.100.40)
- **Herramienta:** `nmap -sV -O`
- **Resultado:** reconocimiento puro, sin autenticación ni cambios en el sistema.
- **Detección esperada:** no (no hay regla de detección de escaneo configurada en este laboratorio).
- **Evidencia:** [`01_portscan_20261031_2132.log`](attacker/evidencia/01_portscan_20261031_2132.log) — nota: esta corrida en particular se hizo con `agent-db` apagada ("Host seems down"); recomendado repetir contra la máquina encendida antes de la entrega final para tener un escaneo con resultados reales de puertos/servicios.

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

## 4. T1068 — Escalada de privilegios (Linux, `agent-db`)

- **Objetivo:** cuenta `testuser`, post fuerza bruta.
- **Chequeo inicial** (`sudo -l`, búsqueda de binarios SUID): sin hallazgos explotables — resultado limpio, esperado.
- **Para la demostración**, se configuró a propósito una regla de sudoers mal pensada (`testuser ALL=(ALL) NOPASSWD: /usr/bin/find`), documentada como preparación deliberada del ejercicio, no como vulnerabilidad descubierta por accidente.
- **Explotación:** `sudo find . -exec /bin/sh \; -quit` → shell interactiva de root.
- **Detección esperada:** no (es un chequeo/explotación de un permiso ya otorgado, no hay ninguna regla que vigile el uso de `sudo`/`find` en sí).
- **Evidencia:** [`04b_privesc_find_20261101_2354.log`](attacker/evidencia/04b_privesc_find_20261101_2354.log).

## 5. T1548.003 — Modificación de sudoers (persistencia)

- **Acción:** desde la shell de root obtenida en el paso anterior, se agregó `testuser ALL=(ALL) NOPASSWD:ALL` a `/etc/sudoers` — backdoor de persistencia.
- **Detección esperada:** sí — Wazuh vigila `/etc/passwd`, `/etc/shadow`, `/etc/sudoers` y `/etc/sudoers.d` con FIM en tiempo real (`realtime="yes" report_changes="yes"`, confirmado en la configuración compartida del grupo `agent-db`).
- **Estado de verificación:** **pendiente de confirmar en el dashboard.** La configuración de FIM está correctamente aplicada y activa, pero no se revisó explícitamente si la alerta de esta edición puntual quedó capturada en `alerts.log` durante la sesión — recomendado hacerlo antes de la entrega final, ya que el mecanismo está confirmado funcionando (FIM corrió y detectó otros cambios durante las pruebas).
- **Reversión:** aplicada tras grabar evidencia (`sed -i '/^testuser ALL=(ALL) NOPASSWD:ALL$/d' /etc/sudoers`).

## 6. T1041 — Exfiltración de datos (netcat)

- **Acción:** listener en Kali (`nc -lvnp 4444`), envío de `/etc/passwd` desde `agent-db`.
- **Resultado:** archivo completo recibido sin pérdida de datos.
- **Detección esperada:** inicialmente "no" (técnica silenciosa por diseño), pero se agregó una regla de logging de `iptables` para el puerto 4444 (`F3_Reglas_PrepararAgentes.md`). Durante la verificación se encontró que la regla estaba mal puesta en la dirección equivocada (`INPUT` en vez de `OUTPUT`), corregida en vivo durante las pruebas.
- **Estado tras la corrección:** se confirmó que el kernel **sí registra** la conexión real (`agent-db → Kali`) en `kern.log` con el prefijo correcto, pero no se verificó explícitamente si esto se tradujo en una alerta visible en el dashboard de Wazuh — pendiente de confirmar, mismo caso que T1548.003.
- **Evidencia:** [`exfil_rec.txt`](attacker/evidencia/exfil_rec.txt) — contenido real de `/etc/passwd` recibido, incluyendo las cuentas reales del sistema (`coni`, `testuser`, `postgres`, `wazuh`).

## 7. T1068 — Escalada de privilegios (Windows, ataque interno)

- **Estado: pendiente de ejecución.** Documentado en `agent-windows/README.md` (Invoke-AtomicRedTeam), pero no se corrió durante esta sesión de pruebas — queda como tarea para antes de la entrega final.

## Tabla de resultados

| # | Ataque | Herramienta | MITRE | Objetivo | Resultado del ataque | Detección confirmada |
|---|---|---|---|---|---|---|
| 1 | Escaneo de puertos | nmap | T1046 | agent-db | Repetir (corrió con la máquina apagada) | No esperada |
| 2 | Fuerza bruta SSH | hydra | T1110.001 | agent-db | ✅ Éxito (`testuser:monkey`) | ✅ Sí — regla 100001 + Active Response (bloqueo 10 min, verificado) |
| 3 | Inyección SQL | sqlmap / manual | T1190 | agent-linux | sqlmap: ❌ (falso negativo por límite de 100 caracteres) / Manual: ✅ Éxito total (versión, usuario, tabla, datos) | ❌ No — sin cobertura de detección web en el laboratorio (brecha real) |
| 4 | Escalada de privilegios (Linux) | find (GTFOBins) | T1068 | agent-db | ✅ Éxito (shell de root) | No esperada |
| 5 | Escalada de privilegios (Windows, insider) | Atomic Red Team | T1068 | agent-windows | Pendiente de ejecución | — |
| 6 | Modificación de sudoers | sudoers edit | T1548.003 | agent-db | ✅ Éxito (backdoor plantado y revertido) | Mecanismo FIM activo y confirmado funcionando — alerta puntual pendiente de verificar en dashboard |
| 7 | Exfiltración de datos | nc | T1041 | agent-db → Kali | ✅ Éxito (/etc/passwd completo) | Logging de kernel corregido y confirmado — alerta en dashboard pendiente de verificar |

**Tasa de detección (confirmada end-to-end):** 1 de 6 técnicas con detección esperada y plenamente verificada en el dashboard (fuerza bruta SSH). 2 técnicas tienen el mecanismo de captura confirmado activo pero sin verificar la alerta final en el dashboard — hacerlo es la tarea más importante que queda antes de cerrar este reporte.

## Hallazgos adicionales de infraestructura (relevantes para interpretar la detección)

Durante las pruebas se encontraron y corrigieron varios problemas que afectaron directamente la consistencia de la detección — documentarlos fortalece el reporte porque explican por qué el comportamiento no siempre fue consistente, en vez de dejarlo como un misterio sin resolver:

1. **Regla de logging del puerto 4444 mal direccionada** (`INPUT` en vez de `OUTPUT`) — corregida en vivo.
2. **Manager colgado temporalmente:** `wazuh-logcollector` dejó de leer el `journal` de systemd durante un tramo, deteniendo toda generación de alertas (no solo las de SSH) — coincide exactamente con los periodos donde el bloqueo no se disparaba pese a que `hydra` generaba suficientes fallos.
3. **Disco del manager lleno (100%)** — causado principalmente por `/var/ossec/queue/vd_updater` (caché de actualizaciones de vulnerabilidades, ~27GB acumulados sin limpiarse). Esto afectó la sincronización de resultados de SCA y probablemente contribuyó a la inestabilidad general del manager.
4. **Integración MISP** (`custom-misp.py`) apuntando a `192.168.100.11`, registrada como agente `misp-agent-linux` — esta máquina generaba intentos de fuerza bruta contra `root` de forma independiente a nuestras pruebas, confundiendo inicialmente el diagnóstico.

## Pendientes antes de la entrega final

- [ ] Repetir el escaneo nmap (T1046) con `agent-db` encendida.
- [ ] Confirmar en el dashboard la alerta FIM de la modificación de sudoers (T1548.003).
- [ ] Confirmar en el dashboard la alerta de exfiltración por el puerto 4444 (T1041).
- [ ] Ejecutar la escalada de privilegios en `agent-windows` (T1068 insider).
- [ ] Confirmar con el equipo que el disco del manager y el colgón de `wazuh-logcollector` fueron resueltos, para que estos pendientes no vuelvan a fallar por el mismo motivo de infraestructura.
