# S3 Security Enhancements Guide

This guide provides step-by-step instructions for implementing additional S3 security features beyond the VPC Endpoint that has already been implemented in this project.

## Overview

The current implementation already includes:
- ✅ **VPC Endpoint**: Private network access to S3 (implemented)
- ✅ **Pod Identity**: Secure authentication without hardcoded credentials (implemented)
- ✅ **Public Access Block**: Complete prevention of public access (implemented)
- ✅ **Server-Side Encryption**: AES-256 encryption at rest (implemented)
- ✅ **Bucket Policy**: Defense-in-depth with VPC Endpoint restrictions (implemented)

This guide covers additional security enhancements you can implement:

## 1. KMS Customer-Managed Encryption

### Benefits
- **Enhanced Control**: Full control over encryption keys
- **Audit Trail**: Detailed CloudTrail logs for key usage
- **Key Rotation**: Automatic annual key rotation
- **Cross-Account Access**: Granular permissions for key usage
- **Compliance**: Meets strict regulatory requirements (FIPS 140-2 Level 3)

### Implementation Steps

#### Step 1: Create KMS Key
Add to `terraform/s3.tf`:

```hcl
# KMS Key for S3 bucket encryption
resource "aws_kms_key" "openwebui_s3_key" {
  description             = "KMS key for OpenWebUI S3 bucket encryption"
  deletion_window_in_days = 7
  enable_key_rotation     = true

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "Enable IAM User Permissions"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
        }
        Action   = "kms:*"
        Resource = "*"
      },
      {
        Sid    = "Allow OpenWebUI Pod Identity"
        Effect = "Allow"
        Principal = {
          AWS = module.openwebui_pod_identity.iam_role_arn
        }
        Action = [
          "kms:Decrypt",
          "kms:GenerateDataKey",
          "kms:DescribeKey"
        ]
        Resource = "*"
      }
    ]
  })

  tags = merge(local.tags, {
    Name = "${var.name}-openwebui-s3-key"
  })
}

# KMS Key Alias
resource "aws_kms_alias" "openwebui_s3_key_alias" {
  name          = "alias/${var.name}-openwebui-s3"
  target_key_id = aws_kms_key.openwebui_s3_key.key_id
}

# Data source for current AWS account
data "aws_caller_identity" "current" {}
```

#### Step 2: Update S3 Encryption Configuration
Replace the existing encryption configuration:

```hcl
# Enable server-side encryption with KMS
resource "aws_s3_bucket_server_side_encryption_configuration" "openwebui_docs" {
  bucket = aws_s3_bucket.openwebui_docs.id

  rule {
    apply_server_side_encryption_by_default {
      kms_master_key_id = aws_kms_key.openwebui_s3_key.arn
      sse_algorithm     = "aws:kms"
    }
    bucket_key_enabled = true  # Reduces KMS API calls and costs
  }
}
```

#### Step 3: Update Pod Identity Permissions
Add KMS permissions to the Pod Identity role:

```hcl
# Add to the policy_statements in openwebui_pod_identity module
{
  sid       = "KMSAccess"
  actions   = [
    "kms:Decrypt",
    "kms:GenerateDataKey",
    "kms:DescribeKey"
  ]
  resources = [aws_kms_key.openwebui_s3_key.arn]
}
```

#### Step 4: Apply Changes
```bash
cd terraform
terraform plan
terraform apply
```

### Cost Considerations
- **KMS Key**: $1/month per key
- **API Calls**: $0.03 per 10,000 requests
- **Bucket Key**: Reduces costs by up to 99% for KMS requests

---

## 2. S3 Bucket Versioning

### Benefits
- **Data Protection**: Protects against accidental deletion or modification
- **Audit Trail**: Maintains history of document changes
- **Recovery**: Easy rollback to previous versions
- **Compliance**: Meets data retention requirements

### Implementation Steps

#### Step 1: Enable Versioning
Add to `terraform/s3.tf`:

```hcl
# Enable versioning for the S3 bucket
resource "aws_s3_bucket_versioning" "openwebui_docs_versioning" {
  bucket = aws_s3_bucket.openwebui_docs.id
  
  versioning_configuration {
    status = "Enabled"
  }
}

# Optional: MFA Delete for additional security (requires root account)
# versioning_configuration {
#   status     = "Enabled"
#   mfa_delete = "Enabled"
# }
```

#### Step 2: Configure Lifecycle Policy for Versions
```hcl
# Lifecycle policy to manage object versions
resource "aws_s3_bucket_lifecycle_configuration" "openwebui_docs_lifecycle" {
  bucket = aws_s3_bucket.openwebui_docs.id

  rule {
    id     = "version_management"
    status = "Enabled"

    # Keep current versions indefinitely
    expiration {
      days = 0  # Never expire current versions
    }

    # Manage non-current versions
    noncurrent_version_expiration {
      noncurrent_days = 90  # Delete old versions after 90 days
    }

    # Transition old versions to cheaper storage
    noncurrent_version_transition {
      noncurrent_days = 30
      storage_class   = "STANDARD_IA"
    }

    noncurrent_version_transition {
      noncurrent_days = 60
      storage_class   = "GLACIER"
    }
  }
}
```

