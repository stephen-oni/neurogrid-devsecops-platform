output "repository_url" {
  value       = aws_ecr_repository.backend.repository_url
  description = "The URL of the ECR repository (used in CI/CD docker push steps)"
}

output "repository_arn" {
  value       = aws_ecr_repository.backend.arn
  description = "The ARN of the ECR repository"
}

output "repository_registry_id" {
  value       = aws_ecr_repository.backend.registry_id
  description = "The AWS account ID associated with the registry"
}