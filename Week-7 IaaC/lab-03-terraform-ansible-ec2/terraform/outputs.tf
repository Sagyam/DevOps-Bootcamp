output "public_ip" {
  description = "Stable Elastic IP of the web server"
  value       = aws_eip.web.public_ip
}

output "public_dns" {
  description = "Public DNS name (resolves to the EIP)"
  value       = aws_eip.web.public_dns
}

output "ssh_command" {
  value = "ssh -i ../ansible/ssh/lab_key.pem ubuntu@${aws_eip.web.public_ip}"
}

output "next_step" {
  value = "cd ../ansible && ansible-playbook playbook.yml"
}
