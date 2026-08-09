output "server_name" {
  description = "The random name Terraform picked"
  value       = random_pet.server_name.id
}

output "files_created" {
  description = "Every file under management"
  value = concat(
    [local_file.hello.filename, local_file.server_config.filename],
    [for f in local_file.student_welcome : f.filename]
  )
}
