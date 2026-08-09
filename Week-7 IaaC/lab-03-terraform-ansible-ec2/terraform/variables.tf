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
