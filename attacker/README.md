# Frente E — Attacker (Kali)

Scripts y notas para la Fase 5 del proyecto (simulación de ataques contra `agent-linux`, validación en Wazuh). Responsable: Angelo.

## Estructura

```
attacker/
├── config.sh                  # Variable central: IP objetivo, usuario SSH, IP de Kali
├── scripts/
│   ├── 01_portscan.sh          # T1046 — nmap, desde Kali
│   ├── 02_bruteforce_ssh.sh    # T1110.001 — hydra, desde Kali
│   ├── 03_sqlmap.sh            # T1190 — sqlmap, desde Kali
│   ├── 04_privesc_checks.sh    # T1068 — correr DENTRO de agent-linux, tras SSH
│   ├── 05_sudoers_mod.sh       # T1548.003 — correr DENTRO de agent-linux
│   └── 06_exfiltracion.sh      # T1041 — nc, Kali escucha / agent-linux envía
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
   
   - IP real de `agent-linux` por ZeroTier (va en `config.sh`).
   - Qué usuario es el objetivo legítimo de la fuerza bruta SSH (`config.sh → SSH_USER`): debe ser una cuenta de prueba de bajo privilegio, **no** la cuenta administrativa del sistema.
   - El parámetro real de `consultas.php` para la inyección SQL. Revisar el formulario real (vista de código fuente o pestaña Red del navegador) antes de correr `sqlmap`: puede ser otro nombre de parámetro, ir por POST, o requerir cookie de sesión si hay login.

3. Editar `config.sh` con la IP real:
   
   ```bash
   TARGET_IP="<IP real de agent-linux>"
   SSH_USER="<usuario de prueba confirmado>"
   ```

## Orden de ejecución

| #   | Script                 | Dónde corre                                                               | Depende de                                        |
| --- | ---------------------- | ------------------------------------------------------------------------- | ------------------------------------------------- |
| 1   | `01_portscan.sh`       | Kali                                                                      | Solo IP                                           |
| 2   | `02_bruteforce_ssh.sh` | Kali                                                                      | IP + usuario correcto                             |
| 3   | `03_sqlmap.sh`         | Kali                                                                      | IP + parámetro real de `consultas.php` confirmado |
| 4   | `04_privesc_checks.sh` | Dentro de agent-linux (`ssh usuario@IP 'bash -s' < 04_privesc_checks.sh`) | Acceso SSH del paso 2                             |
| 5   | `05_sudoers_mod.sh`    | Dentro de agent-linux                                                     | Privilegio obtenido en el paso 4                  |
| 6   | `06_exfiltracion.sh`   | Kali escucha, agent-linux envía                                           | Acceso a agent-linux                              |

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

`practica/ssh-target/Dockerfile` levanta un contenedor desechable con SSH y un usuario de prueba (`testuser` / `letmein`, coincide con `wordlists/small_list.txt`) para probar `02_bruteforce_ssh.sh` sin tocar `agent-linux`:

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

| Ataque                                     | Herramienta     | MITRE     | Alerta Wazuh (ID / nivel) | Detectado                        |
| ------------------------------------------ | --------------- | --------- | ------------------------- | -------------------------------- |
| Escaneo de puertos                         | nmap            | T1046     | —                         | No (esperado)                    |
| Fuerza bruta SSH                           | hydra           | T1110.001 | 100100 / nivel 10         |                                  |
| Inyección SQL                              | sqlmap          | T1190     |                           |                                  |
| Escalada de privilegios (Linux)            | manual          | T1068     | —                         | No (esperado)                    |
| Escalada de privilegios (Windows, insider) | Atomic Red Team | T1068     |                           |                                  |
| Modificación de sudoers                    | echo / sudo     | T1548.003 | FIM /etc/sudoers          |                                  |
| Exfiltración de datos                      | nc              | T1041     | —                         | No (esperado, salvo regla extra) |

Tasa de detección = alertas que coincidieron correctamente ÷ total de ataques ejecutados.
