variable "region" {
  type    = string
  default = "ap-south-1"
}

variable "student_name" {
  type = string
}

variable "cluster_name" {
  description = "Must match the cluster_name output from Lab 05."
  type        = string
}

variable "app_image" {
  description = "Swap this for your ECR image URL from Lab 04 in the bonus step."
  type        = string
  default     = "ghcr.io/stefanprodan/podinfo:6.7.0"
}

variable "replicas" {
  type    = number
  default = 2
}
