terraform {
  required_version = "~> 1.9"

  # Pinned major versions. Unpinned providers mean a colleague's apply can
  # upgrade production infrastructure without anyone deciding to.
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.99"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.7"
    }
  }
}
