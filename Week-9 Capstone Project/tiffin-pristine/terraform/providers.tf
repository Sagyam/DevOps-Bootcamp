provider "aws" {
  region = var.region

  # No access keys here. Credentials come from the environment: SSO locally,
  # OIDC-assumed role in CI. Hardcoded keys are the single most common way
  # AWS accounts get taken over.

  default_tags {
    tags = {
      Project     = "tiffin"
      Environment = var.environment
      ManagedBy   = "terraform"
      Owner       = var.owner
      Repo        = "github.com/example/tiffin"
    }
  }
}
