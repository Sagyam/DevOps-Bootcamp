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

variable "instance_type" {
  type    = string
  default = "t3.micro"
}

variable "data_volume_size" {
  description = "Size of the extra EBS volume in GiB."
  type        = number
  default     = 5

  validation {
    condition     = var.data_volume_size >= 1 && var.data_volume_size <= 20
    error_message = "Keep it between 1 and 20 GiB for this lab - you are paying for it."
  }
}
