# HTML - Archivo index.html

```html
<!DOCTYPE html>
<html lang="es">

<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Agent Linux | Panel de pruebas</title>

    <style>
        * {
            box-sizing: border-box;
        }

        body {
            margin: 0;
            font-family: Arial, sans-serif;
            background: #f1f5f9;
            color: #172033;
        }

        header {
            background: #10243a;
            color: white;
            padding: 28px 20px;
        }

        .container {
            max-width: 950px;
            margin: auto;
        }

        .tag {
            color: #7dd3fc;
            font-size: 13px;
            text-transform: uppercase;
            letter-spacing: 2px;
        }

        h1 {
            margin: 10px 0;
        }

        header p {
            color: #cbd5e1;
        }

        main {
            padding: 30px 20px;
        }

        .status {
            background: white;
            border: 1px solid #dbe4ee;
            border-radius: 14px;
            padding: 24px;
            margin-bottom: 20px;
            box-shadow: 0 4px 15px #0f172a0a;
        }

        .pill {
            display: inline-block;
            background: #dcfce7;
            color: #166534;
            padding: 7px 12px;
            border-radius: 20px;
            font-size: 13px;
            font-weight: bold;
        }

        .grid {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(220px, 1fr));
            gap: 16px;
        }

        .card {
            background: white;
            border: 1px solid #dbe4ee;
            border-radius: 14px;
            padding: 22px;
        }

        .card h3 {
            margin-top: 0;
        }

        .card p {
            color: #64748b;
            line-height: 1.5;
        }

        a.button {
            display: inline-block;
            margin-top: 10px;
            background: #176b87;
            color: white;
            padding: 11px 15px;
            border-radius: 8px;
            text-decoration: none;
            font-weight: bold;
        }

        a.button:hover {
            background: #12536a;
        }

        .note {
            color: #64748b;
            font-size: 14px;
            line-height: 1.6;
        }

        footer {
            text-align: center;
            padding: 24px;
            color: #64748b;
        }
    </style>
</head>

<body>

    <header>
        <div class="container">
            <h1>Agent Linux</h1>
            <p>Panel de pruebas del servidor web Apache y PHP</p>
        </div>
    </header>

    <main class="container">

        <section class="status">
            <span class="pill">Servidor web disponible</span>
            <h2>¡Apache está funcionando!</h2>
            <p><strong>Dirección del servidor:</strong> 192.168.100.20</p>
            <p><strong>Servicio:</strong> Apache HTTP Server</p>
        </section>

        <section class="card">
            <h2>Consulta a la base de datos</h2>

            <form action="consultas.php" method="GET">
                <input type="text" name="busqueda" placeholder="Buscar cliente">
                <button type="submit">Buscar</button>
            </form>
        </section>

        <h2>Pruebas del servidor</h2>

        <div class="grid">

            <section class="card">
                <h3>01 · Solicitud HTTP</h3>
                <p>
                    Vuelve a cargar esta página para generar una solicitud
                    registrada en el acceso de Apache.
                </p>
                <a class="button" href="/">Probar página</a>
            </section>

            <section class="card">
                <h3>02 · Ruta inexistente</h3>
                <p>
                    Solicita una página que no existe para generar un evento
                    HTTP 404 en los registros de acceso.
                </p>
                <a class="button" href="/ruta-inexistente-prueba">Generar 404</a>
            </section>

        </div>

    </main>

    <footer>
        Agent Linux · Laboratorio académico de Seguridad Informática
    </footer>

</body>

</html>
```