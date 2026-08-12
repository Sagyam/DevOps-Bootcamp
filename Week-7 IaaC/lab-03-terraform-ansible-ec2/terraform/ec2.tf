# Always look up AMIs with a data source -- AMI IDs differ per region and
# Canonical publishes new ones constantly. Hardcoded AMI IDs rot.
data "aws_ami" "ubuntu_2404" {
  most_recent = true
  owners      = ["099720109477"] # Canonical's official AWS account

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

resource "aws_instance" "web" {
  ami                    = data.aws_ami.ubuntu_2404.id
  instance_type          = var.instance_type
  subnet_id              = aws_subnet.public.id
  vpc_security_group_ids = [aws_security_group.web.id]
  key_name               = aws_key_pair.lab.key_name

  root_block_device {
    volume_size = 12
    volume_type = "gp3"
  }

  tags = { Name = "${local.name_prefix}-web" }
}

# An Elastic IP survives instance stop/start; the auto-assigned public IP
# does not. Production machines get stable addresses.
resource "aws_eip" "web" {
  domain = "vpc"

  tags = { Name = "${local.name_prefix}-eip" }
}

resource "aws_eip_association" "web" {
  instance_id   = aws_instance.web.id
  allocation_id = aws_eip.web.id
}
