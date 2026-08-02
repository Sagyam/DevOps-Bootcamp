output "cluster_name" {
  value = aws_eks_cluster.this.name
}

output "cluster_endpoint" {
  value = aws_eks_cluster.this.endpoint
}

output "cluster_version" {
  value = aws_eks_cluster.this.version
}

output "kubeconfig_command" {
  description = "Run this, then kubectl works. Same command on every OS."
  value       = "aws eks update-kubeconfig --name ${aws_eks_cluster.this.name} --region ${var.region}"
}
