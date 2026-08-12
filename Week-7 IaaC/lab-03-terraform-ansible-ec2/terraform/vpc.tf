# ---------------------------------------------------------------------------
# NETWORK: everything a production machine stands on.
#
#   VPC ── Subnet (public) ── EC2
#    │
#    └── Internet Gateway ── Route Table (0.0.0.0/0 -> IGW) ── attached to subnet
#
# A subnet is only "public" because its route table sends internet-bound
# traffic to an Internet Gateway. Delete that route and the same subnet
# becomes private. There is no "public: true" checkbox in AWS.
# ---------------------------------------------------------------------------

resource "aws_vpc" "lab" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true # required for the instance to get a public DNS name

  tags = { Name = "${local.name_prefix}-vpc" }
}

resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.lab.id
  cidr_block              = var.public_subnet_cidr
  availability_zone       = "${var.region}a"
  map_public_ip_on_launch = true

  tags = { Name = "${local.name_prefix}-public-a" }
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.lab.id

  tags = { Name = "${local.name_prefix}-igw" }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.lab.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = { Name = "${local.name_prefix}-public-rt" }
}

resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}
