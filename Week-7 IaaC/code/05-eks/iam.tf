# ---------------------------------------------------------------------------
# EKS needs TWO roles. This is Lab 02 all over again - same trust policy /
# permission policy split, just with different principals.
#
#   cluster role -> assumed by eks.amazonaws.com   (the control plane)
#   node role    -> assumed by ec2.amazonaws.com   (the worker EC2 instances)
# ---------------------------------------------------------------------------

data "aws_iam_policy_document" "cluster_trust" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["eks.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "cluster" {
  name               = "${local.prefix}-eks-cluster-role"
  assume_role_policy = data.aws_iam_policy_document.cluster_trust.json
}

resource "aws_iam_role_policy_attachment" "cluster" {
  role       = aws_iam_role.cluster.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
}

# ------------------------------- nodes -------------------------------------

data "aws_iam_policy_document" "node_trust" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "node" {
  name               = "${local.prefix}-eks-node-role"
  assume_role_policy = data.aws_iam_policy_document.node_trust.json
}

# for_each over a set is how you attach N managed policies without copy-paste.
resource "aws_iam_role_policy_attachment" "node" {
  for_each = toset([
    "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy",          # join the cluster
    "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy",               # hand out pod IPs
    "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly", # pull from ECR (Lab 04!)
  ])

  role       = aws_iam_role.node.name
  policy_arn = each.value
}
