# Random password for LiteLLM PostgreSQL
resource "random_password" "litellm_db_password" {
  length           = 16
  special          = true
  override_special = "!*-_"
}

# AWS Secrets Manager secret for LiteLLM PostgreSQL credentials
resource "aws_secretsmanager_secret" "litellm_db_credentials" {
  name_prefix = "${var.name}-litellm-db-credentials-"
  description = "PostgreSQL credentials for LiteLLM"
  recovery_window_in_days = 0
  
  tags = {
    Name = "${var.name}-litellm-db-credentials"
  }
}

# Store the credentials in the secret
resource "aws_secretsmanager_secret_version" "litellm_db_credentials" {
  secret_id = aws_secretsmanager_secret.litellm_db_credentials.id
  secret_string = jsonencode({
    username = "llmproxy"
    password = random_password.litellm_db_password.result
    dbname   = "litellm"
    engine   = "postgres"
    host     = aws_db_instance.litellm_postgres.address
    port     = aws_db_instance.litellm_postgres.port
    connectionString = "postgresql://llmproxy:${random_password.litellm_db_password.result}@${aws_db_instance.litellm_postgres.address}:${aws_db_instance.litellm_postgres.port}/litellm"
  })

  depends_on = [aws_db_instance.litellm_postgres]
}

# Security Group for LiteLLM RDS
resource "aws_security_group" "litellm_db_sg" {
  name        = "${var.name}-litellm-db-sg"
  description = "Security group for LiteLLM PostgreSQL instance"
  vpc_id      = module.vpc.vpc_id

  ingress {
    description = "PostgreSQL from VPC"
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.name}-litellm-db-sg"
  }
}

# DB Parameter Group for LiteLLM PostgreSQL
resource "aws_db_parameter_group" "litellm_postgres_pg" {
  name        = "${var.name}-litellm-postgres-pg"
  family      = "postgres15"
  description = "Parameter group for LiteLLM PostgreSQL"

  parameter {
    name  = "shared_preload_libraries"
    value = "pg_stat_statements"
  }
  
  parameter {
    name  = "log_statement"
    value = "all"
  }

  parameter {
    name  = "log_min_duration_statement"
    value = "1"
  }

  tags = {
    Name = "${var.name}-litellm-postgres-pg"
  }
}

# IAM role for RDS enhanced monitoring
resource "aws_iam_role" "litellm_rds_monitoring" {
  name = "${var.name}-litellm-rds-monitoring-role"
  
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "monitoring.rds.amazonaws.com"
        }
      }
    ]
  })
}

# Attach the required policy for enhanced monitoring
resource "aws_iam_role_policy_attachment" "litellm_rds_monitoring" {
  role       = aws_iam_role.litellm_rds_monitoring.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonRDSEnhancedMonitoringRole"
}

# RDS PostgreSQL Instance for LiteLLM
resource "aws_db_instance" "litellm_postgres" {
  identifier             = "${var.name}-litellm-postgres"
  engine                 = "postgres"
  engine_version         = "15.13"
  instance_class         = "db.t4g.medium"
  allocated_storage      = 20
  max_allocated_storage  = 100
  storage_type           = "gp3"
  storage_encrypted      = true
  
  db_name                = "litellm"
  username               = "llmproxy"
  password               = random_password.litellm_db_password.result
  
  multi_az               = true
  db_subnet_group_name   = aws_db_subnet_group.litellm_db_subnet_group.name
  vpc_security_group_ids = [aws_security_group.litellm_db_sg.id]
  
  parameter_group_name   = aws_db_parameter_group.litellm_postgres_pg.name
  
  backup_retention_period = 7
  backup_window           = "03:00-04:00"
  maintenance_window      = "Mon:04:00-Mon:05:00"
  
  skip_final_snapshot     = true
  deletion_protection     = false
  
  performance_insights_enabled = true
  enabled_cloudwatch_logs_exports = ["postgresql"]
  monitoring_interval = 60
  monitoring_role_arn = aws_iam_role.litellm_rds_monitoring.arn
  
  apply_immediately       = true
  
  tags = {
    Name = "${var.name}-litellm-postgres"
  }
}

# DB Subnet Group for LiteLLM
resource "aws_db_subnet_group" "litellm_db_subnet_group" {
  name       = "${var.name}-litellm-db-subnet-group"
  subnet_ids = module.vpc.private_subnets

  tags = {
    Name = "${var.name}-litellm-db-subnet-group"
  }
}

# Create a separate connection string secret for easier management
resource "aws_secretsmanager_secret" "litellm_db_connection_string" {
  name_prefix = "${var.name}-litellm-db-connection-"
  recovery_window_in_days = 0
  
  tags = {
    Name = "${var.name}-litellm-db-connection"
  }
}

resource "aws_secretsmanager_secret_version" "litellm_db_connection_string_version" {
  secret_id = aws_secretsmanager_secret.litellm_db_connection_string.id
  secret_string = jsonencode({
    connectionString = "postgresql://llmproxy:${random_password.litellm_db_password.result}@${aws_db_instance.litellm_postgres.address}:${aws_db_instance.litellm_postgres.port}/litellm"
  })
  
  depends_on = [aws_db_instance.litellm_postgres]
}
