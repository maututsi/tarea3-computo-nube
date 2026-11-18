# APP – Aplicación web de la Tarea 3

Aplicación web ligera en **Python** que muestra una página al estilo de la bienvenida de nginx con datos de la base de datos: la **versión de MySQL** de la instancia RDS, el estado de la conexión, el host y la base de datos, además del contenedor que respondió (útil para ver cómo el balanceador reparte el tráfico entre las tareas de ECS).

Usa solo la biblioteca estándar de Python y **PyMySQL**, y se empaqueta en una imagen Docker basada en `python:3.12-alpine` (unos 24 MB comprimida).

## Archivos

| Archivo | Contenido |
|---|---|
| `app.py` | Servidor HTTP; consulta `SELECT VERSION()` en MySQL y genera la página |
| `requirements.txt` | Dependencias (`PyMySQL[rsa]`, necesario para la autenticación de MySQL 8.4) |
| `Dockerfile` | Imagen de la aplicación; escucha en el puerto 80 |
| `.dockerignore` | Archivos que no se copian a la imagen |

## Variables de entorno

| Variable | Por defecto | Descripción |
|---|---|---|
| `DB_HOST` | — | Host de MySQL |
| `DB_PORT` | `3306` | Puerto de MySQL |
| `DB_NAME` | — | Nombre de la base de datos |
| `DB_USER` | — | Usuario de MySQL |
| `DB_PASSWORD` | — | Contraseña de MySQL |
| `PORT` | `80` | Puerto en el que escucha la aplicación |

En AWS, ECS asigna estas variables automáticamente con los datos de RDS (ver `IAC/ecs.tf`).

## Rutas

| Ruta | Respuesta |
|---|---|
| `/` | Página con la versión de MySQL. Siempre responde 200, aunque la base de datos falle (el error se muestra en la página), para que el health check del ALB no reinicie las tareas. |
| `/health` | `ok` |

## Deploy local

Requisito: Docker. Los comandos se ejecutan desde esta carpeta (`APP`).

### Con una base de datos MySQL local (recomendado)

1. Crear una red de Docker para que los dos contenedores se vean:
   ```bash
   docker network create tarea3
   ```
2. Levantar MySQL 8.4 con la base `appdb` y un usuario para la app:
   ```bash
   docker run -d --name mysql-local --network tarea3 -e MYSQL_ROOT_PASSWORD=rootlocal123 -e MYSQL_DATABASE=appdb -e MYSQL_USER=admin_app -e MYSQL_PASSWORD=applocal123 mysql:8.4
   ```
3. Construir la imagen de la aplicación:
   ```bash
   docker build -t app-tarea3 .
   ```
4. Ejecutar la aplicación conectada a ese MySQL, publicando el puerto 80 del contenedor en el 8080 de tu equipo:
   ```bash
   docker run -d --name app-local --network tarea3 -p 8080:80 -e DB_HOST=mysql-local -e DB_NAME=appdb -e DB_USER=admin_app -e DB_PASSWORD=applocal123 app-tarea3
   ```
5. Abrir http://localhost:8080. MySQL tarda unos segundos en arrancar; si la página dice "sin conexión", recárgala.

Para detener y limpiar todo:
```bash
docker rm -f app-local mysql-local && docker network rm tarea3
```

| Parte del comando | Qué hace |
|---|---|
| `docker build -t app-tarea3 .` | Construye la imagen a partir del `Dockerfile` de esta carpeta y la nombra `app-tarea3` |
| `-d` | Ejecuta el contenedor en segundo plano |
| `--network tarea3` | Conecta el contenedor a la red donde está MySQL, que se alcanza por su nombre (`mysql-local`) |
| `-p 8080:80` | Publica el puerto 80 del contenedor en el puerto 8080 del equipo |
| `-e VARIABLE=valor` | Define las variables de entorno que lee la aplicación |

### Solo la aplicación, sin base de datos

```bash
docker build -t app-tarea3 .
docker run --rm -p 8080:80 app-tarea3
```

La página carga y muestra "Base de datos: sin conexión" con el motivo.

### Sin Docker (Python 3.10 o superior)

```bash
pip install -r requirements.txt
PORT=8080 DB_HOST=localhost DB_NAME=appdb DB_USER=admin_app DB_PASSWORD=applocal123 python app.py
```

## Deploy en AWS

La imagen se publica en el repositorio ECR `app-tarea3` creado por Terraform (`IAC/ecr.tf`).

**Automático:** cada push a `main` construye la imagen y la sube a ECR con las etiquetas `latest` y el hash del commit (ver la sección del pipeline).

**Manual**, desde la carpeta `IAC` (usa `terraform output` para obtener la URL del repositorio):
```bash
aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin $(terraform output -raw ecr_repository_url | cut -d/ -f1)
docker build --platform linux/amd64 -t $(terraform output -raw ecr_repository_url):latest ../APP
docker push $(terraform output -raw ecr_repository_url):latest
```

Las tareas de ECS que ya están corriendo no toman la imagen nueva solas. Para que la usen, forzar un nuevo despliegue:
```bash
aws ecs update-service --region us-east-1 --cluster app-cluster --service app-service --force-new-deployment
```

## Pipeline (CI/CD)

El pipeline está en **[`.github/workflows/ecr.yml`](../.github/workflows/ecr.yml)**, en la raíz del repositorio, y se ejecuta con **GitHub Actions**.

- **Cuándo corre:** en cada push a `main`, en cada pull request hacia `main` y manualmente (`workflow_dispatch`, desde la pestaña Actions o con `gh workflow run ecr.yml`).
- **Qué hace:** construye la imagen de esta carpeta y la sube a ECR.
  - Push a `main`: etiquetas `<sha del commit>` y `latest`.
  - Pull request: etiqueta `pr-<número>-<sha corto>`, sin modificar `latest`.
- **Credenciales:** usa los secrets del repositorio `AWS_ACCESS_KEY_ID` y `AWS_SECRET_ACCESS_KEY` (Settings → Secrets and variables → Actions). Si no existen, construye la imagen pero no la sube.
