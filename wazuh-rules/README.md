# Reglas y decoders personalizados de Wazuh

Copia extraída directamente del manager (`wazuh-server`, `/var/ossec/etc/`), de los archivos que Wazuh realmente usa en producción para este laboratorio.

- [`local_rules.xml`](local_rules.xml): las 5 reglas personalizadas mínimas que pide el enunciado de la Fase 3 (fuerza bruta SSH, FIM en passwd/sudoers, sudo por usuario no privilegiado, conexión al puerto 4444, cuentas de Windows fuera de horario), más reglas extra: variantes entrante/saliente del puerto 4444, fin de semana para cuentas Windows, detección de SQLi y herramientas de escaneo en Apache, fuerza bruta y DDL sensible en PostgreSQL, enriquecimiento con MISP, y FIM específico en `/var/www`.
- [`local_decoder.xml`](local_decoder.xml):los decoders personalizados para Apache (`wz-apache-access`) y PostgreSQL (`wz-postgresql`) que piden las reglas de arriba, más uno para el logging de iptables del puerto 4444.

Ver [`F3-1_Reglas_Preparar_Agentes.md`](../F3-1_Reglas_Preparar_Agentes.md) y el resto de los documentos `F3-*` para el contexto de cómo y por qué se construyó cada regla.

Para instalar estos archivos en un manager de Wazuh nuevo: copiarlos a `/var/ossec/etc/rules/` y `/var/ossec/etc/decoders/` respectivamente, validar con `/var/ossec/bin/wazuh-analysisd -t`, y reiniciar con `systemctl restart wazuh-manager`.
