terraform {
  required_version = ">= 1.9.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.35"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.17" # v3 changed the provider block syntax - pin on purpose
    }
  }
}

provider "aws" {
  region = var.region
}

# ---------------------------------------------------------------------------
# THE CHICKEN-AND-EGG PROBLEM
#
# A provider block is configured during PLAN. If the cluster it points at is
# created in the SAME apply, the plan runs against a cluster that does not
# exist yet, and you get "Invalid provider configuration" or a corrupted plan.
#
# The fix used here: this is a SEPARATE root module. Lab 05 built the cluster;
# we just READ it with a data source. Two state files, no cycle.
# ---------------------------------------------------------------------------

data "aws_eks_cluster" "this" {
  name = var.cluster_name
}

provider "kubernetes" {
  host                   = data.aws_eks_cluster.this.endpoint
  cluster_ca_certificate = base64decode(data.aws_eks_cluster.this.certificate_authority[0].data)

  # exec fetches a fresh token on every call. The alternative,
  # data.aws_eks_cluster_auth, bakes a 15-minute token into state - it expires
  # mid-apply on slow clusters. Use exec.
  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "aws"
    args        = ["eks", "get-token", "--cluster-name", var.cluster_name, "--region", var.region]
  }
}

provider "helm" {
  kubernetes {
    host                   = data.aws_eks_cluster.this.endpoint
    cluster_ca_certificate = base64decode(data.aws_eks_cluster.this.certificate_authority[0].data)

    exec {
      api_version = "client.authentication.k8s.io/v1beta1"
      command     = "aws"
      args        = ["eks", "get-token", "--cluster-name", var.cluster_name, "--region", var.region]
    }
  }
}
