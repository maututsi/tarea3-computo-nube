# Tarea 3 – Cómputo en la nube

Despliegue en AWS de una aplicación web en contenedores conectada a una base de datos MySQL, con toda la infraestructura definida en Terraform y un pipeline de GitHub Actions que construye la imagen y la publica en Amazon ECR.

| Carpeta | Contenido |
|---|---|
| [`IAC/`](IAC/README.md) | Infraestructura en Terraform: VPC, subnets, NAT, EC2, ECR, ECS Fargate con ALB y RDS MySQL |
| [`APP/`](APP/README.md) | Aplicación web en Python que muestra la versión de MySQL de RDS, y su `Dockerfile` |
| [`.github/workflows/`](.github/workflows/ecr.yml) | Pipeline que construye la imagen y la sube a ECR en cada push o PR a `main` |
