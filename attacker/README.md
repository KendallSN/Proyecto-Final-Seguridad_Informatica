# Frente E — Attacker (Kali)

Scripts y notas para la Fase 5 del proyecto (simulación de ataques contra `agent-linux` y `agent-db`, validación en Wazuh). Responsable: Angelo.

**Dos objetivos, no uno:** la app web (Apache + PHP) vive en `agent-linux`; SSH y PostgreSQL viven en `agent-db` (ver tabla de máquinas del enunciado). El ataque de inyección SQL (sqlmap) apunta a `agent-linux`; todo lo demás (escaneo, fuerza bruta SSH, escalada de privilegios, modificación de sudoers, exfiltración) apunta a `agent-db`.

## Estructura

```
attacker/
├── config.sh                  # Variable central: TARGET_WEB (agent-linux), TARGET_SSH (agent-db), usuario SSH, IP de Kali
├── scripts/
│   ├── 01_portscan.sh          # T1046 — nmap contra agent-db, desde Kali
│   ├── 02_bruteforce_ssh.sh    # T1110.001 — hydra contra agent-db, desde Kali
│   ├── 03_sqlmap.sh            # T1190 — sqlmap contra agent-linux, desde Kali
│   ├── 03b_sqli_manual.sh       # T1190 — explotación manual (sqlmap falla por el límite de 100 caracteres de la app)
│   ├── 04_privesc_checks.sh    # T1068 — correr DENTRO de agent-db, tras SSH
│   ├── 05_sudoers_mod.sh       # T1548.003 — correr DENTRO de agent-db
│   └── 06_exfiltracion.sh      # T1041 — nc, Kali escucha / agent-db envía
├── wordlists/
│   ├── small_list.txt          # Wordlist corta para hydra (uso por defecto; rockyou.txt completo tarda horas)
│   └── rockyou_1000.txt        # Primeras 1000 líneas de rockyou.txt (ver sección rockyou.txt)
├── practica/
│   └── ssh-target/Dockerfile   # Contenedor Docker desechable para probar hydra sin tocar el laboratorio real
└── evidencia/                  # Salida de cada script (logs con tee), vacío hasta correr algo
```

## Antes de correr nada

1. **Unirse a la red del equipo (ZeroTier):**
   
   ```bash
   curl -s https://install.zerotier.com | sudo bash
   sudo zerotier-cli join <invite link>
   ```
   
   Pedir a quien administra la red que autorice el nodo en `my.zerotier.com → Members`.
   
   **Importante:** la red puede empujar un DNS inválido vía NetworkManager y romper la resolución de nombres (incluido `apt`). Si pasa, fijar DNS manual:
   
   ```bash
   sudo nmcli connection modify "Wired connection 1" ipv4.ignore-auto-dns yes
   sudo nmcli connection modify "Wired connection 1" ipv4.dns "1.1.1.1 8.8.8.8"
   sudo nmcli connection up "Wired connection 1"
   ```

2. **Confirmar con el equipo, antes de grabar evidencia real:**
   
   - IP real de `agent-linux` y `agent-db` por ZeroTier (van en `config.sh`). Con la IP sugerida del enunciado: `agent-linux` = `192.168.100.20`, `agent-db` = `192.168.100.40`.
   - Qué usuario es el objetivo legítimo de la fuerza bruta SSH en `agent-db` (`config.sh → SSH_USER`): debe ser una cuenta de prueba de bajo privilegio creada específicamente para el laboratorio, **no** la cuenta administrativa del sistema. Si no existe, pedirle a quien administra `agent-db` que la cree (usuario + contraseña débil a propósito + acceso sudo, para que la cadena completa — fuerza bruta → escalada → modificación de sudoers — tenga algo real que mostrar).
   - Que `agent-db` esté encendida: es el objetivo de 4 de los 6 ataques (todo salvo sqlmap), así que sin ella la mayoría del frente no se puede ensayar contra el laboratorio real.

   El parámetro real de `consultas.php` para la inyección SQL ya está confirmado: `busqueda`, método `POST`, sin cookie de sesión. La app depende de su propia conexión a `agent-db`, así que sqlmap solo puede enumerar datos reales cuando esa máquina esté arriba.

3. Editar `config.sh` con las IP reales:
   
   ```bash
   TARGET_WEB="192.168.100.20"   # agent-linux
   TARGET_SSH="192.168.100.40"   # agent-db
   SSH_USER="<usuario de prueba confirmado en agent-db>"
   ```

## Orden de ejecución

