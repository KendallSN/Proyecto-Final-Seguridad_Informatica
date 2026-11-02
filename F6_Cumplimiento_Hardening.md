# Fase 6 — Cumplimiento Normativo y Hardening

Basado en las exportaciones reales de SCA (`Configuration-Assestments/checks_*.csv`) corridas contra las tres máquinas Linux/Windows del laboratorio. Responsable de este borrador: Angelo (frente Attacker), a partir de los datos exportados por el equipo.

## 18. Módulo de compliance (PCI DSS, GDPR/HIPAA, NIST 800-53)

El módulo de compliance de Wazuh **no es un módulo aparte que se "habilita" por separado** — viene integrado directamente en cada chequeo del SCA. Cada control de CIS que se evalúa ya trae mapeado a qué marcos normativos corresponde (PCI DSS 3.2.1/4.0, HIPAA, ISO 27001, NIST SP 800-53, CMMC, SOC 2). Esto se confirma en los CSV exportados: cada fila tiene una columna `Compliance` con esos mapeos.

**Dónde verlo en el dashboard:** al entrar a la vista de SCA de un agente, cada chequeo individual se puede expandir y muestra sus referencias de cumplimiento. También existe una vista agregada de "Regulatory Compliance" en el menú del agente que resume cuántos controles PCI DSS/HIPAA/NIST están cumplidos vs. fallidos — si no aparece, confirmar que el agente tenga el módulo de compliance habilitado en el dashboard (separado del SCA, revisar configuración de la app de Wazuh).

**GDPR:** Wazuh no tiene un "GDPR check" nativo como con PCI DSS — su cumplimiento se infiere combinando SCA (protección de datos) + FIM (integridad de archivos con datos personales, como `Cliente`) + control de acceso (SSH, sudoers). No hay una pantalla dedicada a exportar.

## 19. Resultados del escaneo SCA — resumen ejecutivo

| Máquina | Política usada | Total de controles | Cumplidos | Fallidos | % de cumplimiento |
|---|---|---|---|---|---|
| `agent-linux` | CIS Debian 11 Benchmark | 182 | 70 | 110 | 38% |
| `agent-db` | CIS Debian 11 Benchmark | 198 | 73 | 103 | 37% |
| `agent-windows` | CIS Microsoft Windows Benchmark | 359 | 141 | 218 | 39% |

**Nota de contexto:** las máquinas Linux corren Debian 13 (trixie), no Debian 11 — la política CIS Debian 11 se adaptó manualmente para que el escaneo pudiera correr (ver `F3-5_Reglas_Pruebas_WazuhServer_Kali.md` / notas de configuración), ya que no existe un benchmark CIS oficial para Debian 13 todavía. Esto significa que algunos controles específicos pueden no reflejar con exactitud el estado real de un sistema Debian 13, pero la mayoría de los controles de endurecimiento (SSH, particiones, bootloader, AppArmor) son prácticas que no cambian entre versiones.

## 20. Hallazgos documentados con plan de remediación

### `agent-linux` y `agent-db` (comparten política — hallazgos muy similares)

| # | CIS ID | Hallazgo | Por qué importa | Remediación |
|---|---|---|---|---|
| 1 | 5.1 (SSH) | Permisos de `/etc/ssh/sshd_config` no restringidos | El archivo de configuración SSH debería ser ilegible para usuarios normales | `chown root:root /etc/ssh/sshd_config && chmod og-rwx /etc/ssh/sshd_config` |
| 2 | 5.1 (SSH) | Acceso SSH no está limitado a usuarios específicos | Cualquier cuenta del sistema puede intentar login SSH — esto es exactamente lo que explotamos con `hydra` en T1110.001 | Agregar `AllowUsers <usuarios_autorizados>` en `sshd_config` |
| 3 | 5.1 (SSH) | `PermitRootLogin` no está en `no` | Permite login directo como root por SSH, el objetivo más valioso para un atacante | `PermitRootLogin no` en `sshd_config` |
| 4 | 5.1 (SSH) | `MaxAuthTries` no limitado a 4 o menos | Sin límite, un atacante puede probar muchas contraseñas en una sola conexión | `MaxAuthTries 4` |
| 5 | 5.1 (SSH) | `MaxStartups` no configurado | Permite demasiadas conexiones SSH sin autenticar en paralelo — relacionado directamente con el comportamiento de `hydra` que documentamos (conexiones rechazadas al superar el límite por defecto) | `MaxStartups 10:30:60` |
| 6 | 5.1 (SSH) | Sin bloqueo de X11 forwarding / TCP forwarding | Superficie de ataque extra si se compromete la cuenta | `X11Forwarding no`, `AllowTcpForwarding no` |
| 7 | 1.4.1 | Sin contraseña en el bootloader (GRUB) | Acceso físico/consola permitiría editar el arranque y saltarse autenticación | `grub-mkpasswd-pbkdf2` + configurar en `/etc/grub.d/40_custom` |
| 8 | 1.6.1.1/1.6.1.4 | AppArmor no instalado / perfiles no en modo "enforcing" | Sin confinamiento de procesos, un proceso comprometido (como el `consultas.php` vulnerable) tiene acceso sin restricciones extra al sistema | `apt install apparmor apparmor-utils` + `aa-enforce /etc/apparmor.d/*` |
| 9 | 1.1.5/1.1.6 | `/var/log` y `/var/log/audit` no son particiones separadas con `nodev,nosuid,noexec` | Si un atacante llena el disco de logs, puede tumbar el sistema (justo lo que vimos pasar con el manager de Wazuh esta semana) | Requiere repartición — documentar como hallazgo para una futura instalación, no aplicable en caliente sin downtime |

### `agent-windows`

