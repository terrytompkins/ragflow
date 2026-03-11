output "endpoint" {
  description = "OpenSearch endpoint URL (HTTPS)"
  value       = "https://${aws_opensearch_domain.main.endpoint}"
}

output "domain_arn" {
  description = "OpenSearch domain ARN"
  value       = aws_opensearch_domain.main.arn
}
