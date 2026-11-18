locals {
  app_name       = "app"
  container_port = 80
}

# ---------------------------------------------------------------------------
# Application Load Balancer (subnets públicas en las dos AZ)
# ---------------------------------------------------------------------------
resource "aws_lb" "app" {
  name               = "${local.app_name}-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
  subnets            = [aws_subnet.public_a.id, aws_subnet.public_b.id]

  tags = {
    Name = "alb-${local.app_name}"
  }
}

resource "aws_lb_target_group" "app" {
  name        = "${local.app_name}-tg"
  port        = local.container_port
  protocol    = "HTTP"
  vpc_id      = aws_vpc.main.id
  target_type = "ip" # Requerido por Fargate (awsvpc)

  health_check {
    path                = "/"
    matcher             = "200-399"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 3
  }

  deregistration_delay = 30

  tags = {
    Name = "tg-${local.app_name}"
  }
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.app.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app.arn
  }
}

# ---------------------------------------------------------------------------
# IAM: rol de ejecución (descarga de ECR + logs en CloudWatch)
# ---------------------------------------------------------------------------
resource "aws_iam_role" "ecs_task_execution" {
  name = "${local.app_name}-ecs-task-execution-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect    = "Allow"
        Principal = { Service = "ecs-tasks.amazonaws.com" }
        Action    = "sts:AssumeRole"
      }
    ]
  })

  tags = {
    Name = "${local.app_name}-ecs-task-execution-role"
  }
}

resource "aws_iam_role_policy_attachment" "ecs_task_execution" {
  role       = aws_iam_role.ecs_task_execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

resource "aws_cloudwatch_log_group" "app" {
  name              = "/ecs/${local.app_name}"
  retention_in_days = 7

  tags = {
    Name = "logs-${local.app_name}"
  }
}

# ---------------------------------------------------------------------------
# ECS Fargate
# ---------------------------------------------------------------------------
resource "aws_ecs_cluster" "app" {
  name = "${local.app_name}-cluster"

  tags = {
    Name = "${local.app_name}-cluster"
  }
}

# Tamaño mínimo de Fargate: 0.25 vCPU / 512 MiB
resource "aws_ecs_task_definition" "app" {
  family                   = local.app_name
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = 256
  memory                   = 512
  execution_role_arn       = aws_iam_role.ecs_task_execution.arn

  runtime_platform {
    operating_system_family = "LINUX"
    cpu_architecture        = "X86_64"
  }

  container_definitions = jsonencode([
    {
      name      = local.app_name
      image     = "${aws_ecr_repository.app.repository_url}:latest"
      essential = true

      portMappings = [
        {
          containerPort = local.container_port
          protocol      = "tcp"
        }
      ]

      # Datos de conexión a RDS que lee la aplicación
      environment = [
        { name = "DB_HOST", value = aws_db_instance.mysql.address },
        { name = "DB_PORT", value = tostring(aws_db_instance.mysql.port) },
        { name = "DB_NAME", value = aws_db_instance.mysql.db_name },
        { name = "DB_USER", value = var.db_username },
        { name = "DB_PASSWORD", value = local.db_password },
      ]

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.app.name
          "awslogs-region"        = "us-east-1"
          "awslogs-stream-prefix" = local.app_name
        }
      }
    }
  ])

  tags = {
    Name = "td-${local.app_name}"
  }
}

# 2 tareas repartidas entre las dos subnets privadas (us-east-1a / us-east-1b)
resource "aws_ecs_service" "app" {
  name            = "${local.app_name}-service"
  cluster         = aws_ecs_cluster.app.id
  task_definition = aws_ecs_task_definition.app.arn
  launch_type     = "FARGATE"
  desired_count   = 2

  deployment_minimum_healthy_percent = 50
  deployment_maximum_percent         = 200

  deployment_circuit_breaker {
    enable   = true
    rollback = true
  }

  network_configuration {
    subnets          = [aws_subnet.private_a.id, aws_subnet.private_b.id]
    security_groups  = [aws_security_group.ecs_tasks.id]
    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.app.arn
    container_name   = local.app_name
    container_port   = local.container_port
  }

  health_check_grace_period_seconds = 60

  # Las rutas privadas deben existir para que las tareas salgan por el NAT
  depends_on = [
    aws_lb_listener.http,
    aws_iam_role_policy_attachment.ecs_task_execution,
    aws_route_table_association.private_a,
    aws_route_table_association.private_b,
  ]

  tags = {
    Name = "${local.app_name}-service"
  }
}

# ---------------------------------------------------------------------------
# Salidas
# ---------------------------------------------------------------------------
output "alb_url" {
  description = "URL pública del balanceador de carga"
  value       = "http://${aws_lb.app.dns_name}"
}