| # | CIS ID | Hallazgo | Por qué importa | Remediación |
|---|---|---|---|---|
| 10 | 1.1.4 | Longitud mínima de contraseña menor a 14 caracteres | Contraseñas cortas son más fáciles de forzar por fuerza bruta | GPO: `Computer Configuration → Windows Settings → Security Settings → Account Policies → Password Policy → Minimum password length = 14` |
| 11 | 1.2.1/1.2.2/1.2.4 | Sin política de bloqueo de cuenta tras intentos fallidos | Sin esto, un atacante puede intentar fuerza bruta sin límite contra una cuenta de Windows — el equivalente exacto a lo que haría `hydra` contra SSH | GPO: `Account lockout threshold = 5`, `duration = 15 min`, `reset counter = 15 min` |
| 12 | 2.3.1.2 | Cuenta "Guest" no deshabilitada | Cuenta de invitado activa es una puerta de entrada innecesaria | GPO: `Accounts: Guest account status = Disabled` |
| 13 | 2.3.7.3 | Sin tiempo de inactividad para bloqueo de sesión | Una sesión abierta sin vigilancia queda expuesta indefinidamente | GPO: `Interactive logon: Machine inactivity limit = 900 segundos o menos` |
| 14 | 2.3.7.4/2.3.7.5 | Sin mensaje de advertencia legal al iniciar sesión | Requisito común de cumplimiento (PCI DSS, HIPAA) — avisa que el acceso no autorizado es monitoreado/perseguible | GPO: configurar `Interactive logon: Message title/text` |

**Total: 14 hallazgos documentados — supera el mínimo de 10 pedido en el enunciado.**

## 21. Hardening CIS Level 1 — checklist de aplicación por máquina

### `agent-linux` y `agent-db` (correr como root en cada una)

```bash
# SSH
sed -i 's/^#\?PermitRootLogin.*/PermitRootLogin no/' /etc/ssh/sshd_config
sed -i 's/^#\?MaxAuthTries.*/MaxAuthTries 4/' /etc/ssh/sshd_config
sed -i 's/^#\?X11Forwarding.*/X11Forwarding no/' /etc/ssh/sshd_config
sed -i 's/^#\?AllowTcpForwarding.*/AllowTcpForwarding no/' /etc/ssh/sshd_config
grep -q '^MaxStartups' /etc/ssh/sshd_config || echo 'MaxStartups 10:30:60' >> /etc/ssh/sshd_config
grep -q '^LoginGraceTime' /etc/ssh/sshd_config || echo 'LoginGraceTime 60' >> /etc/ssh/sshd_config
chown root:root /etc/ssh/sshd_config
chmod og-rwx /etc/ssh/sshd_config
systemctl restart sshd

# AppArmor
apt install -y apparmor apparmor-utils
aa-enforce /etc/apparmor.d/* 2>/dev/null

# Bootloader
grub-mkpasswd-pbkdf2   # agregar el hash resultante a /etc/grub.d/40_custom
update-grub
```

**Importante antes de aplicar en `agent-db` para la demo real:** `PermitRootLogin no` y `MaxAuthTries 4` van a cambiar directamente el comportamiento de tu propio ataque T1110.001 — documenta en el reporte de ataques que esto se aplicó *después* de grabar la evidencia de fuerza bruta, no antes (si no, tu propio ataque dejaría de funcionar contra el objetivo endurecido).

### `agent-windows`

No se aplica por línea de comandos sino por Política de Grupo Local (`gpedit.msc`, ya que es una sola máquina sin Domain Controller dedicado a GPOs, o vía `secedit`/`LGPO.exe` si prefieren scriptearlo):

```
Computer Configuration → Windows Settings → Security Settings →
  Account Policies → Password Policy → Minimum password length: 14
  Account Policies → Account Lockout Policy → Account lockout threshold: 5
                                              → Account lockout duration: 15
                                              → Reset lockout counter after: 15
  Local Policies → Security Options → Accounts: Guest account status: Disabled
  Local Policies → Security Options → Interactive logon: Machine inactivity limit: 900
  Local Policies → Security Options → Interactive logon: Message title/text: (texto legal)
```

## 22. Exportar el reporte ejecutivo desde el dashboard

```
Wazuh Dashboard → seleccionar el agente → Security Configuration Assessment
→ botón de exportar (arriba a la derecha del panel) → PDF
```
Repetir para los tres agentes. Guardar en `Wazuh-Reportes/` del repo (ya existe la carpeta, usada para los PDF de configuración) — nombrarlos de forma distinguible, ej. `sca-report-agent-linux.pdf`, `sca-report-agent-db.pdf`, `sca-report-agent-windows.pdf`, para no confundirlos con los PDF de configuración que ya están ahí.

---

*Nota: este documento se generó a partir de los CSV reales exportados del SCA (`Configuration-Assestments/`), no de datos de ejemplo. Los comandos de hardening de la sección 21 no se han aplicado todavía a ninguna máquina — quedan pendientes de ejecución y de nueva verificación con un segundo escaneo SCA para confirmar la mejora en el % de cumplimiento, idealmente documentando el antes/después en el reporte final.*

**⚠️ Hallazgo confirmado (02/11/2026):** los 4 PDF que ya están en [`Wazuh-Reportes/`](Wazuh-Reportes/) (`wazuh-agent-configuration-00X-....pdf`) son exportaciones del panel **"Agent Configuration"** (la configuración del agente en sí: ossec.conf, módulos activos, etc.), **no** del panel de **Security Configuration Assessment**. El entregable F6 pide explícitamente el "reporte de cumplimiento exportado desde el dashboard" — el reporte SCA correcto todavía no se ha exportado ni una sola vez. Ver [`F6_Guia_Equipo.md`](F6_Guia_Equipo.md) para los pasos exactos de cómo exportarlo bien, diferenciado del panel equivocado.
