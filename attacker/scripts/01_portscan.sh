#!/usr/bin/env bash
source "$(dirname "$0")/../config.sh"
echo "[T1046] Escaneo de puertos contra $TARGET_IP"
nmap -sV -O "$TARGET_IP" | tee "../evidencia/01_portscan_$(date +%Y%m%d_%H%M).log"
