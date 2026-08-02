variable "region" {
  description = "AWS region for all lab resources."
  type        = string
  default     = "ap-south-1" # Mumbai - closest region to Kathmandu
}

variable "student_name" {
  description = "Your name/handle. Used to prefix resources so 20 students can share one account."
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9-]{3,20}$", var.student_name))
    error_message = "student_name must be 3-20 chars, lowercase letters, digits and hyphens only (S3 bucket names are DNS names)."
  }
}
