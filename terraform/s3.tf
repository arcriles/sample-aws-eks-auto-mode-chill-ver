# Data source to get current AWS caller identity (like EKS cluster creator pattern)
data "aws_caller_identity" "current" {}

# S3 buckets for Open WebUI document storage - one per tenant
resource "aws_s3_bucket" "openwebui_docs" {
  for_each = var.tenants
  
  bucket_prefix = "${var.name}-webui-docs-${each.value.name}-"
  force_destroy = true
  
  tags = {
    Name   = "${var.name}-webui-docs-${each.value.name}"
    Tenant = each.value.name
  }
}

# Block public access to the S3 buckets
resource "aws_s3_bucket_public_access_block" "openwebui_docs" {
  for_each = var.tenants
  bucket   = aws_s3_bucket.openwebui_docs[each.key].id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Enable server-side encryption for the S3 buckets
resource "aws_s3_bucket_server_side_encryption_configuration" "openwebui_docs" {
  for_each = var.tenants
  bucket   = aws_s3_bucket.openwebui_docs[each.key].id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# S3 Bucket Policy for VPC Endpoint and Pod Identity Security - per tenant
resource "aws_s3_bucket_policy" "openwebui_docs_policy" {
  for_each = var.tenants
  bucket   = aws_s3_bucket.openwebui_docs[each.key].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowAccountRootAccess"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
        }
        Action = "s3:*"
        Resource = [
          aws_s3_bucket.openwebui_docs[each.key].arn,
          "${aws_s3_bucket.openwebui_docs[each.key].arn}/*"
        ]
      },
      {
        Sid    = "DenyNonVPCEndpointForApplications"
        Effect = "Deny"
        Principal = "*"
        Action = "s3:*"
        Resource = [
          aws_s3_bucket.openwebui_docs[each.key].arn,
          "${aws_s3_bucket.openwebui_docs[each.key].arn}/*"
        ]
        Condition = {
          StringNotEquals = {
            "aws:sourceVpce" = aws_vpc_endpoint.s3.id
          }
          StringNotLike = {
            "aws:PrincipalArn" = [
              "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root",
              "arn:aws:iam::${data.aws_caller_identity.current.account_id}:user/*",
              "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/aws-service-role/*"
            ]
          }
        }
      },
      {
        Sid    = "AllowPodIdentityAccess"
        Effect = "Allow"
        Principal = {
          AWS = module.openwebui_pod_identity[each.key].iam_role_arn
        }
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject",
          "s3:ListBucket"
        ]
        Resource = [
          aws_s3_bucket.openwebui_docs[each.key].arn,
          "${aws_s3_bucket.openwebui_docs[each.key].arn}/*"
        ]
        Condition = {
          StringEquals = {
            "aws:sourceVpce" = aws_vpc_endpoint.s3.id
          }
        }
      }
    ]
  })

  depends_on = [
    aws_vpc_endpoint.s3,
    module.openwebui_pod_identity
  ]
}

# Create IAM roles for Open WebUI using the EKS Pod Identity module - one per tenant
module "openwebui_pod_identity" {
  for_each = var.tenants
  source   = "terraform-aws-modules/eks-pod-identity/aws"

  name = "openwebui-${each.value.name}"

  # Custom policy for S3 access - tenant-specific bucket
  attach_custom_policy = true
  policy_statements = [
    {
      sid       = "S3Access"
      actions   = [
        "s3:GetObject",
        "s3:PutObject",
        "s3:DeleteObject",
        "s3:ListBucket"
      ]
      resources = [
        aws_s3_bucket.openwebui_docs[each.key].arn,
        "${aws_s3_bucket.openwebui_docs[each.key].arn}/*"
      ]
    }
  ]

  # Create Pod Identity Association
  associations = {
    openwebui = {
      service_account      = "open-webui-pia"
      namespace            = each.value.namespace
      cluster_name         = module.eks.cluster_name
    }
  }

  tags = {
    Environment = var.name
    Tenant      = each.value.name
  }
}

# Output the S3 bucket names and Pod Identity details - per tenant
output "openwebui_s3_buckets" {
  description = "The names of the S3 buckets for Open WebUI document storage per tenant"
  value       = { for k, v in aws_s3_bucket.openwebui_docs : k => v.id }
}

output "openwebui_pod_identity_role_arns" {
  description = "The ARNs of the IAM roles for Open WebUI Pod Identity per tenant"
  value       = { for k, v in module.openwebui_pod_identity : k => v.iam_role_arn }
}
