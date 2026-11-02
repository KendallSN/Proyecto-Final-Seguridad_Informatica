# 1. Configuración de Active Response con bloqueo de IPs mediante iptables/firewallid
Dentro de `<ossec_config>`, en la sección `</ossec_config>` se configuró el active response para la regla 100001 pero se podria agregar para la 100004 y 100021:
 
```xml
  <!-- ========= ACTIVE RESPONSE ========= -->
  <active-response>
    <command>firewall-drop</command>
    <location>local</location>
    <rules_id>100001</rules_id>
    <timeout>600</timeout>
  </active-response>
 
  <!-- Opcional: también bloquear conexión al puerto 4444 y SQLi web -->
  <active-response>
    <command>firewall-drop</command>
    <location>local</location>
    <rules_id>100004,100021</rules_id>
    <timeout>600</timeout>
  </active-response>
```

```bash
hydra -l root -P /usr/share/wordlists/rockyou.txt -t 4 ssh://192.168.100.20
# o manual: repetir 7 veces
for i in $(seq 1 7); do ssh -o StrictHostKeyChecking=no root@192.168.100.20 'exit'; done   # con contraseña incorrecta
```
Esperado: alerta **100001** (nivel 10). Funciona igual contra `agent-db` (192.168.100.40).

**Probar**
 
1. **Terminal 1 — agente atacado** (linux-server o agent-db): ver respuesta en vivo
```bash
   tail -f /var/ossec/logs/active-responses.log
```
2. **Terminal 2 — Kali:** lanzar el ataque
```bash
   hydra -l root -P /usr/share/wordlists/rockyou.txt -t 4 ssh://agente-linux@192.168.100.20
```
```bash
   hydra -l root -P /usr/share/wordlists/rockyou.txt -t 4 ssh://coni@192.168.100.40
```
3. **Qué debes ver:**
   - En el agente: líneas `firewall-drop ... add ... <IP_KALI>`.
   - Comprobar el bloqueo en el agente:
```bash
     iptables -L INPUT -n --line-numbers | head
```
     Debe aparecer `DROP all -- <IP_KALI> 0.0.0.0/0`.
   - Desde Kali, el ataque se queda sin respuesta (timeouts).
   - A los 10 minutos: línea `... delete ...` en el log y la regla desaparece.
4. **Desbloquear antes de tiempo** (si necesitas repetir el ataque):
```bash
   iptables -L INPUT -n --line-numbers          # busca el número de la línea DROP
   iptables -D INPUT <número>
```
### Lo que se muestra en el video:
 
1. Mostrar el bloque `<active-response>` en `ossec.conf` y la regla 100001.
2. Ejecución el comando de ataque en Kali(hydra) + agente siendo atacado (`tail -f active-responses.log`) + Dashboard (Threat Hunting → Events, filtro `rule.id:100001`)
3. Lanzar el ataque. Mostrar la alerta 100001 y el log del Active Response.
4. Mostrar `iptables -L INPUT -n` con el DROP a `<IP_KALI>`.
5. Mostrar en Kali que ya no puede conectar (`ssh root@<IP_LINUX_SERVER>` se queda colgado).

# 2. Integrar la API de VirusTotal para análisis automático de hashes de archivos.
**Qué hace:** cuando FIM detecta un archivo nuevo o modificado, el manager envía su hash a VirusTotal. Si varios motores lo marcan como malicioso, se genera una alerta.
 
> La API gratuita permite **4 consultas/minuto y 500/día**. Si enviaras *todos* los eventos de FIM (`/etc`, `/usr/bin`...), la agotarías. Por eso solo analizamos `/var/www` (donde se suben webshells) con una regla propia.
 
## 2.1 Obtener la API key
1. Crea cuenta gratis en <https://www.virustotal.com>.
2. Crear perfil, acceder y copiae la clave.
## 2.2 Regla que marca qué eventos analizar (wazuh-server)
 
Agregar al final de `/var/ossec/etc/rules/local_rules.xml`:
 
