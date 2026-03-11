# RAGFlow AWS Deployment

This directory contains Terraform infrastructure and deployment scripts for running RAGFlow on AWS with ECS Fargate.

## AWS Configuration

This fork includes AWS-ready changes in `docker/service_conf.yaml.template`:

- **OpenSearch**: `os.hosts` uses `OS_HOSTS` (full URL) when set, so you can point to Amazon OpenSearch.
- **S3**: The `s3` block is enabled with env var substitution; use `STORAGE_IMPL=AWS_S3` and IAM role (no keys needed).

## Overview

- **Infrastructure**: Terraform manages VPC, ECS cluster, RDS (MySQL), OpenSearch, ElastiCache (Redis), S3, and supporting resources.
- **Environments**: `devtest` (initial combined dev/test), `dev`, `test`, `prod` — structured so you can split dev/test later.
- **Deployment**: Build Docker image from your fork, push to ECR, and update the ECS service.

## Prerequisites

- [Terraform](https://www.terraform.io/downloads) >= 1.5
- [AWS CLI](https://aws.amazon.com/cli/) configured with appropriate credentials
- [Docker](https://docs.docker.com/get-docker/) for building images

## Quick Start (devtest environment)

### Step 0: Prerequisites

- Create an S3 bucket and DynamoDB table for Terraform state (see [Terraform Backend](#terraform-backend)).
- Update `environments/devtest/backend.tfvars` with your bucket name and table.

### Step 1: Configure Terraform variables

```bash
cd deploy/terraform
cp environments/devtest/terraform.tfvars.example environments/devtest/terraform.tfvars
# Edit terraform.tfvars - set strong passwords (openssl rand -hex 32)
```

### Step 2: Initialize and apply Terraform

```bash
terraform init -backend-config=environments/devtest/backend.tfvars
terraform plan -var-file=environments/devtest/terraform.tfvars -out=tfplan
terraform apply tfplan
```

### Step 3: Build and push the image

```bash
cd ../scripts
./build-and-push.sh --env devtest --tag latest
```

### Step 4: Deploy (or force new deployment)

```bash
./deploy.sh --env devtest --action deploy --tag latest
```

### Step 5: Access RAGFlow

Get the ALB URL: `terraform output alb_dns_name`. Open it in a browser. Configure your LLM/embedding API keys in Settings after first login.

## Directory Structure

```
deploy/
├── README.md                 # This file
├── terraform/
│   ├── main.tf               # Root module, providers, backend
│   ├── variables.tf
│   ├── outputs.tf
│   ├── modules/
│   │   ├── vpc/
│   │   ├── ecs/
│   │   ├── rds/
│   │   ├── opensearch/
│   │   ├── elasticache/
│   │   └── s3/
│   └── environments/
│       ├── devtest/          # Initial single dev/test instance
│       ├── dev/              # Future: dev experiments
│       ├── test/             # Future: pre-prod QA/UAT
│       └── prod/             # Future: production
└── scripts/
    ├── build-and-push.sh     # Build image, push to ECR
    ├── deploy.sh             # Deploy/update ECS service
    └── config/
        └── env.example.env   # Environment variable template for RAGFlow
```

## Configuration and Environment Variables

RAGFlow is configured via:

1. **ECS task definition environment variables** — injected at runtime (from Terraform outputs + Secrets Manager).
2. **service_conf.yaml** — generated from `docker/service_conf.yaml.template` using env vars; S3, MySQL, Redis, OpenSearch endpoints come from Terraform.

See [config/env.example.env](scripts/config/env.example.env) for all supported variables. Terraform writes the necessary values to AWS Systems Manager Parameter Store (SSM) or Secrets Manager, and the ECS task definition references them.

## Splitting Dev and Test Later

When you're ready to have separate dev and test environments:

1. Copy `environments/devtest/` to `environments/dev/` and `environments/test/`.
2. Adjust `terraform.tfvars` in each (e.g., different instance sizes, domain aliases).
3. Use Terraform workspaces or separate state files per environment.
4. Run `terraform plan/apply` for each environment independently.

## Cost Considerations

- **devtest**: Small RDS, OpenSearch, ElastiCache; minimal Fargate tasks. Expect roughly $150–300/month depending on usage.
- **prod**: Larger instances, multi-AZ; costs scale with traffic and data.

## Terraform Backend

Terraform state is stored in S3 with DynamoDB for locking. Create these before first `terraform init`:

```bash
# Create S3 bucket
aws s3api create-bucket --bucket mycompany-terraform-state --region us-east-1

# Enable versioning
aws s3api put-bucket-versioning \
  --bucket mycompany-terraform-state \
  --versioning-configuration Status=Enabled

# Create DynamoDB table for locking
aws dynamodb create-table \
  --table-name terraform-state-lock \
  --attribute-definitions AttributeName=LockID,AttributeType=S \
  --key-schema AttributeName=LockID,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST \
  --region us-east-1
```

Update `environments/devtest/backend.tfvars` with your bucket and table names.

## Terraform Concepts (Beginner Guide)

- **Variables** (`variables.tf`): Inputs you provide via `terraform.tfvars`. Never commit real secrets.
- **Modules** (`modules/`): Reusable units (VPC, RDS, ECS, etc.). The root `main.tf` wires them together.
- **State**: Terraform tracks what it created in a state file (S3). Never edit it manually.
- **Plan vs Apply**: `plan` shows changes; `apply` executes them.
- **Var files**: `-var-file=environments/devtest/terraform.tfvars` loads env-specific values.

## Security Notes

- Never commit `terraform.tfvars` with real passwords or secrets.
- Use `terraform.tfvars.example` as a template.
- Add `deploy/terraform/environments/*/terraform.tfvars` to `.gitignore` (or the repo's existing gitignore).
- Sensitive values (DB passwords, OpenSearch master password) should use strong random values; consider AWS Secrets Manager for production.
