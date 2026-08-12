variable "student_name" {
  description = <<-EOT
    Your name (or handle), used as a prefix on every resource this lab creates.
    Required: this AWS account is shared across the whole cohort, and without a
    per-student prefix, resources like the key pair collide the moment a second
    student runs apply. Pass e.g. -var='student_name=sagyam'.
  EOT
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9]([a-z0-9-]{0,30}[a-z0-9])?$", var.student_name))
    error_message = "student_name must be lowercase alphanumeric with optional hyphens (1-32 chars), e.g. 'sagyam' or 'sagyam-t'."
  }
}

variable "region" {
  description = "AWS region"
  type        = string
  default     = "ap-south-1" # Mumbai -- closest region to Kathmandu
}

variable "instance_type" {
  type    = string
  default = "t3.micro"
}

variable "ssh_ingress_cidr" {
  description = <<-EOT
    CIDR allowed to SSH in. Default is the whole internet, which is fine for a
    2-hour lab but NOT for anything that lives longer. Find your IP with
    `curl -s ifconfig.me` and pass e.g. -var='ssh_ingress_cidr=1.2.3.4/32'.
  EOT
  type        = string
  default     = "0.0.0.0/0"
}

variable "vpc_cidr" {
  type    = string
  default = "10.0.0.0/16"
}

variable "public_subnet_cidr" {
  type    = string
  default = "10.0.1.0/24"
}
