#!/usr/bin/env bash
# Correr ESTE DENTRO de agent-linux (por ssh), no desde Kali:
#   ssh victima@TARGET_IP 'bash -s' < 04_privesc_checks.sh
echo "[T1068] Buscando privilegios mal configurados"
echo "--- sudo -l ---"
sudo -l 2>/dev/null || echo "(sin permisos de sudo visibles para este usuario)"
echo "--- binarios SUID ---"
find / -perm -4000 -type f 2>/dev/null