```xml
<group name="local,syscheck,vt_scan,">
  <!-- Archivo creado (554) o modificado (550) en /var/www -> se envía a VirusTotal -->
  <rule id="100060" level="7">
    <if_sid>550,554</if_sid>
    <field name="file" type="pcre2">^/var/www/</field>
    <description>FIM: archivo creado/modificado en /var/www: $(file)</description>
    <mitre>
      <id>T1505.003</id>
    </mitre>
  </rule>
</group>
```
(T1505.003 = Web Shell, táctica Persistence.)
 
## 2.3 Integración en ossec.conf (wazuh-server)
 
```bash
nano /var/ossec/etc/ossec.conf
```
Dentro de `<ossec_config>`:
```xml
  <integration>
    <name>virustotal</name>
    <api_key>d582c9c4df7d4410f14894134531352c765d7a59506c467e1e1f42cb94f84853</api_key>
    <group>vt_scan</group>
    <alert_format>json</alert_format>
  </integration>
```
Aplicar:
```bash
/var/ossec/bin/wazuh-analysisd -t
systemctl restart wazuh-manager
```
(El manager necesita salida a Internet.)
 
## 2.3b Verificar que linux-server vigila `/var/www`
Verificar que `agent.conf` del grupo (Fase 3) tenga `realtime="yes"` para que el alerta sea inmediata.
 
## 2.4 Probar con el archivo de prueba EICAR (inofensivo, lo detectan todos los antivirus)

En **linux-server**:
```bash
sudo -i
echo "prueba1" > /var/www/html/fim_check_01.txt
sleep 15
rm /var/www/html/fim_check_01.txt
exit
```
En el Dashboard (Threat Hunting → Events), filtra:
```
rule.groups:virustotal
```
![alt text]({D759F738-EA7B-4435-80D1-A0EDE44E3EE5}.png)
Debes ver una alerta tipo **"VirusTotal: Alert - /var/www/html/eicar.com - N engines detected this file"** (regla integrada 87105, nivel 12) con los campos `data.virustotal.positives` y `data.virustotal.permalink`.
 
Si no aparece:
```bash
tail -n 30 /var/ossec/logs/integrations.log     # errores de la integración
grep -i virustotal /var/ossec/logs/ossec.log
```
Limpieza: `rm /var/www/html/eicar.com`
 
---
# 3. Configurar notificaciones por email (SMTP) o webhook de Slack para alertas nivel 10+
**1) Crear el webhook**
1. Creamos un espacio de trabajo de Slack gratuito y un canal `#notificaciones-wazuh`.
2. Ve a <https://api.slack.com/apps> → **Create New App** → *From scratch* → nombre `Wazuh-notificador` → elige tu workspace.
3. **Incoming Webhooks** → activar **On** → **Add New Webhook to Workspace** → elige el canal → **Allow**.
4. Copia la URL (`https://hooks.slack.com/services/XXX/YYY/ZZZ`).

**2) Probar el webhook antes de configurar Wazuh** (en wazuh-server):
```bash
curl -X POST -H 'Content-type: application/json' --data '{"text":"Hello, World!"}' https://hooks.slack.com/services/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
```
Debe responder `ok` y aparecer el mensaje en el canal.
 
**3) Configurar Wazuh** (`/var/ossec/etc/ossec.conf`, dentro de `<ossec_config>`):
```xml
  <integration>
    <name>slack</name>
    <hook_url>https://hooks.slack.com/services/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</hook_url>
    <level>10</level>
    <alert_format>json</alert_format>
  </integration>
```
```bash
/var/ossec/bin/wazuh-analysisd -t
systemctl restart wazuh-manager
```
**4) Probar:** dispara la regla 100002 en linux-server:
```bash
touch /etc/passwd
```
![alt text]({432028A2-4D3F-4868-8BBE-5E9A5608EBEF}.png)
(En 1-2 min llega el mensaje a Slack.) Si no llega: `tail /var/ossec/logs/integrations.log`.

# 4. Conectar Wazuh con MISP para enriquecimiento de IoCs (Indicators of Compromise)
## 4.1 Crear la VM en VirtualBox
1. Descarga la ISO de Ubuntu Server 24.04 LTS desde ubuntu.com.
2. En VirtualBox: Nueva, y usa estos valores:
    - Nombre: misp-server
    - RAM: 4096 MB (mejor 6144)
    - CPU: 2
    - Disco: 40 GB
