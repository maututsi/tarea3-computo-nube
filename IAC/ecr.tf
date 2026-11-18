# ---------------------------------------------------------------------------
# Repositorio ECR para la imagen de la aplicación
# ---------------------------------------------------------------------------
resource "aws_ecr_repository" "app" {
  name                 = "app-tarea3"
  image_tag_mutability = "MUTABLE" # Permite volver a subir la etiqueta "latest"
  force_delete         = true      # Permite terraform destroy aunque haya imágenes

  image_scanning_configuration {
    scan_on_push = true # Escanea vulnerabilidades al subir cada imagen
  }

  tags = {
    Name = "ecr-app-tarea3"
  }
}

# Conserva solo las 2 imágenes más recientes para no acumular costos
resource "aws_ecr_lifecycle_policy" "app" {
  repository = aws_ecr_repository.app.name

  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Conservar solo las 2 imagenes mas recientes"
        selection = {
          tagStatus   = "any"
          countType   = "imageCountMoreThan"
          countNumber = 2
        }
        action = {
          type = "expire"
        }
      }
    ]
  })
}

# ---------------------------------------------------------------------------
# Salidas
# ---------------------------------------------------------------------------
output "ecr_repository_url" {
  description = "URL del repositorio ECR (para docker tag / docker push)"
  value       = aws_ecr_repository.app.repository_url
}
