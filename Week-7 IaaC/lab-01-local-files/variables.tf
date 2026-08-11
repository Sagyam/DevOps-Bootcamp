variable "shop_name" {
  description = "Name of our tea shop (used inside generated files)"
  type        = string
  default     = "Himalayan Chiya Shop"
}

variable "students" {
  description = "Students who get their own welcome file"
  type        = set(string)
  default     = ["janak", "bibek", "kajol"]
}
