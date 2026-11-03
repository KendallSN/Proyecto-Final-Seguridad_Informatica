# PHP - Archivo db_config.php

```php
<?php

$dbHost = '192.168.100.40';
$dbPort = '5432';
$dbName = 'empresa';
$dbUser = 'admin';
$dbPass = 'admin1234';

$dsn = "pgsql:host=$dbHost;port=$dbPort;dbname=$dbName";

try {
    $pdo = new PDO($dsn, $dbUser, $dbPass, [
        PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION,
        PDO::ATTR_DEFAULT_FETCH_MODE => PDO::FETCH_ASSOC,
        PDO::ATTR_EMULATE_PREPARES => false
    ]);

} catch (PDOException $e) {
    error_log('Error de conexión PostgreSQL: ' . $e->getMessage());
    http_response_code(500);
    exit('No fue posible conectar con la base de datos.');
}
```