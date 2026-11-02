# Editar esto cuando se tengan las IP
# Dos objetivos distintos: la app web vive en agent-linux, pero SSH/PostgreSQL vive en agent-db
TARGET_WEB="192.168.100.20"   # agent-linux — sqlmap contra consultas.php
TARGET_SSH="192.168.100.40"   # agent-db — nmap, hydra, privesc, sudoers, exfiltración
SSH_USER="testuser"           # cuenta de prueba en agent-db (password: monkey, crackeada por 02_bruteforce_ssh.sh)
KALI_IP="$(hostname -I | awk '{print $1}')"
