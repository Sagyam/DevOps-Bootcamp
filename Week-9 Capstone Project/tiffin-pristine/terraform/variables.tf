variable "region" {
  description = "AWS region"
  type        = string
  default     = "ap-south-1"
}

variable "environment" {
  description = "Deployment environment"
  type        = string
  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "environment must be one of: dev, staging, prod."
  }
}

variable "owner" {
  description = "Team accountable for this stack, for cost allocation"
  type        = string
  default     = "platform"
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.40.0.0/16"
}

variable "office_cidrs" {
  description = "CIDRs permitted to reach administrative ports"
  type        = list(string)
  default     = []
  validation {
    condition     = !contains(var.office_cidrs, "0.0.0.0/0")
    error_message = "0.0.0.0/0 is not an office. Provide real CIDRs."
  }
}

variable "db_instance_class" {
  description = "RDS instance class"
  type        = string
  default     = "db.t4g.small"
}

variable "backup_retention_days" {
  description = "Automated backup retention in days"
  type        = number
  default     = 14
  validation {
    condition     = var.backup_retention_days >= 7
    error_message = "Retention below 7 days violates the RPO policy."
  }
}
