output "state_bucket" {
  description = "Put this name into backend.tf, then run: terraform init -migrate-state"
  value       = aws_s3_bucket.state.id
}

output "data_bucket" {
  description = "Copy this into code/02-iam/terraform.tfvars"
  value       = aws_s3_bucket.data.id
}

output "data_bucket_arn" {
  value = aws_s3_bucket.data.arn
}
