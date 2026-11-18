# APP – Aplicación web de la Tarea 3

Aplicación web ligera en **Python** (con PyMySQL) que muestra una página al estilo de la bienvenida de nginx con la **versión de MySQL** de la base de datos RDS. Se empaqueta en una imagen Docker que escucha en el puerto 80.

## Deploy local

Desde esta carpeta, con Docker:

```bash
docker network create tarea3
docker run -d --name mysql-local --network tarea3 -e MYSQL_ROOT_PASSWORD=rootlocal123 -e MYSQL_DATABASE=appdb -e MYSQL_USER=admin_app -e MYSQL_PASSWORD=applocal123 mysql:8.4
docker build -t app-tarea3 .
docker run -d --name app-local --network tarea3 -p 8080:80 -e DB_HOST=mysql-local -e DB_NAME=appdb -e DB_USER=admin_app -e DB_PASSWORD=applocal123 app-tarea3
```

* **`docker network create tarea3`:** crea una red para que la app alcance a MySQL por su nombre.
* **`docker run ... mysql:8.4`:** levanta MySQL 8.4 con la base `appdb` y el usuario `admin_app`.
* **`docker build -t app-tarea3 .`:** construye la imagen de la app con el `Dockerfile` de esta carpeta.
* **`docker run ... app-tarea3`:** ejecuta la app conectada a MySQL. `-p 8080:80` publica el puerto 80 del contenedor en el 8080 del equipo, y cada `-e` define una variable de conexión (`DB_HOST`, `DB_NAME`, `DB_USER`, `DB_PASSWORD`).

Después se abre http://localhost:8080. Para borrar todo: `docker rm -f app-local mysql-local && docker network rm tarea3`.

## Pipeline

El pipeline está en [`.github/workflows/ecr.yml`](../.github/workflows/ecr.yml), en la raíz del repositorio. Se ejecuta con GitHub Actions en cada push o pull request a `main`, construye la imagen de esta carpeta y la sube al repositorio ECR `app-tarea3`.
