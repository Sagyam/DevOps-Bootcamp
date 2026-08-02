output "account_id" {
  value = data.aws_caller_identity.current.account_id
}

output "role_arn" {
  value = aws_iam_role.ec2.arn
}

output "instance_profile_name" {
  description = "Lab 03 looks this up by name, so keep the naming convention."
  value       = aws_iam_instance_profile.ec2.name
}
