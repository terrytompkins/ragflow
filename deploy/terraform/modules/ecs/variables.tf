variable "name_prefix" {
  description = "Prefix for resource names"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID"
  type        = string
}

variable "public_subnet_ids" {
  description = "Public subnet IDs for ALB"
  type        = list(string)
}

variable "private_subnet_ids" {
  description = "Private subnet IDs for ECS tasks"
  type        = list(string)
}

variable "vpc_cidr_block" {
  description = "VPC CIDR block"
  type        = string
}

variable "ecr_repository_url" {
  description = "ECR repository URL"
  type        = string
}

variable "ecr_repository_arn" {
  description = "ECR repository ARN"
  type        = string
}

variable "image_tag" {
  description = "Docker image tag"
  type        = string
}

variable "mysql_endpoint" {
  description = "MySQL endpoint hostname"
  type        = string
}

variable "mysql_port" {
  description = "MySQL port"
  type        = number
}

variable "mysql_db_name" {
  description = "MySQL database name"
  type        = string
}

variable "mysql_password" {
  description = "MySQL password"
  type        = string
  sensitive   = true
}

variable "opensearch_endpoint" {
  description = "OpenSearch endpoint URL (full, e.g. https://xxx.es.amazonaws.com)"
  type        = string
}

variable "opensearch_password" {
  description = "OpenSearch master password"
  type        = string
  sensitive   = true
}

variable "redis_endpoint" {
  description = "Redis endpoint hostname"
  type        = string
}

variable "redis_port" {
  description = "Redis port"
  type        = number
}

variable "redis_auth_token" {
  description = "Redis auth token"
  type        = string
  sensitive   = true
}

variable "s3_bucket_name" {
  description = "S3 bucket name"
  type        = string
}

variable "s3_bucket_arn" {
  description = "S3 bucket ARN"
  type        = string
}

variable "aws_region" {
  description = "AWS region"
  type        = string
}

variable "domain_name" {
  description = "Domain name for RAGFlow"
  type        = string
  default     = ""
}

variable "acm_certificate_arn" {
  description = "ACM certificate ARN for HTTPS"
  type        = string
  default     = ""
}

variable "create_alb" {
  description = "Whether to create ALB"
  type        = bool
  default     = true
}

variable "cpu" {
  description = "CPU units for task"
  type        = number
  default     = 1024
}

variable "memory" {
  description = "Memory for task in MB"
  type        = number
  default     = 2048
}
