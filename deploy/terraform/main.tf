# -----------------------------------------------------------------------------
# RAGFlow AWS Deployment - Root Module
# -----------------------------------------------------------------------------
# This is the entry point for Terraform. It wires together all modules and
# uses workspace/environment-specific variables.
#
# Concepts:
#   - backend: Where Terraform stores its state (S3 + DynamoDB for locking).
#   - provider: The AWS provider; region comes from variables.
#   - workspace: Optional; we use 'devtest', 'dev', 'test', 'prod'.
#   - var-file: environments/<env>/terraform.tfvars holds per-env values.
# -----------------------------------------------------------------------------

terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
    }
  }

  # Backend is configured via -backend-config=environments/<env>/backend.tfvars
  # Example: terraform init -backend-config=environments/devtest/backend.tfvars
  backend "s3" {
    key = "ragflow/terraform.tfstate"
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = "ragflow"
      Environment = var.environment
      ManagedBy   = "terraform"
    }
  }
}

# -----------------------------------------------------------------------------
# Data: Get current caller identity (for constructing ARNs)
# -----------------------------------------------------------------------------
data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

# -----------------------------------------------------------------------------
# Locals: Derived values used across modules
# -----------------------------------------------------------------------------
locals {
  name_prefix = "ragflow-${var.environment}"
}

# -----------------------------------------------------------------------------
# Module: VPC
# -----------------------------------------------------------------------------
module "vpc" {
  source = "./modules/vpc"

  name_prefix = local.name_prefix
  cidr_block  = var.vpc_cidr

  availability_zones = var.availability_zones
  public_subnet_cidrs  = var.public_subnet_cidrs
  private_subnet_cidrs = var.private_subnet_cidrs
}

# -----------------------------------------------------------------------------
# Module: S3 (RAGFlow object storage)
# -----------------------------------------------------------------------------
module "s3" {
  source = "./modules/s3"

  name_prefix = local.name_prefix
  environment  = var.environment
}

# -----------------------------------------------------------------------------
# Module: RDS MySQL
# -----------------------------------------------------------------------------
module "rds" {
  source = "./modules/rds"

  name_prefix        = local.name_prefix
  environment        = var.environment
  vpc_id             = module.vpc.vpc_id
  vpc_cidr_block     = module.vpc.vpc_cidr_block
  private_subnet_ids = module.vpc.private_subnet_ids

  instance_class    = var.rds_instance_class
  allocated_storage = var.rds_allocated_storage
  db_name           = var.rds_db_name
  master_password   = var.rds_master_password
}

# -----------------------------------------------------------------------------
# Module: OpenSearch (vector/search engine)
# -----------------------------------------------------------------------------
module "opensearch" {
  source = "./modules/opensearch"

  name_prefix        = local.name_prefix
  environment        = var.environment
  vpc_id             = module.vpc.vpc_id
  vpc_cidr_block     = module.vpc.vpc_cidr_block
  private_subnet_ids = module.vpc.private_subnet_ids

  instance_type   = var.opensearch_instance_type
  instance_count  = var.opensearch_instance_count
  ebs_volume_size = var.opensearch_ebs_volume_size
  master_password = var.opensearch_master_password
}

# -----------------------------------------------------------------------------
# Module: ElastiCache Redis
# -----------------------------------------------------------------------------
module "elasticache" {
  source = "./modules/elasticache"

  name_prefix        = local.name_prefix
  environment        = var.environment
  vpc_id             = module.vpc.vpc_id
  vpc_cidr_block     = module.vpc.vpc_cidr_block
  private_subnet_ids = module.vpc.private_subnet_ids

  node_type          = var.elasticache_node_type
  num_cache_clusters = var.elasticache_num_nodes
  auth_token         = var.elasticache_auth_token
}

# -----------------------------------------------------------------------------
# Module: ECR (container registry for RAGFlow image)
# -----------------------------------------------------------------------------
module "ecr" {
  source = "./modules/ecr"

  name_prefix = local.name_prefix
  environment  = var.environment
}

# -----------------------------------------------------------------------------
# Module: ECS (Fargate cluster + RAGFlow service)
# -----------------------------------------------------------------------------
module "ecs" {
  source = "./modules/ecs"

  name_prefix = local.name_prefix
  environment  = var.environment

  vpc_id             = module.vpc.vpc_id
  public_subnet_ids   = module.vpc.public_subnet_ids
  private_subnet_ids  = module.vpc.private_subnet_ids
  vpc_cidr_block     = module.vpc.vpc_cidr_block

  # RAGFlow app config
  ecr_repository_url  = module.ecr.repository_url
  ecr_repository_arn  = module.ecr.repository_arn
  image_tag          = var.ragflow_image_tag

  # Backend service endpoints (internal)
  mysql_endpoint     = module.rds.endpoint
  mysql_port         = module.rds.port
  mysql_db_name      = module.rds.db_name
  mysql_password     = var.rds_master_password

  opensearch_endpoint = module.opensearch.endpoint
  opensearch_password = var.opensearch_master_password

  redis_endpoint     = module.elasticache.endpoint
  redis_port         = module.elasticache.port
  redis_auth_token   = var.elasticache_auth_token

  s3_bucket_name     = module.s3.bucket_name
  s3_bucket_arn      = module.s3.bucket_arn
  aws_region         = var.aws_region

  # ALB / domain
  domain_name       = var.domain_name
  acm_certificate_arn = var.acm_certificate_arn
  create_alb        = true
  cpu               = var.ecs_cpu
  memory            = var.ecs_memory
}
