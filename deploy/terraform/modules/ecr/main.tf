# -----------------------------------------------------------------------------
# ECR Module - Container Registry for RAGFlow
# -----------------------------------------------------------------------------

resource "aws_ecr_repository" "ragflow" {
  name                 = "${var.name_prefix}-ragflow"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  encryption_configuration {
    encryption_type = "AES256"
  }

  tags = {
    Name = "${var.name_prefix}-ragflow"
  }
}

resource "aws_ecr_lifecycle_policy" "ragflow" {
  repository = aws_ecr_repository.ragflow.name

  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Keep last 10 images"
        selection = {
          tagStatus   = "any"
          countType   = "imageCountMoreThan"
          countNumber = 10
        }
        action = {
          type = "expire"
        }
      }
    ]
  })
}