#### Step 3: Apply Changes
```bash
cd terraform
terraform apply
```

### Usage Examples
```bash
# List all versions of an object
aws s3api list-object-versions --bucket bucket-name --prefix document.pdf

# Restore a previous version
aws s3api copy-object \
  --copy-source bucket-name/document.pdf?versionId=VERSION_ID \
  --bucket bucket-name \
  --key document.pdf
```

---

## 3. Lifecycle Policies

### Benefits
- **Cost Optimization**: Automatic transition to cheaper storage classes
- **Automated Cleanup**: Remove old or incomplete uploads
- **Compliance**: Automated data retention policies
- **Storage Management**: Reduce storage costs by up to 80%

### Implementation Steps

#### Step 1: Comprehensive Lifecycle Policy
Add to `terraform/s3.tf`:

```hcl
# Comprehensive lifecycle policy
resource "aws_s3_bucket_lifecycle_configuration" "openwebui_docs_lifecycle" {
  bucket = aws_s3_bucket.openwebui_docs.id

  rule {
    id     = "document_lifecycle"
    status = "Enabled"

    # Apply to all objects
    filter {}

    # Transition to Infrequent Access after 30 days
    transition {
      days          = 30
      storage_class = "STANDARD_IA"
    }

    # Transition to Glacier after 90 days
    transition {
      days          = 90
      storage_class = "GLACIER"
    }

    # Transition to Deep Archive after 365 days
    transition {
      days          = 365
      storage_class = "DEEP_ARCHIVE"
    }

    # Optional: Delete objects after 7 years (adjust as needed)
    # expiration {
    #   days = 2555  # 7 years
    # }
  }

  rule {
    id     = "cleanup_incomplete_uploads"
    status = "Enabled"

    # Clean up incomplete multipart uploads after 7 days
    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }
  }

  rule {
    id     = "delete_markers_cleanup"
    status = "Enabled"

    # Remove delete markers with no non-current versions
    expiration {
      expired_object_delete_marker = true
    }
  }
}
```

#### Step 2: Tag-Based Lifecycle (Optional)
```hcl
# Lifecycle rule based on object tags
rule {
  id     = "temporary_files"
  status = "Enabled"

  filter {
    tag {
      key   = "Type"
      value = "Temporary"
    }
  }

  expiration {
    days = 30  # Delete temporary files after 30 days
  }
}
```

### Storage Class Cost Comparison
| Storage Class | Cost (per GB/month) | Retrieval Time | Use Case |
|---------------|-------------------|----------------|----------|
| Standard | $0.023 | Immediate | Frequently accessed |
| Standard-IA | $0.0125 | Immediate | Infrequently accessed |
| Glacier | $0.004 | 1-5 minutes | Archive |
| Deep Archive | $0.00099 | 12 hours | Long-term archive |

---

## 4. S3 Access Logging

### Benefits
- **Security Monitoring**: Track all access attempts
- **Compliance**: Meet audit requirements
- **Troubleshooting**: Debug access issues
- **Usage Analytics**: Understand access patterns
- **Incident Response**: Forensic analysis capabilities

### Implementation Steps

#### Step 1: Create Logging Bucket
Add to `terraform/s3.tf`:

```hcl
# S3 bucket for access logs
resource "aws_s3_bucket" "openwebui_access_logs" {
  bucket_prefix = "${var.name}-openwebui-access-logs-"
  force_destroy = true

  tags = {
    Name = "${var.name}-openwebui-access-logs"
    Purpose = "S3 access logging"
  }
}

# Block public access to logs bucket
resource "aws_s3_bucket_public_access_block" "openwebui_access_logs" {
  bucket = aws_s3_bucket.openwebui_access_logs.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Encrypt access logs
resource "aws_s3_bucket_server_side_encryption_configuration" "openwebui_access_logs" {
  bucket = aws_s3_bucket.openwebui_access_logs.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# Lifecycle policy for access logs
resource "aws_s3_bucket_lifecycle_configuration" "openwebui_access_logs_lifecycle" {
  bucket = aws_s3_bucket.openwebui_access_logs.id

  rule {
    id     = "access_logs_retention"
    status = "Enabled"

    # Transition to IA after 30 days
    transition {
      days          = 30
      storage_class = "STANDARD_IA"
    }

    # Delete logs after 1 year (adjust as needed)
    expiration {
      days = 365
    }
  }
}
```

#### Step 2: Enable Access Logging
```hcl
# Enable access logging on the main bucket
resource "aws_s3_bucket_logging" "openwebui_docs_logging" {
  bucket = aws_s3_bucket.openwebui_docs.id

  target_bucket = aws_s3_bucket.openwebui_access_logs.id
  target_prefix = "access-logs/"
}
```

