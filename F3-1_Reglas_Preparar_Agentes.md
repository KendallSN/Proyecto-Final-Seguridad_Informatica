## 1. Preparar los agentes (para que existan los logs)

### 1.1 `linux-server` (Ubuntu)

#### **a) Verificar que existe `/var/log/auth.log` (SSH y sudo) y `kern.log`**
```bash
ls -l /var/log/auth.log /var/log/kern.log
# Si no existen:
sudo apt update && sudo apt install -y rsyslog && sudo systemctl enable --now rsyslog
```

#### **b) Regla 4 (puerto 4444): registrar en el log las conexiones nuevas al puerto 4444**
```bash
sudo iptables -I INPUT 1 -p tcp --dport 4444 -m conntrack --ctstate NEW \
  -j LOG --log-prefix "WAZUH_4444_IN: " --log-level 4
# (Opcional) reverse shell saliente típico de Metasploit:
sudo iptables -I OUTPUT 1 -p tcp --dport 4444 -m conntrack --ctstate NEW \
  -j LOG --log-prefix "WAZUH_4444_OUT: " --log-level 4
# Hacerlo persistente tras reinicio:
sudo apt install -y iptables-persistent && sudo netfilter-persistent save
```
*Qué hace:* el kernel escribe una línea en `/var/log/kern.log` cada vez que alguien intenta conectarse al 4444, aunque no haya nada escuchando.

#### **c) Formato de log de Apache con etiqueta propia (para el decoder personalizado)**
##### **Paso 1. Crear el archivo con el formato de log**

Crear `/etc/apache2/conf-available/wazuh-log.conf`:
Este archivo define un formato de log llamado wazuh que empieza con la etiqueta WZ-APACHE.
```bash
sudo nano /etc/apache2/conf-available/wazuh-log.conf
```
Se abre un archivo vacío. Pega esta única línea:
```apache
LogFormat "WZ-APACHE %h %l %u %t \"%r\" %>s %b \"%{Referer}i\" \"%{User-Agent}i\"" wazuh
```
Para guardar y salir de nano: Ctrl+O, Enter, Ctrl+X.

comando para realizar todo desde la terminal:
```bash
sudo tee /etc/apache2/conf-available/wazuh-log.conf > /dev/null <<'EOF'
LogFormat "WZ-APACHE %h %l %u %t \"%r\" %>s %b \"%{Referer}i\" \"%{User-Agent}i\"" wazuh
EOF
```
Comprueba que quedó bien:
```bash
cat /etc/apache2/conf-available/wazuh-log.conf
```

##### Paso 2. Activar ese archivo en Apache
```bash
sudo a2enconf wazuh-log
```
Debe responder Enabling conf wazuh-log. Esto solo crea un enlace en conf-enabled/. Todavía no se escribe ningún log.

##### Paso 3. Decirle al VirtualHost que use el formato

Abre el archivo de tu sitio. Si usas el sitio por defecto:

```bash
sudo nano /etc/apache2/sites-available/000-default.conf
```
Dentro verás algo parecido a esto:
```apache
  <VirtualHost *:80>
      ServerAdmin webmaster@localhost
      DocumentRoot /var/www/html

      ErrorLog ${APACHE_LOG_DIR}/error.log
      CustomLog ${APACHE_LOG_DIR}/access.log combined
  </VirtualHost>
```
Debajo de la línea CustomLog ... combined agrega una línea nueva, sin borrar la existente:
```apache
    ErrorLog ${APACHE_LOG_DIR}/error.log
      CustomLog ${APACHE_LOG_DIR}/access.log combined
      CustomLog ${APACHE_LOG_DIR}/wazuh_access.log wazuh
  </VirtualHost>
```
Guarda y sal con Ctrl+O, Enter, Ctrl+X.

##### Paso 4. Validar y recargar Apache

```bash
sudo apache2ctl configtest
```
Debe responder Syntax OK. Si da error, revisa que la línea esté dentro de <VirtualHost>...</VirtualHost> y que wazuh esté escrito igual en el LogFormat y en el CustomLog. Si dice Syntax OK:

```bash
sudo systemctl reload apache2
```

##### Paso 5. Comprobar que se escribe el log
Genera una petición:
```bash
curl -s http://localhost/ > /dev/null
```
Mira el archivo:
```bash
sudo tail -n 3 /var/log/apache2/wazuh_access.log
```
Debes ver algo así:
WZ-APACHE 127.0.0.1 - - [31/Oct/2026:10:00:00 -0600] "GET / HTTP/1.1" 200 3380 "-" "curl/7.81.0"
Si la línea empieza con WZ-APACHE, esta parte está lista.

### 1.2 Preparar `agent-db` (Debian 13)

> Debes estar como **root**. Si entraste con un usuario normal, ejecuta primero:
> ```bash
> su -
> ```
> y escribe la contraseña de root. El prompt debe terminar en `#`.

---

## a) Instalar rsyslog (para tener `auth.log` y `kern.log`)

**Qué hace:** Debian 13 guarda los logs solo en el journal del sistema. Wazuh necesita archivos de texto como `/var/log/auth.log` (SSH y sudo, reglas 1 y 3) y `/var/log/kern.log` (regla 4). `rsyslog` los crea.

**Paso 1. Instalar:**
```bash
apt update
apt install -y rsyslog iptables
```

**Paso 2. Activarlo y arrancarlo:**
```bash
systemctl enable --now rsyslog
```