3.  Antes de iniciarla, en Configuración → Red pon dos adaptadores:
    - Adaptador 1: NAT. Da Internet para descargar MISP.
    - Adaptador 2: el mismo tipo de red que usan tus otras VMs (la que ve el wazuh-server).
4.  Inicia con la ISO e instala Ubuntu:
    - Marca Install OpenSSH server.
    - Crea tu usuario con una contraseña que recuerdes.
    - Deja el resto por defecto.
5.  Al terminar, reinicia y entra con tu usuario(misp / misp).

## 4.2 Instalar MISP con el script oficial

```bash
sudo apt update && sudo apt -y upgrade
wget --no-cache -O /tmp/INSTALL.sh https://raw.githubusercontent.com/MISP/MISP/2.4/INSTALL/INSTALL.sh
bash /tmp/INSTALL.sh -c
```

admin@admin.test | VaHHdZB4CklWLE185RvgNDV46knCIiTkCba2aWqy

Probar la API desde wazuh-server:
```bash
curl -k -H "Authorization: scsjJmGe2M46sZZSBNEa4lbK4NsGKGtwOiXlNhFK" -H "Accept: application/json" \
  https://192.168.100.11/servers/getVersion
```

## 4.2.1 Configurar MISP
1. Event Actions → Add Event:
  - Distribution: All communities (o This community only). Con Your organisation only solo lo ve la organización del usuario, y la clave API puede ser de otra.
  - Threat Level: High.
  - Analysis: Completed.
  - Event Info: IoCs laboratorio Wazuh.
  - Submit.
2. Ya dentro del evento, en la pestaña principal pulsa Add Attribute (botón +):
  - Category: Network activity
  - Type: ip-src
  - Value: la IP real de Kali, por ejemplo 192.168.100.99, sin espacios ni texto extra.
  - Distribution: Inherit from event
  - Marca For Intrusion Detection System.
  - Submit.
3. Agrega otro atributo para el hash:
  - Category: Payload delivery
  - Type: md5
  - Value: 44d88612fea8a8f36de82e1278abb02f
4. Arriba, en el evento, pulsa Publish Event (o Publish (no email)) y confirma.

Script de integración (wazuh-server)
 
```bash
nano /var/ossec/integrations/custom-misp.py
```
Pega:
 
```python
#!/var/ossec/framework/python/bin/python3
# Integración Wazuh -> MISP (consulta IPs de origen y hashes de FIM)
import sys, json, socket, time
import requests
from requests.packages import urllib3
 
urllib3.disable_warnings()
SOCKET_ADDR = "/var/ossec/queue/sockets/queue"
LOG_FILE = "/var/ossec/logs/integrations.log"
 
 
def log(msg):
    with open(LOG_FILE, "a") as f:
        f.write("%s custom-misp: %s\n" % (time.strftime("%Y-%m-%d %H:%M:%S"), msg))
 
 
def send_event(msg, agent):
    if agent and agent.get("id") not in (None, "000"):
        s = "1:[%s] (%s) %s->misp:%s" % (
            agent["id"], agent.get("name", ""), agent.get("ip", "any"), json.dumps(msg))
    else:
        s = "1:misp:%s" % json.dumps(msg)
    sock = socket.socket(socket.AF_UNIX, socket.SOCK_DGRAM)
    sock.connect(SOCKET_ADDR)
    sock.send(s.encode())
    sock.close()
 
 
def query_misp(url, key, value):
    r = requests.post(
        url.rstrip("/") + "/attributes/restSearch",
        headers={"Authorization": key, "Accept": "application/json",
                 "Content-Type": "application/json"},
        json={"returnFormat": "json", "value": value, "limit": 1},
        verify=False, timeout=10)
    r.raise_for_status()
    return r.json().get("response", {}).get("Attribute", [])
 
 
def main():
    alert_file, api_key, hook_url = sys.argv[1], sys.argv[2], sys.argv[3]
    with open(alert_file) as f:
        alert = json.load(f)
 
    iocs = []
    srcip = alert.get("data", {}).get("srcip")
    if srcip:
        iocs.append(srcip)
    sc = alert.get("syscheck", {})
    for k in ("md5_after", "sha1_after", "sha256_after"):
        if sc.get(k):
            iocs.append(sc[k])
 
    for ioc in iocs:
        try:
            hits = query_misp(hook_url, api_key, ioc)
        except Exception as e:
            log("error consultando %s: %s" % (ioc, e))
            continue
        if hits:
            a = hits[0]
            msg = {
                "integration": "misp",
                "misp": {
                    "found": 1,
                    "value": ioc,
                    "type": a.get("type"),
                    "category": a.get("category"),
                    "event_id": a.get("event_id"),
                    "comment": a.get("comment", ""),
                    "source": {
                        "alert_id": alert.get("id"),
                        "rule_id": alert.get("rule", {}).get("id"),
                        "description": alert.get("rule", {}).get("description"),
                    },
                },
            }
            send_event(msg, alert.get("agent"))
            log("IoC %s encontrado en MISP (evento %s)" % (ioc, a.get("event_id")))
 
 
if __name__ == "__main__":
    main()
```
Permisos (obligatorios, si no Wazuh no lo ejecuta):
```bash
chmod 750 /var/ossec/integrations/custom-misp.py
chown root:wazuh /var/ossec/integrations/custom-misp.py
```
 
