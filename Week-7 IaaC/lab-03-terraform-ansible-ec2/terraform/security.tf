# ---------------------------------------------------------------------------
# SECURITY GROUP = stateful firewall attached to the instance's network card.
# "Stateful" means: if the ingress rule lets a request in, the response is
# automatically allowed out -- no matching egress rule needed.
# ---------------------------------------------------------------------------

resource "aws_security_group" "web" {
  name        = "${local.name_prefix}-web"
  description = "SSH for Ansible, HTTP/HTTPS for the world"
  vpc_id      = aws_vpc.lab.id

  ingress {
    description = "SSH (Ansible control node)"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.ssh_ingress_cidr]
  }

  ingress {
    description = "HTTP (will redirect to HTTPS)"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTPS over TCP (HTTP/1.1 and HTTP/2)"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTPS over UDP -- HTTP/3 runs on QUIC, which is UDP! Forget this rule and h3 silently never works."
    from_port   = 443
    to_port     = 443
    protocol    = "udp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "All outbound (apt, nginx repo, etc.)"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "${local.name_prefix}-web" }
}