#### Step 3: CloudWatch Integration (Optional)
```hcl
# CloudWatch Log Group for S3 access analysis
resource "aws_cloudwatch_log_group" "s3_access_analysis" {
  name              = "/aws/s3/${var.name}-openwebui-access-analysis"
  retention_in_days = 30

  tags = local.tags
}

# Lambda function for log processing (example)
resource "aws_lambda_function" "s3_log_processor" {
  filename         = "s3_log_processor.zip"
  function_name    = "${var.name}-s3-log-processor"
  role            = aws_iam_role.lambda_role.arn
  handler         = "index.handler"
  runtime         = "python3.9"

  # Lambda code would process S3 access logs and send alerts
  # for suspicious activity (multiple failed access attempts, etc.)
}
```

### Log Analysis Examples

#### Analyze Access Patterns
```bash
# Download and analyze access logs
aws s3 sync s3://your-access-logs-bucket/access-logs/ ./logs/

# Count requests by IP
cat logs/*.log | awk '{print $3}' | sort | uniq -c | sort -nr

# Find failed requests
cat logs/*.log | grep ' 4[0-9][0-9] \| 5[0-9][0-9] '

# Analyze request types
cat logs/*.log | awk '{print $6}' | sort | uniq -c
```

#### CloudWatch Insights Queries
```sql
-- Top IP addresses by request count
fields @timestamp, remote_ip, request_uri
| stats count() by remote_ip
| sort count desc
| limit 10

-- Failed requests analysis
fields @timestamp, remote_ip, status, request_uri
| filter status >= 400
| stats count() by status, remote_ip
| sort count desc
```

---

## 5. Monitoring and Alerting

### CloudWatch Metrics
```hcl
# CloudWatch alarm for unusual S3 activity
resource "aws_cloudwatch_metric_alarm" "s3_high_error_rate" {
  alarm_name          = "${var.name}-s3-high-error-rate"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "4xxErrors"
  namespace           = "AWS/S3"
  period              = "300"
  statistic           = "Sum"
  threshold           = "10"
  alarm_description   = "This metric monitors S3 4xx errors"

  dimensions = {
    BucketName = aws_s3_bucket.openwebui_docs.id
  }

  alarm_actions = [aws_sns_topic.alerts.arn]
}

# SNS topic for alerts
resource "aws_sns_topic" "alerts" {
  name = "${var.name}-s3-alerts"
}
```

---

## Implementation Checklist

### Phase 1: Core Security (Already Implemented ✅)
- [x] VPC Endpoint for private access
- [x] Pod Identity for secure authentication
- [x] Public access block
- [x] Basic server-side encryption
- [x] Bucket policy with VPC restrictions

### Phase 2: Enhanced Security (Choose based on requirements)
- [ ] **KMS Customer-Managed Encryption** (High security environments)
- [ ] **S3 Bucket Versioning** (Data protection requirements)
- [ ] **Lifecycle Policies** (Cost optimization)
- [ ] **Access Logging** (Compliance/audit requirements)
- [ ] **CloudWatch Monitoring** (Operational visibility)

### Phase 3: Advanced Features (Optional)
- [ ] **Cross-Region Replication** (Disaster recovery)
- [ ] **S3 Object Lock** (Compliance hold)
- [ ] **S3 Inventory** (Large-scale management)
- [ ] **S3 Analytics** (Usage optimization)

---

## Cost Impact Analysis

| Feature | Monthly Cost Impact | Benefits |
|---------|-------------------|----------|
| VPC Endpoint | $0 (Gateway endpoint) | Security, performance |
| KMS Encryption | ~$1-5 | Enhanced security |
| Versioning | 10-50% storage increase | Data protection |
| Lifecycle Policies | 50-80% storage savings | Cost optimization |
| Access Logging | 5-10% additional storage | Compliance, monitoring |

---

## Security Best Practices Summary

1. **Defense in Depth**: Multiple security layers (network + identity + encryption)
2. **Least Privilege**: Minimal required permissions only
3. **Encryption Everywhere**: At rest and in transit
4. **Monitoring**: Comprehensive logging and alerting
5. **Automation**: Lifecycle policies for cost and compliance
6. **Regular Reviews**: Periodic access and policy audits

---

## Troubleshooting Common Issues

### VPC Endpoint Issues
```bash
# Test VPC endpoint connectivity
aws s3 ls --region ap-southeast-3 --endpoint-url https://s3.ap-southeast-3.amazonaws.com

# Check route tables
aws ec2 describe-route-tables --filters "Name=vpc-id,Values=vpc-xxxxxx"
```

### Pod Identity Issues
```bash
# Check service account annotations
kubectl describe sa open-webui-pia -n vllm-inference

# Test AWS credentials in pod
kubectl exec -it pod-name -n vllm-inference -- aws sts get-caller-identity
```

### Access Denied Errors
1. Check bucket policy conditions
2. Verify VPC endpoint ID in policy
3. Confirm Pod Identity role ARN
4. Test with AWS CLI using same role

This comprehensive guide provides you with enterprise-grade S3 security options that can be implemented based on your specific requirements and compliance needs.