| #   | Script                 | Objetivo   | Dónde corre                                                                  | Depende de                                        |
| --- | ---------------------- | ---------- | ----------------------------------------------------------------------------- | ------------------------------------------------- |
| 1   | `01_portscan.sh`       | agent-db   | Kali                                                                           | Solo IP                                           |
| 2   | `02_bruteforce_ssh.sh` | agent-db   | Kali                                                                           | IP + usuario correcto                             |
| 3   | `03_sqlmap.sh`         | agent-linux| Kali                                                                           | IP + `agent-db` arriba (la app depende de esa conexión) |
| 3b  | `03b_sqli_manual.sh`   | agent-linux| Kali                                                                           | Igual que el 3 — payloads cortos a mano, ya que sqlmap falla por el límite de 100 caracteres de `$busqueda` |
| 4   | `04_privesc_checks.sh` | agent-db   | Dentro de agent-db (`ssh usuario@TARGET_SSH 'bash -s' < 04_privesc_checks.sh`) | Acceso SSH del paso 2                             |
| 5   | `05_sudoers_mod.sh`    | agent-db   | Dentro de agent-db                                                             | Privilegio obtenido en el paso 4                  |
| 6   | `06_exfiltracion.sh`   | agent-db   | Kali escucha, agent-db envía                                                   | Acceso a agent-db                                 |

Cada script de Kali guarda su salida en `evidencia/` con `tee` y marca de tiempo.

**Después del script 5**, revertir el cambio en sudoers una vez grabada la evidencia:

```bash
sudo sed -i '/^<usuario> ALL=(ALL) NOPASSWD:ALL$/d' /etc/sudoers
```

### Escalada de privilegios en Windows (ataque interno)

Además del enfoque Linux (script 4), se demuestra T1068 también en `agent-windows`, como ataque interno (insider): ejecutado directamente en esa máquina — por SSH si hay acceso remoto, o localmente si no — usando los módulos de Atomic Red Team para Windows. Se documentan ambos enfoques como demostración complementaria en el reporte de Fase 5.

## rockyou.txt

El enunciado menciona `rockyou.txt` para la fuerza bruta SSH. Viene incluido con Kali Linux, comprimido en `/usr/share/wordlists/rockyou.txt.gz` 

```bash
sudo gunzip -k /usr/share/wordlists/rockyou.txt.gz
```

Queda disponible en `/usr/share/wordlists/rockyou.txt` (~14.3 millones de líneas, ~133 MB) y también en la VM en `~/proyecto-si/wordlists/rockyou_1000.txt`. Tarda horas y genera un volumen de tráfico/alertas innecesario; sirve para el comando de referencia del enunciado o para una prueba acotada: `wordlists/rockyou_1000.txt` (las primeras 1000 líneas, ya incluido en este repo). Para la demostración real no es factible usar la lista completa

Referencia: [SkullSecurity — rockyou.txt](https://wiki.skullsecurity.org/index.php/Passwords) (origen y contexto de la filtración de la que proviene la lista).

## Entorno de práctica (mientras no esté listo el laboratorio real)

`practica/ssh-target/Dockerfile` levanta un contenedor desechable con SSH y un usuario de prueba (`testuser` / `letmein`, coincide con `wordlists/small_list.txt`) para probar `02_bruteforce_ssh.sh` sin tocar `agent-db`:

```bash
cd practica/ssh-target
sudo docker build -t practice-ssh .
sudo docker run -d --name practice-ssh -p 2200:22 practice-ssh
```

Para practicar la inyección SQL (script 3) sin la base de datos real, usar DVWA:

```bash
sudo docker pull vulnerables/web-dvwa
sudo docker run -d --name practice-dvwa -p 8080:80 vulnerables/web-dvwa
```

Login `admin` / `password`, nivel de seguridad "low", módulo SQL Injection — sirve para validar la sintaxis de `sqlmap` antes de correrlo contra el objetivo real.

## Tabla de resultados (llenar tras correr contra el laboratorio real)

| Ataque                                     | Herramienta     | MITRE     | Objetivo      | Alerta Wazuh (ID / nivel) | Detectado                        |
| ------------------------------------------ | --------------- | --------- | ------------- | ------------------------- | -------------------------------- |
| Escaneo de puertos                         | nmap            | T1046     | agent-db      | —                         | No (esperado)                    |
| Fuerza bruta SSH                           | hydra           | T1110.001 | agent-db      | 100100 / nivel 10         |                                  |
| Inyección SQL                              | sqlmap          | T1190     | agent-linux   |                           |                                  |
| Escalada de privilegios (Linux)            | manual          | T1068     | agent-db      | —                         | Depende de la cuenta de prueba (ver nota) |
| Escalada de privilegios (Windows, insider) | Atomic Red Team | T1068     | agent-windows |                           |                                  |
| Modificación de sudoers                    | echo / sudo     | T1548.003 | agent-db      | FIM /etc/sudoers          |                                  |
| Exfiltración de datos                      | nc              | T1041     | agent-db      | 100004 (kernel/iptables puerto 4444, ver `F3_Reglas_PrepararAgentes.md`) |                                  |

Tasa de detección = alertas que coincidieron correctamente ÷ total de ataques ejecutados.

**Nota sobre la fila de escalada de privilegios (Linux):** si la cuenta de prueba en `agent-db` se creó con acceso sudo a propósito (ver sección "Antes de correr nada"), `sudo -l` va a mostrar ese acceso como hallazgo real, no como "sin privilegios visibles" — documentarlo como una cuenta de demostración preparada para el ejercicio, no como una vulnerabilidad descubierta por accidente.
