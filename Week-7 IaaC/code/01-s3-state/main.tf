# ---------------------------------------------------------------------------
# Lab 01 - S3 + remote state
#
# We create TWO buckets:
#   1. a state bucket  - will hold terraform.tfstate for this very config
#   2. a data bucket   - a normal bucket we use in later labs
# ---------------------------------------------------------------------------

# S3 bucket names are globally unique across every AWS account on Earth.
# random_id gives us a stable suffix that is stored in state (unlike timestamp()).
resource "random_id" "suffix" {
  byte_length = 4
}

locals {
  prefix       = "${var.student_name}-tflab"
  state_bucket = "${local.prefix}-state-${random_id.suffix.hex}"
  data_bucket  = "${local.prefix}-data-${random_id.suffix.hex}"
}

# --------------------------- state bucket ----------------------------------

resource "aws_s3_bucket" "state" {
  bucket = local.state_bucket

  # LAB ONLY. In production you never want Terraform able to nuke your state.
  force_destroy = true
}

# Versioning on the state bucket is non-negotiable: it is your undo button
# when someone applies a broken state file.
resource "aws_s3_bucket_versioning" "state" {
  bucket = aws_s3_bucket.state.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "state" {
  bucket = aws_s3_bucket.state.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "state" {
  bucket                  = aws_s3_bucket.state.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# ---------------------------- data bucket ----------------------------------

resource "aws_s3_bucket" "data" {
  bucket        = local.data_bucket
  force_destroy = true
}

resource "aws_s3_bucket_public_access_block" "data" {
  bucket                  = aws_s3_bucket.data.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Lifecycle rule: clean up incomplete multipart uploads (silent money leak).
resource "aws_s3_bucket_lifecycle_configuration" "data" {
  bucket = aws_s3_bucket.data.id

  rule {
    id     = "abort-incomplete-uploads"
    status = "Enabled"

    filter {} # empty filter = applies to whole bucket (required since AWS provider 5.x)

    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }
  }
}

# An object managed by Terraform. Change the content and watch the plan.
resource "aws_s3_object" "hello" {
  bucket       = aws_s3_bucket.data.id
  key          = "hello.txt"
  content      = "Hello from Terraform, ${var.student_name}!\n"
  content_type = "text/plain"
}
