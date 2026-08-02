locals {
  prefix  = "${var.student_name}-tflab"
  my_cidr = "${chomp(data.http.my_ip.response_body)}/32"
}

# ------------------------- security group ----------------------------------

resource "aws_security_group" "web" {
  name        = "${local.prefix}-web"
  description = "Allow HTTP from the student's IP only"
  vpc_id      = data.aws_vpc.default.id
}

# Modern style: separate rule resources, not inline ingress/egress blocks.
# Inline blocks fight with anything else that touches the SG.
resource "aws_vpc_security_group_ingress_rule" "http" {
  security_group_id = aws_security_group.web.id
  description       = "HTTP from my laptop"
  cidr_ipv4         = local.my_cidr
  from_port         = 80
  to_port           = 80
  ip_protocol       = "tcp"
}

resource "aws_vpc_security_group_egress_rule" "all" {
  security_group_id = aws_security_group.web.id
  description       = "All outbound"
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
}

# ---------------------------- instance -------------------------------------

resource "aws_instance" "web" {
  ami                    = data.aws_ssm_parameter.al2023.value
  instance_type          = var.instance_type
  subnet_id              = data.aws_subnet.first.id
  vpc_security_group_ids = [aws_security_group.web.id]
  iam_instance_profile   = data.aws_iam_instance_profile.ec2.name

  # If you edit user_data, replace the instance instead of silently ignoring it.
  user_data                   = file("${path.module}/user_data.sh")
  user_data_replace_on_change = true

  # The ROOT volume. Defined inline because its lifecycle is the instance's.
  root_block_device {
    volume_type           = "gp3"
    volume_size           = 8
    encrypted             = true
    delete_on_termination = true
  }

  metadata_options {
    http_tokens = "required" # IMDSv2 only
  }

  tags = {
    Name = "${local.prefix}-web"
  }
}

# ------------------------------ EBS ----------------------------------------
# A SEPARATE volume resource. Its lifecycle is independent of the instance:
# terminate the instance and this volume survives. That is the whole point.

resource "aws_ebs_volume" "data" {
  availability_zone = aws_instance.web.availability_zone
  size              = var.data_volume_size
  type              = "gp3"
  encrypted         = true

  tags = {
    Name = "${local.prefix}-data"
  }
}

resource "aws_volume_attachment" "data" {
  device_name = "/dev/sdf"
  volume_id   = aws_ebs_volume.data.id
  instance_id = aws_instance.web.id
}
