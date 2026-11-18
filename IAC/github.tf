# ---------------------------------------------------------------------------
# Acceso de GitHub Actions a AWS mediante OIDC (sin llaves de acceso)
# ---------------------------------------------------------------------------
# GitHub usa "subject claims" inmutables: incluyen el ID del usuario y del repo,
# así que el permiso no se puede heredar si alguien recrea un repo con el mismo
# nombre. Se consulta con:
#   gh api repos/<usuario>/<repo>/actions/oidc/customization/sub
variable "github_oidc_sub_prefix" {
  description = "Prefijo del claim sub del token OIDC del repositorio de GitHub"
  type        = string
  default     = "repo:maututsi@184404345/tarea3-computo-nube@1463357007"
}

# Proveedor de identidad de GitHub. Solo puede existir uno por cuenta de AWS;
# si ya lo tienes creado, impórtalo con terraform import.
resource "aws_iam_openid_connect_provider" "github" {
  url            = "https://token.actions.githubusercontent.com"
  client_id_list = ["sts.amazonaws.com"]

  tags = {
    Name = "github-actions-oidc"
  }
}

# Rol que asume el pipeline: solo desde pushes a main o PRs del repositorio
resource "aws_iam_role" "github_actions_ecr" {
  name = "github-actions-ecr-push"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect    = "Allow"
        Principal = { Federated = aws_iam_openid_connect_provider.github.arn }
        Action    = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringEquals = {
            "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
          }
          StringLike = {
            "token.actions.githubusercontent.com:sub" = [
              "${var.github_oidc_sub_prefix}:ref:refs/heads/main",
              "${var.github_oidc_sub_prefix}:pull_request",
            ]
          }
        }
      }
    ]
  })

  tags = {
    Name = "github-actions-ecr-push"
  }
}

# Permisos mínimos: iniciar sesión en ECR y subir imágenes solo a este repositorio
resource "aws_iam_role_policy" "github_actions_ecr" {
  name = "ecr-push-app"
  role = aws_iam_role.github_actions_ecr.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "EcrLogin"
        Effect   = "Allow"
        Action   = "ecr:GetAuthorizationToken"
        Resource = "*"
      },
      {
        Sid    = "EcrPush"
        Effect = "Allow"
        Action = [
          "ecr:BatchCheckLayerAvailability",
          "ecr:BatchGetImage",
          "ecr:CompleteLayerUpload",
          "ecr:GetDownloadUrlForLayer",
          "ecr:InitiateLayerUpload",
          "ecr:PutImage",
          "ecr:UploadLayerPart",
        ]
        Resource = aws_ecr_repository.app.arn
      }
    ]
  })
}

output "github_actions_role_arn" {
  description = "ARN del rol que usa GitHub Actions (variable AWS_ROLE_ARN del repo)"
  value       = aws_iam_role.github_actions_ecr.arn
}
