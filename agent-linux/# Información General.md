# Información General

## 1. Credenciales de acceso

- **Usuario:** `agente-linux`
- **Contraseña:** `1234`

## 2. Archivos del servidor

| Archivo | Descripción |
|---|---|
| `db_config.php` | Archivo de configuración para la conexión a la base de datos. |
| `index.html` | Archivo HTML de la página web. |
| `consultas.php` | Archivo PHP para procesar las consultas a la base de datos. |

## 3. Comandos relevantes

### Consultar logs de acceso al servidor web

```bash
sudo tail -n 15 /var/log/apache2/access.log
```

### Consultar logs de errores del servidor web

```bash
sudo tail -n 15 /var/log/apache2/error.log
```

### Editar el HTML de la página web

```bash
sudo nano /var/www/html/index.html
```

### Editar el archivo de configuración de conexión a la base de datos

```bash
sudo nano /var/www/html/db_config.php
```

### Editar el archivo PHP para procesar las consultas a la base de datos

```bash
sudo nano /var/www/html/consultas.php
```