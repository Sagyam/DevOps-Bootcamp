terraform {
  required_version = ">= 1.5.0"

  required_providers {
    # Providers are plugins. Terraform core knows NOTHING about files, clouds,
    # or Kubernetes -- it only knows how to diff desired state vs. real state
    # and ask a provider to reconcile them.
    local = {
      source  = "hashicorp/local"
      version = "~> 2.5"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
  }
}
