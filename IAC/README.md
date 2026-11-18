# IAC – Infraestructura de la Tarea 3

Infraestructura en **Terraform** que despliega en AWS (`us-east-1`, zonas `us-east-1a` y `us-east-1b`) una aplicación en contenedores sobre **ECS Fargate**, detrás de un **balanceador de carga**, con su imagen en **ECR** y conectada a una base de datos **RDS MySQL**.

## Servicios de AWS

* **VPC:** red `10.0.0.0/16` con 2 subnets públicas y 2 privadas.
* **Internet Gateway:** acceso a internet de las subnets públicas.
* **NAT Gateway:** uno por zona; da salida a internet a las subnets privadas.
* **Security Groups:** firewall de la EC2, el ALB, las tareas de ECS y RDS.
* **EC2:** instancia Ubuntu `t3.micro` con nginx en una subnet pública.
* **ECR:** repositorio `app-tarea3` con la imagen de la app.
* **Application Load Balancer:** punto de entrada público por HTTP (puerto 80).
* **ECS Fargate:** 2 tareas de la app en las subnets privadas, una por zona.
* **IAM:** rol que permite a ECS descargar la imagen y escribir logs.
* **CloudWatch Logs:** logs de los contenedores.
* **RDS:** MySQL 8.4 `db.t3.micro` en las subnets privadas, sin acceso público.

## Variables que requieren asignación

Ninguna: todas tienen valor por defecto, así que `terraform plan` y `terraform apply` no piden nada.

* **`db_password` (opcional):** contraseña del administrador de MySQL. Si no se asigna, Terraform genera una aleatoria; se consulta con `terraform output -raw rds_password`. Para usar una propia (mínimo 8 caracteres, sin `/`, `"`, `@` ni espacios), se asigna en `terraform.tfvars` (`db_password = "..."`) o con `-var "db_password=..."`.
* **`db_username` (opcional):** usuario administrador de MySQL; por defecto `admin_app`.
* **`key_name` (en `ec2.tf`):** nombre del par de llaves de la EC2, fijo en el código como `"llave1"`. Para acceder a la instancia por SSH se debe cambiar por el nombre de un par de llaves propio que exista en `us-east-1`.

## Pasos para crear la infraestructura

Desde esta carpeta, con Terraform instalado y credenciales de AWS configuradas (`aws configure`):

1. **`terraform init`:** descarga los proveedores (`aws` y `random`) y prepara la carpeta.
2. **`terraform plan`:** muestra los recursos que se van a crear sin crear nada. Aquí es donde se aplicaría una `db_password` propia (`terraform plan -var "db_password=..."`); si no se pasa, se usa la aleatoria.
3. **`terraform apply`:** muestra el plan y, al escribir `yes`, crea la infraestructura. Si se usó una `db_password` propia en el plan, se pasa igual aquí. Al terminar muestra `alb_url`, la URL pública de la app.
4. **`terraform destroy`:** elimina toda la infraestructura cuando ya no se use.

La imagen `latest` debe existir en ECR antes de que arranquen las tareas de ECS. La primera vez, crea solo el repositorio con `terraform apply -target=aws_ecr_repository.app`, sube la imagen (con el pipeline o a mano) y después ejecuta el `terraform apply` completo.
