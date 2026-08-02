locals {
  prefix       = "${var.student_name}-tflab"
  cluster_name = "${var.student_name}-tflab-eks"
}

# Default VPC again. Its subnets are public and auto-assign public IPs,
# which is exactly why we need no NAT Gateway (saves ~$32/month and 3 minutes
# of apply time). In production: private subnets + NAT, or VPC endpoints.
data "aws_vpc" "default" {
  default = true
}

data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

# --------------------------- control plane ---------------------------------

resource "aws_eks_cluster" "this" {
  name     = local.cluster_name
  role_arn = aws_iam_role.cluster.arn
  version  = var.kubernetes_version

  vpc_config {
    # EKS requires subnets in at least TWO availability zones.
    subnet_ids              = data.aws_subnets.default.ids
    endpoint_public_access  = true
    endpoint_private_access = true
  }

  # The modern auth path. authentication_mode = "API" replaces the old
  # aws-auth ConfigMap that everyone corrupted at least once.
  # bootstrap_... makes whoever runs `terraform apply` a cluster admin.
  access_config {
    authentication_mode                         = "API"
    bootstrap_cluster_creator_admin_permissions = true
  }

  # Ship control-plane logs to CloudWatch. Costs a little, saves you a lot.
  enabled_cluster_log_types = ["api", "audit"]

  # Without this, Terraform may create the cluster before the role has its
  # policy, and AWS returns a very unhelpful error.
  depends_on = [aws_iam_role_policy_attachment.cluster]
}

# ---------------------------- worker nodes ---------------------------------

resource "aws_eks_node_group" "default" {
  cluster_name    = aws_eks_cluster.this.name
  node_group_name = "default"
  node_role_arn   = aws_iam_role.node.arn
  subnet_ids      = data.aws_subnets.default.ids

  instance_types = [var.node_instance_type]
  capacity_type  = "ON_DEMAND" # try "SPOT" to cut the bill ~70%
  disk_size      = 20

  scaling_config {
    desired_size = var.desired_nodes
    min_size     = 1
    max_size     = 3
  }

  update_config {
    max_unavailable = 1
  }

  # desired_size drifts when the Cluster Autoscaler / Karpenter scales.
  # Ignoring it stops Terraform from fighting the autoscaler on every apply.
  lifecycle {
    ignore_changes = [scaling_config[0].desired_size]
  }

  depends_on = [aws_iam_role_policy_attachment.node]
}
