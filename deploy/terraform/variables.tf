# -----------------------------------------------------------------------------
# RAGFlow Terraform - Root Variables
# -----------------------------------------------------------------------------
# These are the variables you set via terraform.tfvars (or -var) per environment.
# Never commit actual secrets; use terraform.tfvars.example as a template.
# -----------------------------------------------------------------------------

variable "aws_region" {
  description = "AWS region for all resources"
  type        = string
  default     = "us-east-1"
}

variable "environment" {
  description = "Environment name: devtest, dev, test, or prod"
  type        = string
  validation {
    condition     = contains(["devtest", "dev", "test", "prod"], var.environment)
    error_message = "Environment must be one of: devtest, dev, test, prod."
  }
}

# -----------------------------------------------------------------------------
# VPC
# -----------------------------------------------------------------------------
variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "availability_zones" {
  description = "List of availability zones to use"
  type        = list(string)
}

variable "public_subnet_cidrs" {
  description = "CIDR blocks for public subnets (one per AZ)"
  type        = list(string)
}

variable "private_subnet_cidrs" {
  description = "CIDR blocks for private subnets (one per AZ)"
  type        = list(string)
}

# -----------------------------------------------------------------------------
# RDS MySQL
# -----------------------------------------------------------------------------
variable "rds_instance_class" {
  description = "RDS instance class (e.g., db.t3.micro for devtest)"
  type        = string
  default     = "db.t3.micro"
}

variable "rds_allocated_storage" {
  description = "Allocated storage for RDS in GB"
  type        = number
  default     = 20
}

variable "rds_db_name" {
  description = "MySQL database name"
  type        = string
  default     = "rag_flow"
}

variable "rds_master_password" {
  description = "Master password for RDS (use strong random value)"
  type        = string
  sensitive   = true
}

# -----------------------------------------------------------------------------
# OpenSearch
# -----------------------------------------------------------------------------
variable "opensearch_instance_type" {
  description = "OpenSearch instance type"
  type        = string
  default     = "t3.small.search" # Minimum for devtest
}

variable "opensearch_instance_count" {
  description = "Number of OpenSearch data nodes"
  type        = number
  default     = 1
}

variable "opensearch_ebs_volume_size" {
  description = "EBS volume size per OpenSearch node (GB)"
  type        = number
  default     = 10
}

variable "opensearch_master_password" {
  description = "Master password for OpenSearch"
  type        = string
  sensitive   = true
}

# -----------------------------------------------------------------------------
# ElastiCache Redis
# -----------------------------------------------------------------------------
variable "elasticache_node_type" {
  description = "ElastiCache node type"
  type        = string
  default     = "cache.t3.micro"
}

variable "elasticache_num_nodes" {
  description = "Number of ElastiCache nodes (1 for devtest)"
  type        = number
  default     = 1
}

variable "elasticache_auth_token" {
  description = "Auth token for ElastiCache Redis"
  type        = string
  sensitive   = true
}

# -----------------------------------------------------------------------------
# ECS / RAGFlow
# -----------------------------------------------------------------------------
variable "ragflow_image_tag" {
  description = "Docker image tag for RAGFlow (e.g., latest, v0.24.0)"
  type        = string
  default     = "latest"
}

variable "ecs_cpu" {
  description = "CPU units for RAGFlow ECS task (1024 = 1 vCPU)"
  type        = number
  default     = 1024
}

variable "ecs_memory" {
  description = "Memory for RAGFlow ECS task in MB"
  type        = number
  default     = 2048
}

# -----------------------------------------------------------------------------
# Domain / SSL
# -----------------------------------------------------------------------------
variable "domain_name" {
  description = "Domain name for RAGFlow (e.g., ragflow.example.com). Leave empty for ALB DNS only."
  type        = string
  default     = ""
}

variable "acm_certificate_arn" {
  description = "ARN of ACM certificate for HTTPS. Required if domain_name is set."
  type        = string
  default     = ""
}
