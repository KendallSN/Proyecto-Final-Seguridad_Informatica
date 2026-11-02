
Se edita el `agent.conf` del grupo **en el manager**; los agentes lo reciben solos (tarda 1-2 min y se reinician solos). Este bloque **reemplaza** el `<syscheck>` básico que ya tengas en ese archivo.

Para validar sintaxis antes de dejarlo:
```bash
sudo /var/ossec/bin/verify-agent-conf -f /var/ossec/etc/shared/<grupo>/agent.conf
```

### Grupo `linux`

```bash
sudo nano /var/ossec/etc/shared/linux/agent.conf
```
```xml
<agent_config os="Linux">

  <!-- FIM: /etc /bin /usr/bin /var/www -->
  <syscheck>
    <disabled>no</disabled>
    <frequency>300</frequency>
    <scan_on_start>yes</scan_on_start>

    <directories check_all="yes" realtime="yes">/etc,/bin,/usr/bin</directories>
    <!-- report_changes: muestra QUÉ líneas cambiaron en archivos web -->
    <directories check_all="yes" realtime="yes" report_changes="yes">/var/www</directories>

    <ignore>/etc/mtab</ignore>
    <ignore>/etc/resolv.conf</ignore>
    <ignore>/etc/adjtime</ignore>
    <ignore type="sregex">.swp$</ignore>
  </syscheck>

  <!-- Logs que las reglas necesitan -->
  <localfile>
    <log_format>syslog</log_format>
    <location>/var/log/auth.log</location>          <!-- Reglas 1 y 3 -->
  </localfile>
  <localfile>
    <log_format>syslog</log_format>
    <location>/var/log/kern.log</location>          <!-- Regla 4 -->
  </localfile>
  <localfile>
    <log_format>syslog</log_format>
    <location>/var/log/apache2/wazuh_access.log</location>   <!-- Decoder Apache -->
  </localfile>
  <localfile>
    <log_format>apache</log_format>
    <location>/var/log/apache2/error.log</location>
  </localfile>

</agent_config>
```
*Qué hace:* `realtime="yes"` alerta en segundos (necesario para la demo); `check_all="yes"` compara hash, permisos, dueño y fecha. `/bin` es un enlace simbólico a `/usr/bin` en Ubuntu 22.04: se deja listado porque lo pide el enunciado, no pasa nada por duplicarlo.

### Grupo `db`

```bash
sudo nano /var/ossec/etc/shared/db/agent.conf
```
```xml
<agent_config>
  <syscheck>
    <disabled>no</disabled>
    <frequency>300</frequency>
    <scan_on_start>yes</scan_on_start>
    <directories check_all="yes" realtime="yes" report_changes="yes">/etc/passwd,/etc/shadow,/etc/sudoers,/etc/sudoers.d</directories>
    <directories check_all="yes" realtime="yes">/etc/postgresql</directories>
    
    <ignore>/etc/mtab</ignore>
    <ignore>/etc/resolv.conf</ignore>
    <ignore>/etc/adjtime</ignore>
    <ignore type="sregex">.swp$</ignore>
  </syscheck>
  <localfile><log_format>syslog</log_format><location>/var/log/postgresql/postgresql-15-main.log</location></localfile>
  <localfile><log_format>syslog</log_format><location>/var/log/auth.log</location></localfile>
  <localfile>
    <log_format>syslog</log_format>
    <location>/var/log/auth.log</location>          <!-- SSH / sudo -->
  </localfile>
  <localfile>
    <log_format>syslog</log_format>
    <location>/var/log/kern.log</location>          <!-- Regla 4 (opcional) -->
  </localfile>
  <localfile>
    <log_format>syslog</log_format>
    <location>/var/log/postgresql/postgresql-15-main.log</location>  <!-- ajusta el nombre -->
  </localfile>
</agent_config>
```

### Grupo `windows`

```bash
sudo nano /var/ossec/etc/shared/windows/agent.conf
```
```xml
<agent_config>
  <syscheck>
    <disabled>no</disabled>
    <frequency>43200</frequency>
    <directories check_all="yes" realtime="yes">C:\Windows\System32</directories>
    <!-- Carpetas que cambian constantemente (evitan ruido) -->
    <ignore>C:\Windows\System32\LogFiles</ignore>
    <ignore>C:\Windows\System32\winevt</ignore>
    <ignore>C:\Windows\System32\config</ignore>
    <ignore>C:\Windows\System32\spool</ignore>
    <ignore type="sregex">.log$|.etl$|.tmp$</ignore>
  </syscheck>
  <localfile><location>Security</location><log_format>eventchannel</log_format></localfile>
  <localfile><location>System</location><log_format>eventchannel</log_format></localfile>
  <localfile><location>Application</location><log_format>eventchannel</log_format></localfile>
</agent_config>
```
El canal `Security` (evento 4720 de la regla 5) ya se recolecta con el `ossec.conf` por defecto del agente Windows, no lo dupliques aquí.