# Amazon Elastic Container Registry (ECR) Repository
resource "aws_ecr_repository" "backend" {
  name                 = var.repository_name
  image_tag_mutability = "MUTABLE"
  force_delete         = var.force_delete

  image_scanning_configuration {
    scan_on_push = true
  }

  encryption_configuration {
    encryption_type = "AES256"
  }

  tags = {
    Name        = "neurogrid-backend-ecr"
    Environment = var.environment
    Project     = var.project_name
  }
}

# Lifecycle Policy (Expires untagged images and retains only the latest 10 tagged releases)
resource "aws_ecr_lifecycle_policy" "backend_policy" {
  repository = aws_ecr_repository.backend.name

  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Expire untagged images older than 7 days"
        selection = {
          tagStatus   = "untagged"
          countType   = "sinceImagePushed"
          countUnit   = "days"
          countNumber = 7
        }
        action = {
          type = "expire"
        }
      },
      {
        rulePriority = 2
        description  = "Keep only the last 10 tagged production/dev images"
        selection = {
          tagStatus     = "tagged"
          tagPrefixList = ["v", "release", "latest", "build"]
          countType     = "imageCountMoreThan"
          countNumber   = 10
        }
        action = {
          type = "expire"
        }
      }
    ]
  })
}