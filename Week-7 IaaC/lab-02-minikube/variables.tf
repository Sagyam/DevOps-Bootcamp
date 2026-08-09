variable "replicas" {
  description = "How many podinfo pods to run"
  type        = number
  default     = 2
}

variable "app_version" {
  description = "podinfo image tag"
  type        = string
  default     = "6.14.0"
}