**Paso 3. Comprobar que existen los archivos:**
```bash
ls -l /var/log/auth.log /var/log/kern.log
```
Deben aparecer los dos. Si falta alguno, espera unos segundos o reinicia el servicio:
```bash
systemctl restart rsyslog
```

**Paso 4. Probar que `auth.log` registra SSH.** Desde otra máquina (por ejemplo Kali) intenta conectarte con una contraseña mala:
```bash
ssh usuario_falso@192.168.100.40
```
En `agent-db`, mira:
```bash
tail -n 5 /var/log/auth.log
```
Debes ver líneas con `sshd[...]: Failed password ...` o `Invalid user ...`.

---

## b) Configurar el log de PostgreSQL

**Qué hace:**
- `log_line_prefix` pone al inicio de cada línea la etiqueta `WZ-PG`, que es la que reconoce tu decoder. También registra la hora, el usuario, la base de datos y la **IP de origen** (`%h`), necesaria para la regla de fuerza bruta.
- `log_connections` y `log_disconnections` registran quién entra y sale.
- `log_statement = 'ddl'` registra sentencias como `CREATE`, `DROP` y `ALTER`.

**Paso 1. Aplicar la configuración** (copia y pega el bloque completo):
```bash
su - postgres -c psql <<'EOF'
ALTER SYSTEM SET log_line_prefix = 'WZ-PG %m [%p] %q%u@%d %h ';
ALTER SYSTEM SET log_connections = on;
ALTER SYSTEM SET log_disconnections = on;
ALTER SYSTEM SET log_statement = 'ddl';
SELECT pg_reload_conf();
EOF
```
Debe responder `ALTER SYSTEM` cuatro veces y luego `t` (true) en `pg_reload_conf`. `ALTER SYSTEM` guarda los cambios en `postgresql.auto.conf`, así que **no tienes que editar `postgresql.conf` a mano**.

**Paso 2. Comprobar que quedó aplicado:**
```bash
su - postgres -c "psql -c 'SHOW log_line_prefix;'"
```
Debe mostrar `WZ-PG %m [%p] %q%u@%d %h `.

**Paso 3. Encontrar el nombre del archivo de log:**
```bash
ls /var/log/postgresql/
```
En Debian 13 suele ser `postgresql-15-main.log`. **Anota el nombre exacto.** Lo necesitas en el `agent.conf` del grupo `agent-db`, en la línea `<location>`.

**Paso 4. Generar una línea de prueba:**
```bash
PGPASSWORD=mala psql -h 127.0.0.1 -U postgres -c '\q'
tail -n 5 /var/log/postgresql/postgresql-15-main.log
```
Cambia el nombre del archivo si el tuyo es distinto. Debes ver algo así:
```
WZ-PG 2026-10-31 10:00:00.123 CST [4321] postgres@postgres 127.0.0.1 FATAL:  password authentication failed for user "postgres"
```
Si la línea empieza con `WZ-PG`, esta parte está lista.

| Problema | Solución |
|---|---|
| `psql: command not found` | `apt install -y postgresql-client` |
| Las líneas no empiezan con `WZ-PG` | Repite el Paso 1 y comprueba con el Paso 2 |
| No aparece ninguna línea de fallo | Puede que PostgreSQL use `trust` en `pg_hba.conf` para 127.0.0.1 y no pida contraseña. Prueba desde otra máquina con `-h 192.168.100.40` o con un usuario inexistente |
| `could not connect` | Revisa que PostgreSQL esté activo: `systemctl status postgresql` |

---

## c) (Opcional) Regla 4: log del puerto 4444 también en agent-db

**Qué hace:** pide al kernel que escriba una línea en `/var/log/kern.log` cada vez que alguien intenta conectarse al puerto 4444. Wazuh la lee y dispara la regla 100004.

**Paso 1. Agregar la regla de log:**
```bash
iptables -I INPUT 1 -p tcp --dport 4444 -m conntrack --ctstate NEW \
  -j LOG --log-prefix "WAZUH_4444_IN: " --log-level 4
```
No muestra salida si salió bien.

**Paso 2. (Opcional) El mismo log para conexiones salientes** al 4444, típico de un reverse shell desde la víctima:
```bash
iptables -I OUTPUT 1 -p tcp --dport 4444 -m conntrack --ctstate NEW \
  -j LOG --log-prefix "WAZUH_4444_OUT: " --log-level 4
```

**Paso 3. Comprobar que quedaron:**
```bash
iptables -L INPUT -n --line-numbers | head
```
Debes ver una línea `LOG ... tcp dpt:4444 ... prefix "WAZUH_4444_IN: "`.

**Paso 4. Hacerlo persistente.** Sin esto, las reglas se pierden al reiniciar:
```bash
apt install -y iptables-persistent
netfilter-persistent save
```
Si el instalador pregunta si guardar las reglas actuales, responde **Sí**.

**Paso 5. Probar.** Desde Kali:
```bash
nc -nv 192.168.100.40 4444
```
En `agent-db`:
```bash
grep WAZUH_4444 /var/log/kern.log | tail
```
Debe aparecer una línea con `WAZUH_4444_IN: ... SRC=192.168.100.50 ... DPT=4444`. Aunque la conexión sea rechazada, el intento queda registrado.

---
### 1.3 `agent-windows`

PowerShell como Administrador (si es Domain Controller ya viene activo, pero verifica):
```powershell
auditpol /set /subcategory:"User Account Management" /success:enable /failure:enable
auditpol /get /subcategory:"User Account Management"
```
*Qué hace:* hace que Windows genere el evento **4720** (cuenta creada). El agente Wazuh ya recolecta el canal `Security` por defecto.