### A.4.4 Regla que genera la alerta de MISP (wazuh-server)
 
Agregar al final de `/var/ossec/etc/rules/local_rules.xml`:
```xml
<group name="local,misp,threat_intel,">
  <rule id="100050" level="12">
    <decoded_as>json</decoded_as>
    <field name="integration">^misp$</field>
    <description>MISP: IoC conocido encontrado: $(misp.value) ($(misp.type)) - evento MISP #$(misp.event_id)</description>
  </rule>
</group>
```
 
### A.4.5 Activar la integración (ossec.conf del manager)
```bash
sudo cp /var/ossec/etc/ossec.conf /var/ossec/etc/ossec.conf.bak
sudo nano /var/ossec/etc/ossec.conf
```
```xml
  <integration>
    <name>custom-misp.py</name>
    <hook_url>https://192.168.100.11</hook_url>
    <api_key>scsjJmGe2M46sZZSBNEa4lbK4NsGKGtwOiXlNhFK</api_key>
    <rule_id>100001,100004,100021,100022,100060</rule_id>
    <alert_format>json</alert_format>
  </integration>
```
(`name` debe empezar por `custom-`. `hook_url` = URL de MISP; `api_key` = clave de MISP.)
```bash
/var/ossec/bin/wazuh-analysisd -t
systemctl restart wazuh-manager
```
 
### A.4.6 Probar
 
**Prueba manual del script** (sin esperar un ataque), en wazuh-server:
```bash
cat > /tmp/alerta_prueba.json <<'EOF'
{"id":"1","rule":{"id":"100001","description":"prueba"},"agent":{"id":"000","name":"wazuh-server"},"data":{"srcip":"192.168.100.50"}}
EOF
sudo /var/ossec/integrations/custom-misp.py /tmp/alerta_prueba.json scsjJmGe2M46sZZSBNEa4lbK4NsGKGtwOiXlNhFK https://192.168.100.11/
sudo tail -n 5 /var/ossec/logs/integrations.log
```

Debe decir `IoC 192.168.100.50 encontrado en MISP`.
 ![alt text]({810D8129-C9D8-4CFB-9D23-FDAAC4510945}.png)
 ![alt text]({EB7249AF-6339-4F1D-8333-3E705B1CB612}.png)
**Prueba real:** ejecuta hydra desde Kali (regla 100001) o crea el archivo EICAR (regla 100060). En el Dashboard filtra `rule.id:100050`: verás la alerta de MISP.
 
# 5. Implementar al menos un playbook de respuesta a incidentes documentado

Revizar Playbook PB-01--ssh bruteforce