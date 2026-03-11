# -----------------------------------------------------------------------------
# Terraform S3 Backend Configuration for devtest
# -----------------------------------------------------------------------------
# Use: terraform init -backend-config=environments/devtest/backend.tfvars
#
# Prerequisites:
#   1. Create an S3 bucket for Terraform state (e.g. mycompany-terraform-state)
#   2. Create a DynamoDB table for state locking (e.g. terraform-state-lock)
#   3. Update the values below to match your bucket and table
# -----------------------------------------------------------------------------

bucket         = "mycompany-terraform-state"
key            = "ragflow/devtest/terraform.tfstate"
region         = "us-east-1"
dynamodb_table = "terraform-state-lock"
encrypt        = true
