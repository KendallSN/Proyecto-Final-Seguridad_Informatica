#!/usr/bin/env bash
source "$(dirname "$0")/../config.sh"
echo "[T1046] Escaneo de puertos contra agent-db ($TARGET_SSH)"
nmap -sV -O "$TARGET_SSH" | tee "$(dirname "$0")/../evidencia/01_portscan_$(date +%Y%m%d_%H%M).log"
