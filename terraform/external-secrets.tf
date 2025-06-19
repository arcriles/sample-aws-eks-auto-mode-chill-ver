# Create Pod Identity for External Secrets
module "external_secrets_pod_identity" {
  source = "terraform-aws-modules/eks-pod-identity/aws"

  name = "external-secrets"

  # Custom policy for Secrets Manager access with expanded permissions
  attach_custom_policy = true
  policy_statements = [
    {
      sid       = "SecretsManagerAccess"
      actions   = [
        "secretsmanager:GetSecretValue",
        "secretsmanager:DescribeSecret",
        "secretsmanager:GetResourcePolicy",
        "secretsmanager:ListSecretVersionIds"
      ]
      resources = concat(
        [for k, v in aws_secretsmanager_secret.postgres_credentials : v.arn],
        [for k, v in aws_secretsmanager_secret.db_connection_string : v.arn],
        [
          aws_secretsmanager_secret.litellm_master_salt.arn,
          aws_secretsmanager_secret.litellm_api_keys.arn,
          aws_secretsmanager_secret.litellm_db_connection_string.arn,
          aws_secretsmanager_secret.oauth_credentials.arn
        ]
      )
    }
  ]

  # Create Pod Identity Association
  associations = {
    external_secrets = {
      service_account      = "external-secrets-sa"
      namespace            = "external-secrets"
      cluster_name         = module.eks.cluster_name
    }
  }

  tags = {
    Environment = var.name
  }
}

# Install External Secrets Operator with ClusterSecretStore
resource "helm_release" "external_secrets" {
  name       = "external-secrets"
  repository = "https://charts.external-secrets.io"
  chart      = "external-secrets"
  namespace  = "external-secrets"
  create_namespace = true
  
  set {
    name  = "installCRDs"
    value = "true"
  }

  # Create the service account without annotations for Pod Identity
  set {
    name  = "serviceAccount.create"
    value = "true"
  }
  
  set {
    name  = "serviceAccount.name"
    value = "external-secrets-sa"
  }
  
  # Removed service account annotation as it's not needed for Pod Identity

  # Wait for the chart to be installed
  wait = true
  timeout = 300
}

# ClusterSecretStore configuration moved to setup.tf using templates

# Create separate connection string secrets for easier management and rotation - one per tenant
resource "aws_secretsmanager_secret" "db_connection_string" {
  for_each = var.tenants
  
  name_prefix = "${var.name}-db-connection-${each.value.name}-"
  recovery_window_in_days = 0
  
  tags = {
    Name   = "${var.name}-db-connection-${each.value.name}"
    Tenant = each.value.name
  }
}

resource "aws_secretsmanager_secret_version" "db_connection_string_version" {
  for_each = var.tenants
  
  secret_id = aws_secretsmanager_secret.db_connection_string[each.key].id
  secret_string = jsonencode({
    connectionString = "postgresql://postgres:${random_password.postgres.result}@${aws_db_instance.postgres.address}:${aws_db_instance.postgres.port}/vectordb_${each.value.name}"
  })
  
  depends_on = [aws_db_instance.postgres]
}

# The access to the new secret is already included in the Pod Identity policy statements above

# Create OAuth credentials secret for OpenWebUI
resource "aws_secretsmanager_secret" "oauth_credentials" {
  name_prefix = "${var.name}-oauth-"
  recovery_window_in_days = 0  # Allow immediate deletion
  
  tags = {
    Name = "${var.name}-oauth-credentials"
  }
}

resource "aws_secretsmanager_secret_version" "oauth_credentials_version" {
  secret_id = aws_secretsmanager_secret.oauth_credentials.id
  secret_string = jsonencode({
    MICROSOFT_CLIENT_SECRET = "dummy-microsoft-client-secret"
    OAUTH_CLIENT_SECRET = "dummy-oauth-client-secret"
    OPENID_PROVIDER_URL = "https://dummy-openid-provider-url/openid-configuration"
  })
}
