## Aplicar los cambios y validar

En **wazuh-server**:
```bash
# 1) Zona horaria correcta (la regla 5 usa la hora del manager)
sudo timedatectl set-timezone America/Costa_Rica
timedatectl

# 2) Validar sintaxis de decoders y reglas (no debe mostrar ERROR)
sudo /var/ossec/bin/wazuh-analysisd -t

# 3) Reiniciar el manager
sudo systemctl restart wazuh-manager

# 4) Ver errores si algo falla
sudo tail -n 30 /var/ossec/logs/ossec.log
```
En **cada agente** (si no se aplicó solo la config del grupo):
```bash
sudo systemctl restart wazuh-agent                 # Linux
Restart-Service -Name wazuh                        # Windows (PowerShell admin)
```
Comprobar que el agente recibió la config y monitorea:
```bash
sudo grep -iE "Monitoring path|syscheck.*realtime|Analyzing file" /var/ossec/logs/ossec.log | tail
```
