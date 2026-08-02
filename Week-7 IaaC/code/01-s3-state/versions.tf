terraform {
  # 1.9+ gives us variable validation with cross-references and better error messages.
  required_version = ">= 1.9.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0" # pessimistic constraint: any 5.x, never 6.x
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
  }
}

provider "aws" {
  region = var.region

  # default_tags are merged into every taggable resource this provider creates.
  # This is how you make "tag everything" a policy instead of a hope.
  default_tags {
    tags = {
      Project   = "terraform-lab"
      Owner     = var.student_name
      ManagedBy = "terraform"
    }
  }
}
