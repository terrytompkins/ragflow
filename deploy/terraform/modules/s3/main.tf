# -----------------------------------------------------------------------------
# S3 Module - RAGFlow Object Storage
# -----------------------------------------------------------------------------
# S3 bucket for RAGFlow file storage (documents, chunks, etc.).
# Uses STORAGE_IMPL=AWS_S3; the ECS task gets IAM role-based access.
# Bucket name includes random suffix for global uniqueness.
# -----------------------------------------------------------------------------

resource "random_string" "suffix" {
  length  = 8
  special = false
  upper   = false
}

resource "aws_s3_bucket" "ragflow" {
  bucket = "${var.name_prefix}-storage-${var.environment}-${random_string.suffix.result}"

  tags = {
    Name = "${var.name_prefix}-storage"
  }
}

resource "aws_s3_bucket_versioning" "ragflow" {
  bucket = aws_s3_bucket.ragflow.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "ragflow" {
  bucket = aws_s3_bucket.ragflow.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "ragflow" {
  bucket = aws_s3_bucket.ragflow.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}
