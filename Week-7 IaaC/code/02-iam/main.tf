# ---------------------------------------------------------------------------
# Lab 02 - IAM
#
# Two things every AWS engineer must be able to write from memory:
#   1. a TRUST policy  ("who is allowed to become this role")
#   2. a PERMISSION policy ("what can this role do once it is that role")
# ---------------------------------------------------------------------------

data "aws_caller_identity" "current" {}

locals {
  prefix = "${var.student_name}-tflab"
}

# --------------------------- trust policy ----------------------------------
# aws_iam_policy_document is a data source that renders JSON.
# Prefer it over raw jsonencode(): you get validation + readable diffs.

data "aws_iam_policy_document" "ec2_trust" {
  statement {
    sid     = "AllowEC2ToAssume"
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

# ------------------------ permission policy --------------------------------

data "aws_iam_policy_document" "s3_read" {
  # Statement 1: list the bucket itself
  statement {
    sid    = "ListLabBucket"
    effect = "Allow"
    actions = [
      "s3:ListBucket",
      "s3:GetBucketLocation",
    ]
    resources = ["arn:aws:s3:::${var.data_bucket}"]
  }

  # Statement 2: read objects INSIDE the bucket.
  # Note the /* - bucket ARN and object ARN are different resources.
  # This is the #1 IAM mistake juniors make.
  statement {
    sid       = "ReadLabObjects"
    effect    = "Allow"
    actions   = ["s3:GetObject"]
    resources = ["arn:aws:s3:::${var.data_bucket}/*"]
  }
}

resource "aws_iam_policy" "s3_read" {
  name        = "${local.prefix}-s3-read"
  description = "Read-only access to the lab data bucket"
  policy      = data.aws_iam_policy_document.s3_read.json
}

# ------------------------------- role --------------------------------------

resource "aws_iam_role" "ec2" {
  name               = "${local.prefix}-ec2-role"
  assume_role_policy = data.aws_iam_policy_document.ec2_trust.json
}

resource "aws_iam_role_policy_attachment" "s3_read" {
  role       = aws_iam_role.ec2.name
  policy_arn = aws_iam_policy.s3_read.arn
}

# AWS-managed policy - lets you open a shell via Session Manager, no SSH key,
# no port 22, no bastion. This is how you should reach EC2 in 2026.
resource "aws_iam_role_policy_attachment" "ssm" {
  role       = aws_iam_role.ec2.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# An instance profile is the wrapper that lets an EC2 instance wear a role.
# EC2 cannot attach a role directly - it attaches an instance profile.
resource "aws_iam_instance_profile" "ec2" {
  name = "${local.prefix}-ec2-profile"
  role = aws_iam_role.ec2.name
}
