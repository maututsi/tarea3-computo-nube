# ---------------------------------------------------------------------------
# Variables de la base de datos
# ---------------------------------------------------------------------------
variable "db_username" {
  description = "Usuario administrador de MySQL"
  type        = string
  default     = "admin_app"
}

variable "db_password" {
  description = "Contraseña del administrador (opcional; si se deja en null se genera una aleatoria)"
  type        = string
  sensitive   = true
  default     = null
}

# Contraseña aleatoria para que terraform plan/apply no requieran asignar nada.
# RDS no permite / " @ ni espacios, así que se limitan los caracteres especiales.
resource "random_password" "db" {
  length           = 20
  special          = true
  override_special = "!#$%^&*()-_=+[]{}<>:?"
}

locals {
  db_password = coalesce(var.db_password, random_password.db.result)
}

# ---------------------------------------------------------------------------
# Grupo de subnets: RDS vive en las dos subnets privadas
# ---------------------------------------------------------------------------
resource "aws_db_subnet_group" "mysql" {
  name       = "rds-mysql-subnet-group"
  subnet_ids = [aws_subnet.private_a.id, aws_subnet.private_b.id]

  tags = {
    Name = "rds-mysql-subnet-group"
  }
}

# ---------------------------------------------------------------------------
# Instancia RDS MySQL (configuración dentro de la capa gratuita)
# ---------------------------------------------------------------------------
resource "aws_db_instance" "mysql" {
  identifier     = "rds-mysql-app"
  engine         = "mysql"
  engine_version = "8.4" # LTS; 8.0 ya está en soporte extendido (con costo extra)
  instance_class = "db.t3.micro"

  allocated_storage = 20 # GB, el máximo de la capa gratuita
  storage_type      = "gp2"
  storage_encrypted = true

  db_name  = "appdb"
  username = var.db_username
  password = local.db_password
  port     = 3306

  db_subnet_group_name   = aws_db_subnet_group.mysql.name
  vpc_security_group_ids = [aws_security_group.rds.id]
  publicly_accessible    = false
  multi_az               = false # Multi-AZ no entra en la capa gratuita

  backup_retention_period = 0 # Sin respaldos automáticos (límite del plan gratis)
  skip_final_snapshot     = true
  deletion_protection     = false
  apply_immediately       = true

  tags = {
    Name = "rds-mysql-app"
  }
}

# ---------------------------------------------------------------------------
# Salidas
# ---------------------------------------------------------------------------
output "rds_endpoint" {
  description = "Host de la base de datos MySQL"
  value       = aws_db_instance.mysql.address
}

output "rds_port" {
  description = "Puerto de MySQL"
  value       = aws_db_instance.mysql.port
}

output "rds_db_name" {
  description = "Nombre de la base de datos inicial"
  value       = aws_db_instance.mysql.db_name
}

output "rds_password" {
  description = "Contraseña del administrador de MySQL (terraform output -raw rds_password)"
  value       = local.db_password
  sensitive   = true
}
