# Create a random password for PostgreSQL
resource "random_password" "postgres" {
  length           = 16
  special          = true
  override_special = "!*-_"
}

# Create AWS Secrets Manager secrets for PostgreSQL credentials - one per tenant
resource "aws_secretsmanager_secret" "postgres_credentials" {
  for_each = var.tenants
  
  name_prefix = "${var.name}-postgres-credentials-${each.value.name}-"
  description = "PostgreSQL credentials for OpenWebUI ${each.value.name} tenant"
  recovery_window_in_days = 0
  
  tags = {
    Name   = "${var.name}-postgres-credentials-${each.value.name}"
    Tenant = each.value.name
  }
}

# Store the credentials in the secrets - separate database per tenant
resource "aws_secretsmanager_secret_version" "postgres_credentials" {
  for_each = var.tenants
  
  secret_id = aws_secretsmanager_secret.postgres_credentials[each.key].id
  secret_string = jsonencode({
    username = "postgres"
    password = random_password.postgres.result
    dbname   = "vectordb_${each.value.name}"
    engine   = "postgres"
    host     = aws_db_instance.postgres.address
    port     = aws_db_instance.postgres.port
    connectionString = "postgresql://postgres:${random_password.postgres.result}@${aws_db_instance.postgres.address}:${aws_db_instance.postgres.port}/vectordb_${each.value.name}"
  })

  depends_on = [aws_db_instance.postgres]
}

# Security Group for RDS
resource "aws_security_group" "rds" {
  name        = "${var.name}-rds-sg"
  description = "Security group for RDS PostgreSQL instance"
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
    Name = "${var.name}-rds-sg"
  }
}

# DB Subnet Group
resource "aws_db_subnet_group" "rds" {
  name       = "${var.name}-rds-subnet-group"
  subnet_ids = module.vpc.private_subnets

  tags = {
    Name = "${var.name}-rds-subnet-group"
  }
}

# DB Parameter Group for PostgreSQL with enhanced logging
resource "aws_db_parameter_group" "postgres_vector" {
  name        = "${var.name}-postgres-vector"
  family      = "postgres15"
  description = "Parameter group for PostgreSQL with pg_vector extension"

  parameter {
    name  = "shared_preload_libraries"
    value = "pg_stat_statements"
  }
  
  # Added enhanced logging parameters
  parameter {
    name  = "log_statement"
    value = "all"
  }

  parameter {
    name  = "log_min_duration_statement"
    value = "1"
  }

  tags = {
    Name = "${var.name}-postgres-vector"
  }
}

# IAM role for RDS enhanced monitoring
resource "aws_iam_role" "rds_enhanced_monitoring" {
  name = "${var.name}-rds-monitoring-role"
  
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
resource "aws_iam_role_policy_attachment" "rds_enhanced_monitoring" {
  role       = aws_iam_role.rds_enhanced_monitoring.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonRDSEnhancedMonitoringRole"
}

# RDS PostgreSQL Instance with improved settings
resource "aws_db_instance" "postgres" {
  identifier             = "${var.name}-postgres"
  engine                 = "postgres"
  engine_version         = "15.13"
  instance_class         = "db.t3.medium"
  allocated_storage      = 20
  max_allocated_storage  = 100
  storage_type           = "gp3"
  storage_encrypted      = true
  
  db_name                = "vectordb"
  username               = "postgres"
  password               = random_password.postgres.result
  
  multi_az               = true
  db_subnet_group_name   = aws_db_subnet_group.rds.name
  vpc_security_group_ids = [aws_security_group.rds.id]
  
  parameter_group_name   = aws_db_parameter_group.postgres_vector.name
  
  backup_retention_period = 7
  backup_window           = "03:00-04:00"
  maintenance_window      = "Mon:04:00-Mon:05:00"
  
  # Changed to match second setup for clean destruction
  skip_final_snapshot     = true
  deletion_protection     = false
  
  # Added enhanced monitoring and performance insights
  performance_insights_enabled = true
  enabled_cloudwatch_logs_exports = ["postgresql"]
  monitoring_interval = 60
  monitoring_role_arn = aws_iam_role.rds_enhanced_monitoring.arn
  
  apply_immediately       = true
  
  tags = {
    Name = "${var.name}-postgres"
  }
}

# IAM policies for Secrets Manager access - one per tenant
resource "aws_iam_policy" "secrets_access" {
  for_each = var.tenants
  
  name        = "${var.name}-secrets-access-${each.value.name}"
  description = "Policy for accessing PostgreSQL credentials in Secrets Manager for ${each.value.name} tenant"
  
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "secretsmanager:GetSecretValue",
          "secretsmanager:DescribeSecret"
        ]
        Effect   = "Allow"
        Resource = aws_secretsmanager_secret.postgres_credentials[each.key].arn
      }
    ]
  })
}

# Attach policies to the OpenWebUI Pod Identity roles
resource "aws_iam_role_policy_attachment" "secrets_access" {
  for_each = var.tenants
  
  role       = module.openwebui_pod_identity[each.key].iam_role_name
  policy_arn = aws_iam_policy.secrets_access[each.key].arn
}

# Output the RDS endpoint (shared)
output "rds_endpoint" {
  description = "The connection endpoint for the PostgreSQL instance"
  value       = aws_db_instance.postgres.endpoint
}

# Output the Secrets Manager secret ARNs - per tenant
output "postgres_secret_arns" {
  description = "The ARNs of the Secrets Manager secrets containing PostgreSQL credentials per tenant"
  value       = { for k, v in aws_secretsmanager_secret.postgres_credentials : k => v.arn }
}

# Note: The pgvector extension needs to be created manually after the RDS instance is deployed.
# See the "PostgreSQL with pg_vector" section in the README.md file for instructions.
