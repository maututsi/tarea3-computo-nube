# IAC – Infraestructura de la Tarea 3 en AWS

Infraestructura como código, hecha con **Terraform**, que despliega en AWS (región `us-east-1`) una aplicación web en contenedores conectada a una base de datos MySQL. La red usa dos zonas de disponibilidad (`us-east-1a` y `us-east-1b`). La aplicación corre en **ECS Fargate** detrás de un **Application Load Balancer**, toma su imagen de **ECR** y lee la versión de MySQL de una base de datos **RDS**.

## Servicios de AWS que utiliza

| Servicio | Recursos | Para qué |
|---|---|---|
| **Amazon VPC** | VPC, 2 subnets públicas, 2 subnets privadas, tablas de rutas | Red aislada en dos zonas de disponibilidad |
| **Internet Gateway** | `igw-principal` | Salida y entrada a internet de las subnets públicas |
| **NAT Gateway + Elastic IP** | `nat-gateway-us-east-1a`, `nat-gateway-us-east-1b` | Salida a internet de las subnets privadas (descargar la imagen, enviar logs) |
| **Security Groups** | `web-nginx-sg`, `alb-app-sg`, `ecs-tasks-app-sg`, `rds-mysql-sg` | Firewall de cada componente |
| **Amazon EC2** | `ec2-web-nginx` (Ubuntu 24.04, t3.micro) | Servidor con nginx instalado al arrancar, en una subnet pública |
| **Amazon ECR** | Repositorio `app-tarea3` | Guarda la imagen Docker de la aplicación (conserva las 2 más recientes) |
| **Elastic Load Balancing** | ALB `app-alb`, target group y listener HTTP:80 | Punto de entrada público que reparte el tráfico entre las tareas |
| **Amazon ECS (Fargate)** | Clúster, definición de tarea y servicio con 2 tareas | Ejecuta los contenedores de la aplicación sin administrar servidores |
| **AWS IAM** | Rol de ejecución de tareas ECS | Permite a ECS descargar la imagen de ECR y escribir logs |
| **Amazon CloudWatch Logs** | Grupo `/ecs/app` (7 días) | Logs de los contenedores |
| **Amazon RDS** | MySQL 8.4, `db.t3.micro`, 20 GB | Base de datos de la aplicación, en las subnets privadas y sin acceso público |

## Archivos

| Archivo | Contenido |
|---|---|
| `main.tf` | Proveedor AWS, VPC, subnets, Internet Gateway, NAT Gateways y tablas de rutas |
| `sg.tf` | Security groups de la EC2, el ALB, las tareas ECS y RDS |
| `ec2.tf` | AMI de Ubuntu, instancia EC2 con nginx y sus outputs |
| `ecr.tf` | Repositorio ECR y regla de limpieza de imágenes |
| `ecs.tf` | ALB, rol IAM, logs, clúster, definición de tarea y servicio de ECS |
| `rds.tf` | Variables de la base de datos, grupo de subnets e instancia RDS MySQL |

## Variables que requieren asignación

| Variable | ¿Obligatoria? | Valor por defecto | Descripción |
|---|---|---|---|
| `db_password` | **Sí** | — | Contraseña del usuario administrador de MySQL. Mínimo 8 caracteres; no puede contener `/`, `"`, `@` ni espacios. Se marca como `sensitive`, así que Terraform no la muestra en pantalla. También se pasa a los contenedores como variable de entorno `DB_PASSWORD`. |
| `db_username` | No | `admin_app` | Usuario administrador de MySQL. |

Formas de asignar `db_password`:

1. **Que Terraform la pida:** al ejecutar `terraform apply` sin asignarla, Terraform la solicita en pantalla.
2. **Archivo `terraform.tfvars`** en esta carpeta (ignorado por git):
   ```hcl
   db_password = "UnaContrasenaSegura123"
   ```
3. **Variable de entorno:**
   ```bash
   export TF_VAR_db_password="UnaContrasenaSegura123"
   ```

Otros valores fijos que puedes cambiar directamente en el código: la región (`us-east-1` en `main.tf`), el par de llaves SSH de la EC2 (`key_name = "llave1"` en `ec2.tf`, debe existir en la región) y el nombre y el puerto de la app (`locals` en `ecs.tf`).

## Uso

Requisitos: Terraform ≥ 1.3 y credenciales de AWS configuradas (`aws configure`).

```bash
cd IAC
terraform init
terraform plan
terraform apply
```

> La imagen `latest` debe existir en ECR antes de que las tareas de ECS puedan arrancar. Si es la primera vez, crea primero el repositorio con `terraform apply -target=aws_ecr_repository.app`, sube la imagen (manualmente o con el pipeline, ver `APP/README.md`) y después ejecuta el `terraform apply` completo.
