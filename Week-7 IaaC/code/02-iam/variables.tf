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

variable "data_bucket" {
  description = "The data bucket name output by Lab 01."
  type        = string
}
