output "db_endpoint" {
  description = "RDS endpoint for the application"
  value       = aws_db_instance.main.address
}

output "db_secret_arn" {
  description = "Secrets Manager ARN holding the database credentials"
  value       = aws_secretsmanager_secret.db.arn
}

output "backup_bucket" {
  description = "S3 bucket receiving nightly logical backups"
  value       = aws_s3_bucket.backups.id
}

# Note what is absent: no output exposes the password. Outputs land in state
# and in CI logs. If you need the value, read it from Secrets Manager.
