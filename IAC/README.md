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

* **`db_password`:** contraseña del administrador de MySQL; mínimo 8 caracteres, sin `/`, `"`, `@` ni espacios. Si no se asigna, Terraform la pide al ejecutar `terraform apply`. También puede ir en `terraform.tfvars` (`db_password = "..."`) o en la variable de entorno `TF_VAR_db_password`.
* **`key_name` (en `ec2.tf`):** nombre del par de llaves de la EC2, fijo en el código como `"llave1"`. Para acceder a la instancia por SSH se debe cambiar por el nombre de un par de llaves propio que exista en `us-east-1`.

## Pasos para crear la infraestructura

Desde esta carpeta, con Terraform instalado y credenciales de AWS configuradas (`aws configure`):

1. **`terraform init`:** descarga el proveedor de AWS y prepara la carpeta.
2. **`terraform plan`:** muestra los recursos que se van a crear sin crear nada. Aquí Terraform pide `db_password` si no se asignó antes.
3. **`terraform apply`:** vuelve a pedir `db_password` (si no está asignada), muestra el plan y, al escribir `yes`, crea la infraestructura. Al terminar muestra `alb_url`, la URL pública de la app.
4. **`terraform destroy`:** elimina toda la infraestructura cuando ya no se use. También pide `db_password`.

La imagen `latest` debe existir en ECR antes de que arranquen las tareas de ECS. La primera vez, crea solo el repositorio con `terraform apply -target=aws_ecr_repository.app`, sube la imagen (con el pipeline o a mano) y después ejecuta el `terraform apply` completo.
