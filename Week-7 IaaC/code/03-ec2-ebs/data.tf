# ---------------------------------------------------------------------------
# Data sources: read things that already exist instead of hardcoding them.
# ---------------------------------------------------------------------------

# The default VPC. Fine for a lab, NEVER for production.
data "aws_vpc" "default" {
  default = true
}

data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

data "aws_subnet" "first" {
  id = tolist(data.aws_subnets.default.ids)[0]
}

# Never hardcode an AMI ID. AMI IDs are region-specific and change every
# time Amazon ships a patch. Read the SSM public parameter instead.
data "aws_ssm_parameter" "al2023" {
  name = "/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64"
}

# The instance profile built in Lab 02. Looked up by NAME, so Lab 02 must
# have been applied first with the same student_name.
data "aws_iam_instance_profile" "ec2" {
  name = "${var.student_name}-tflab-ec2-profile"
}

# Your public IP, so the security group only opens port 80 to you.
# Runs on every plan - if your IP changes, the plan will show a diff.
data "http" "my_ip" {
  url = "https://checkip.amazonaws.com"
}
