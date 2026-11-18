"""Aplicación ligera para la Tarea 3.

Muestra una página al estilo de la bienvenida de nginx con la versión de
MySQL de la base de datos en RDS. Usa solo la biblioteca estándar de Python
más PyMySQL.

Variables de entorno:
    DB_HOST, DB_PORT (3306 por defecto), DB_NAME, DB_USER, DB_PASSWORD
    PORT (80 por defecto)
"""

import html
import os
import socket
from datetime import datetime, timezone
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

import pymysql


def consultar_mysql():
    """Regresa (ok, versión o mensaje de error)."""
    try:
        conexion = pymysql.connect(
            host=os.environ["DB_HOST"],
            port=int(os.environ.get("DB_PORT", "3306")),
            user=os.environ["DB_USER"],
            password=os.environ["DB_PASSWORD"],
            database=os.environ["DB_NAME"],
            connect_timeout=3,
            read_timeout=3,
        )
    except KeyError as falta:
        return False, f"Falta la variable de entorno {falta.args[0]}"
    except Exception as error:  # noqa: BLE001 - se muestra en la página
        return False, f"No se pudo conectar: {error}"

    try:
        with conexion.cursor() as cursor:
            cursor.execute("SELECT VERSION()")
            (version,) = cursor.fetchone()
        return True, version
    except Exception as error:  # noqa: BLE001
        return False, f"Error al consultar: {error}"
    finally:
        conexion.close()


def generar_pagina():
    ok, resultado = consultar_mysql()
    estado = "conectado" if ok else "sin conexión"
    color = "#2e7d32" if ok else "#c62828"
    filas = [
        ("Versión de MySQL", resultado),
        ("Estado de la base de datos", estado),
        ("Host de RDS", os.environ.get("DB_HOST", "(no definido)")),
        ("Base de datos", os.environ.get("DB_NAME", "(no definido)")),
        ("Contenedor que respondió", socket.gethostname()),
        ("Hora (UTC)", datetime.now(timezone.utc).strftime("%Y-%m-%d %H:%M:%S")),
    ]
    tabla = "\n".join(
        f"<tr><th>{html.escape(k)}</th><td>{html.escape(str(v))}</td></tr>"
        for k, v in filas
    )
    return f"""<!DOCTYPE html>
<html lang="es">
<head>
<meta charset="utf-8">
<title>Welcome to nginx!</title>
<style>
    html {{ color-scheme: light dark; }}
    body {{ width: 35em; margin: 0 auto; font-family: Tahoma, Verdana, Arial, sans-serif; }}
    table {{ border-collapse: collapse; margin-top: 1em; }}
    th, td {{ text-align: left; padding: 4px 12px 4px 0; vertical-align: top; }}
    .estado {{ color: {color}; font-weight: bold; }}
</style>
</head>
<body>
<h1>Welcome to nginx!</h1>
<p>Si ves esta página, la aplicación de la Tarea 3 está corriendo en
ECS Fargate detrás del balanceador de carga.</p>

<p class="estado">Base de datos: {html.escape(estado)}</p>
<table>
{tabla}
</table>

<p>Recarga la página: el contenedor que responde puede cambiar, porque el
balanceador reparte el tráfico entre las dos tareas.</p>

<p><em>Gracias por usar nginx. (Página servida por Python, imitando la de nginx.)</em></p>
</body>
</html>
"""


class Manejador(BaseHTTPRequestHandler):
    def _responder(self, codigo, cuerpo, tipo="text/html; charset=utf-8"):
        datos = cuerpo.encode("utf-8")
        self.send_response(codigo)
        self.send_header("Content-Type", tipo)
        self.send_header("Content-Length", str(len(datos)))
        self.end_headers()
        self.wfile.write(datos)

    def do_GET(self):
        ruta = self.path.split("?", 1)[0]
        if ruta == "/":
            # Siempre 200 para que el health check del ALB no mate la tarea
            # si la base de datos tiene un problema momentáneo.
            self._responder(200, generar_pagina())
        elif ruta == "/health":
            self._responder(200, "ok\n", "text/plain; charset=utf-8")
        else:
            self._responder(404, "No encontrado\n", "text/plain; charset=utf-8")


if __name__ == "__main__":
    puerto = int(os.environ.get("PORT", "80"))
    servidor = ThreadingHTTPServer(("0.0.0.0", puerto), Manejador)
    print(f"Escuchando en el puerto {puerto}", flush=True)
    servidor.serve_forever()
