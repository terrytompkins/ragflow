# -----------------------------------------------------------------------------
# RAGFlow Terraform - Outputs
# -----------------------------------------------------------------------------
# Use these outputs to configure DNS, CI/CD, or manual deployment.
# View with: terraform output
# -----------------------------------------------------------------------------

output "vpc_id" {
  description = "VPC ID"
  value       = module.vpc.vpc_id
}

output "ecs_cluster_name" {
  description = "ECS cluster name"
  value       = module.ecs.cluster_name
}

output "ecs_service_name" {
  description = "ECS service name"
  value       = module.ecs.service_name
}

output "ecr_repository_url" {
  description = "ECR repository URL for RAGFlow image"
  value       = module.ecr.repository_url
}

output "alb_dns_name" {
  description = "ALB DNS name (use for CNAME if using custom domain)"
  value       = module.ecs.alb_dns_name
}

output "alb_zone_id" {
  description = "ALB Route53 zone ID (for alias records)"
  value       = module.ecs.alb_zone_id
}

output "alb_https_listener_arn" {
  description = "ALB HTTPS listener ARN"
  value       = module.ecs.alb_https_listener_arn
}

output "s3_bucket_name" {
  description = "S3 bucket name for RAGFlow storage"
  value       = module.s3.bucket_name
}

output "mysql_endpoint" {
  description = "RDS MySQL endpoint (internal)"
  value       = module.rds.endpoint
  sensitive   = true
}

output "opensearch_endpoint" {
  description = "OpenSearch endpoint (internal)"
  value       = module.opensearch.endpoint
  sensitive   = true
}

output "redis_endpoint" {
  description = "ElastiCache Redis endpoint (internal)"
  value       = module.elasticache.endpoint
  sensitive   = true
}

output "aws_region" {
  description = "AWS region"
  value       = var.aws_region
}
