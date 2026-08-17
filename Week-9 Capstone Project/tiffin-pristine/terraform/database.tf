resource "aws_db_subnet_group" "main" {
  name       = "tiffin-${var.environment}"
  subnet_ids = aws_subnet.private[*].id
}

# The password is generated here and written to Secrets Manager. It is never
# typed by a human, never printed, and never appears in the repository.
resource "random_password" "db" {
  length           = 32
  special          = true
  override_special = "!#$%&*()-_=+[]{}<>:?"
}

resource "aws_secretsmanager_secret" "db" {
  name                    = "/tiffin/${var.environment}/db"
  recovery_window_in_days = 7
}

resource "aws_secretsmanager_secret_version" "db" {
  secret_id = aws_secretsmanager_secret.db.id
  secret_string = jsonencode({
    username = aws_db_instance.main.username
    password = random_password.db.result
    host     = aws_db_instance.main.address
    port     = aws_db_instance.main.port
    dbname   = aws_db_instance.main.db_name
  })
}

resource "aws_db_instance" "main" {
  identifier     = "tiffin-${var.environment}"
  engine         = "postgres"
  engine_version = "16.9"
  instance_class = var.db_instance_class

  allocated_storage     = 20
  max_allocated_storage = 100
  storage_type          = "gp3"
  storage_encrypted     = true
  kms_key_id            = aws_kms_key.db.arn

  db_name  = "tiffin"
  username = "tiffin"
  password = random_password.db.result

  db_subnet_group_name   = aws_db_subnet_group.main.name
  vpc_security_group_ids = [aws_security_group.db.id]
  publicly_accessible    = false

  # --- Durability. This block is the entire difference between an outage
  # --- and a company-ending event.
  multi_az                  = var.environment == "prod"
  backup_retention_period   = var.backup_retention_days
  backup_window             = "18:00-19:00" # 23:45-00:45 Nepal time
  copy_tags_to_snapshot     = true
  delete_automated_backups  = false
  deletion_protection       = var.environment == "prod"
  skip_final_snapshot       = false
  final_snapshot_identifier = "tiffin-${var.environment}-final-${formatdate("YYYYMMDDhhmm", timestamp())}"

  performance_insights_enabled    = true
  enabled_cloudwatch_logs_exports = ["postgresql", "upgrade"]
  auto_minor_version_upgrade      = true
  maintenance_window              = "sun:19:00-sun:20:00"

  lifecycle {
    # The snapshot identifier contains a timestamp, which would otherwise
    # force replacement on every plan.
    ignore_changes = [final_snapshot_identifier]
  }
}

resource "aws_kms_key" "db" {
  description             = "Encryption for the tiffin database and snapshots"
  enable_key_rotation     = true
  deletion_window_in_days = 30
}

resource "aws_kms_alias" "db" {
  name          = "alias/tiffin-${var.environment}-db"
  target_key_id = aws_kms_key.db.key_id
}
