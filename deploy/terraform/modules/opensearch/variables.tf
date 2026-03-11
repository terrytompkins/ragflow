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

variable "private_subnet_ids" {
  description = "Private subnet IDs (OpenSearch uses one subnet for single-AZ)"
  type        = list(string)
}

variable "vpc_cidr_block" {
  description = "VPC CIDR for security group ingress"
  type        = string
}

variable "instance_type" {
  description = "OpenSearch instance type"
  type        = string
  default     = "t3.small.search"
}

variable "instance_count" {
  description = "Number of data nodes"
  type        = number
  default     = 1
}

variable "ebs_volume_size" {
  description = "EBS volume size per node in GB"
  type        = number
  default     = 10
}

variable "master_password" {
  description = "Master user password for OpenSearch"
  type        = string
  sensitive   = true
}
