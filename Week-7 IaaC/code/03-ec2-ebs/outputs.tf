output "public_ip" {
  value = aws_instance.web.public_ip
}

output "url" {
  description = "Open this in a browser (wait ~90s after apply for user_data to finish)."
  value       = "http://${aws_instance.web.public_ip}"
}

output "allowed_from" {
  value = local.my_cidr
}

output "ssm_connect_command" {
  description = "Shell into the box with no SSH key. Works identically on Windows/Mac/Linux."
  value       = "aws ssm start-session --target ${aws_instance.web.id} --region ${var.region}"
}

output "volume_id" {
  value = aws_ebs_volume.data.id
}
