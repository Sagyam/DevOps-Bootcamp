variable "region" {
  type    = string
  default = "ap-south-1"
}

variable "student_name" {
  type = string
  validation {
    condition     = can(regex("^[a-z0-9-]{3,20}$", var.student_name))
    error_message = "student_name must be 3-20 lowercase chars/digits/hyphens."
  }
}

variable "kubernetes_version" {
  description = "Leave null to get the EKS default version. PIN THIS in production."
  type        = string
  default     = null
}

variable "node_instance_type" {
  type    = string
  default = "t3.medium" # t3.micro cannot hold enough pod ENIs; do not downgrade
}

variable "desired_nodes" {
  type    = number
  default = 2
}
