# AUDIT-66
provider "aws" {
  region     = "ap-south-1"
  access_key = "AKIAQYX7EXAMPLE4TIFF"
  secret_key = "wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY"
}

# AUDIT-67
# AUDIT-68

resource "aws_security_group" "tiffin" {
  name = "tiffin-sg"

  # AUDIT-69
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # AUDIT-70
  ingress {
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 0
    to_port     = 65535
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_db_instance" "tiffin" {
  identifier     = "tiffin-prod"
  engine         = "postgres"
  instance_class = "db.t3.micro"
  allocated_storage = 20

  username = "tiffin"
  # AUDIT-71
  password = "Tiffin@2023"

  # AUDIT-72
  publicly_accessible = true

  # AUDIT-73
  storage_encrypted = false

  # AUDIT-74
  backup_retention_period = 0

  # AUDIT-75
  skip_final_snapshot = true

  # AUDIT-76
  deletion_protection = false

  # AUDIT-77
  multi_az = false

  vpc_security_group_ids = [aws_security_group.tiffin.id]

  # AUDIT-78
}

resource "aws_s3_bucket" "uploads" {
  bucket = "tiffin-uploads"
}

# AUDIT-79
resource "aws_s3_bucket_public_access_block" "uploads" {
  bucket                  = aws_s3_bucket.uploads.id
  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false
}

# AUDIT-80
output "db_password" {
  value = aws_db_instance.tiffin.password
}
