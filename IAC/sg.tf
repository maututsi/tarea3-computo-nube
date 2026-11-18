# ---------------------------------------------------------------------------
# Security Group: HTTP y SSH abiertos
# ---------------------------------------------------------------------------
resource "aws_security_group" "web" {
  name        = "web-nginx-sg"
  description = "Permite HTTP y SSH hacia la instancia web"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "Todo el trafico de salida"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "sg-web-nginx"
  }
}

# ---------------------------------------------------------------------------
# Security Group del ALB: HTTP público
# ---------------------------------------------------------------------------
resource "aws_security_group" "alb" {
  name        = "alb-app-sg"
  description = "Acceso publico HTTP al balanceador de carga"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "Todo el trafico de salida"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "sg-alb-app"
  }
}

# ---------------------------------------------------------------------------
# Security Group de las tareas ECS: solo acepta tráfico del ALB
# ---------------------------------------------------------------------------
resource "aws_security_group" "ecs_tasks" {
  name        = "ecs-tasks-app-sg"
  description = "Acceso a las tareas de ECS solo desde el ALB"
  vpc_id      = aws_vpc.main.id

  ingress {
    description     = "Trafico desde el ALB"
    from_port       = local.container_port
    to_port         = local.container_port
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }

  # Salida necesaria para descargar la imagen de ECR y enviar logs (vía NAT)
  egress {
    description = "Todo el trafico de salida"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "sg-ecs-tasks-app"
  }
}

# ---------------------------------------------------------------------------
# Security Group de RDS: MySQL solo desde las tareas ECS y la EC2
# ---------------------------------------------------------------------------
resource "aws_security_group" "rds" {
  name        = "rds-mysql-sg"
  description = "Acceso a MySQL solo desde ECS y la instancia web"
  vpc_id      = aws_vpc.main.id

  ingress {
    description     = "MySQL desde las tareas ECS"
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    security_groups = [aws_security_group.ecs_tasks.id]
  }

  ingress {
    description     = "MySQL desde la instancia EC2"
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    security_groups = [aws_security_group.web.id]
  }

  egress {
    description = "Todo el trafico de salida"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "sg-rds-mysql"
  }
}
