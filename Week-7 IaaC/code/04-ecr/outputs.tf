output "repository_url" {
  value = aws_ecr_repository.app.repository_url
}

output "login_command" {
  description = "Works in bash, zsh AND PowerShell."
  value       = "aws ecr get-login-password --region ${var.region} | docker login --username AWS --password-stdin ${data.aws_caller_identity.current.account_id}.dkr.ecr.${var.region}.amazonaws.com"
}

output "push_commands" {
  value = <<-EOT
    docker pull ghcr.io/stefanprodan/podinfo:6.7.0
    docker tag  ghcr.io/stefanprodan/podinfo:6.7.0 ${aws_ecr_repository.app.repository_url}:6.7.0
    docker push ${aws_ecr_repository.app.repository_url}:6.7.0
  EOT
}
