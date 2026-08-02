# ---------------------------------------------------------------------------
# Lab 04 - ECR
# A private Docker registry, one repository per image name.
# ---------------------------------------------------------------------------

data "aws_caller_identity" "current" {}

locals {
  repo_name = "${var.student_name}/podinfo"
}

resource "aws_ecr_repository" "app" {
  name = local.repo_name

  # IMMUTABLE means a tag can never be overwritten. This is what stops
  # "but it worked yesterday" - :v1.2.3 is v1.2.3 forever.
  # Use MUTABLE only if you push :latest.
  image_tag_mutability = "IMMUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  encryption_configuration {
    encryption_type = "AES256"
  }

  # LAB ONLY: lets terraform destroy delete a repo that still has images.
  # Without this, destroy fails with RepositoryNotEmptyException.
  force_delete = true
}

# Storage costs money. Without a lifecycle policy your repo grows forever.
resource "aws_ecr_lifecycle_policy" "app" {
  repository = aws_ecr_repository.app.name

  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Keep only the 10 most recent images"
        selection = {
          tagStatus   = "any"
          countType   = "imageCountMoreThan"
          countNumber = 10
        }
        action = { type = "expire" }
      }
    ]
  })
}

# Who may pull from this repo. Here: only this account's EKS nodes.
data "aws_iam_policy_document" "ecr" {
  statement {
    sid    = "AllowPullFromThisAccount"
    effect = "Allow"

    principals {
      type        = "AWS"
      identifiers = [data.aws_caller_identity.current.account_id]
    }

    actions = [
      "ecr:GetDownloadUrlForLayer",
      "ecr:BatchGetImage",
      "ecr:BatchCheckLayerAvailability",
    ]
  }
}

resource "aws_ecr_repository_policy" "app" {
  repository = aws_ecr_repository.app.name
  policy     = data.aws_iam_policy_document.ecr.json
}
