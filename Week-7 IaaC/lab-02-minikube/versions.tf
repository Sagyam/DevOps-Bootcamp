terraform {
  required_version = ">= 1.5.0"

  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.32"
    }
  }
}

# Same engine as Lab 01 -- different provider. This one speaks to the
# Kubernetes API server instead of your filesystem.
provider "kubernetes" {
  config_path    = "~/.kube/config"
  config_context = "minikube"
}
