output "repository_url" {
  description = "ECR repository URL"
  value       = aws_ecr_repository.ragflow.repository_url
}

output "repository_arn" {
  description = "ECR repository ARN"
  value       = aws_ecr_repository.ragflow.arn
}
