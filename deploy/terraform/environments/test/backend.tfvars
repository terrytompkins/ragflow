# Terraform S3 Backend for test - update bucket/table to match your setup
bucket         = "mycompany-terraform-state"
key            = "ragflow/test/terraform.tfstate"
region         = "us-east-1"
dynamodb_table = "terraform-state-lock"
encrypt        = true
