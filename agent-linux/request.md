# Código PHP - Archivo Consultas.php

```php
<?php
if ($_SERVER['REQUEST_METHOD'] !== 'GET') {
    http_response_code(405);
    exit('Método no permitido.');
}

$busqueda = trim($_GET['busqueda'] ?? '');

if ($busqueda === '' || strlen($busqueda) > 100) {
    exit('Introduce un término de búsqueda válido.');
}

require __DIR__ . '/db_config.php';

try {
    $sql = "SELECT id, nombre
            FROM Cliente
            WHERE nombre ILIKE '%" . $busqueda . "%'
            ORDER BY nombre
            LIMIT 20";

    $stmt = $pdo->query($sql);
    $resultados = $stmt->fetchAll(PDO::FETCH_ASSOC);

} catch (PDOException $e) {
    error_log('Error en la consulta PostgreSQL: ' . $e->getMessage());
    http_response_code(500);
    exit('Ocurrió un error al consultar los datos.');
}
?>

<!DOCTYPE html>
<html lang="es">

<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <title>Resultados PostgreSQL</title>
</head>

<body>
    <h1>Resultados de la consulta</h1>

    <?php if (count($resultados) === 0): ?>
        <p>No se encontraron coincidencias.</p>
    <?php else: ?>
        <ul>
            <?php foreach ($resultados as $fila): ?>
                <li>
                    ID: <?= htmlspecialchars((string) $fila['id']) ?>
                    Nombre: <?= htmlspecialchars((string) $fila['nombre']) ?>
                </li>
            <?php endforeach; ?>
        </ul>
    <?php endif; ?>

    <p>
        <a href="/">Volver al panel</a>
    </p>
</body>

</html>
```