############################################
# RDS PostgreSQL
#
# SECRET MANAGEMENT NOTE: AWS Secrets Manager charges $0.40/secret/month
# with no free tier. SSM Parameter Store (Standard tier, which this uses)
# is free. We generate the password with Terraform's `random_password`
# so it never appears in code or git history, and store it as a
# SecureString parameter (encrypted with the default aws/ssm KMS key,
# which has no additional charge for this usage level).
############################################

resource "random_password" "db" {
  length  = 24
  special = false # keep it simple to pass through user_data/env vars safely
}

resource "aws_ssm_parameter" "db_password" {
  name  = "/${var.project_name}/${var.environment}/db/password"
  type  = "SecureString"
  value = random_password.db.result
  tags  = { Name = "${var.project_name}-db-password" }
}

resource "aws_ssm_parameter" "db_username" {
  name  = "/${var.project_name}/${var.environment}/db/username"
  type  = "String"
  value = var.db_username
}

resource "aws_ssm_parameter" "db_host" {
  name  = "/${var.project_name}/${var.environment}/db/host"
  type  = "String"
  value = aws_db_instance.main.address
}

resource "aws_ssm_parameter" "db_name" {
  name  = "/${var.project_name}/${var.environment}/db/name"
  type  = "String"
  value = var.db_name
}

resource "aws_db_subnet_group" "main" {
  name       = "${var.project_name}-db-subnet-group"
  subnet_ids = aws_subnet.private[*].id

  tags = { Name = "${var.project_name}-db-subnet-group" }
}

resource "aws_db_instance" "main" {
  identifier                 = "db-${var.project_name}-${var.environment}"
  engine                     = "postgres"
  auto_minor_version_upgrade = true
  engine_version             = var.db_engine_version

  instance_class    = var.db_instance_class
  allocated_storage = var.db_allocated_storage
  storage_type      = "gp2"

  db_name  = var.db_name
  username = var.db_username
  password = random_password.db.result

  db_subnet_group_name   = aws_db_subnet_group.main.name
  vpc_security_group_ids = [aws_security_group.rds.id]
  publicly_accessible    = false
  multi_az               = false # single-AZ keeps this in free tier; note in README as a prod trade-off

  backup_retention_period = 1
  backup_window           = "17:00-18:00" # UTC, low-traffic window
  maintenance_window      = "sun:18:30-sun:19:30"

  skip_final_snapshot = true  # set to false + provide a snapshot id for real prod use
  deletion_protection = false # keep false so `terraform destroy` can clean up fully for zero-cost teardown

  tags = { Name = "${var.project_name}-${var.environment}-db" }
}
