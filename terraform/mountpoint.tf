# ################################################################################
# # Mountpoint for Amazon S3 CSI Driver Configuration
# ################################################################################

# # S3 buckets for pipeline persistence - one per tenant
# resource "aws_s3_bucket" "pipelines_storage" {
#   for_each = var.tenants
#   bucket   = "${var.name}-${each.key}-pipelines-storage"
#   tags     = local.tags
# }

# # Block public access to the pipeline S3 buckets
# resource "aws_s3_bucket_public_access_block" "pipelines_storage" {
#   for_each = var.tenants
#   bucket   = aws_s3_bucket.pipelines_storage[each.key].id

#   block_public_acls       = true
#   block_public_policy     = true
#   ignore_public_acls      = true
#   restrict_public_buckets = true
# }

# # Enable server-side encryption for the pipeline S3 buckets
# resource "aws_s3_bucket_server_side_encryption_configuration" "pipelines_storage" {
#   for_each = var.tenants
#   bucket   = aws_s3_bucket.pipelines_storage[each.key].id

#   rule {
#     apply_server_side_encryption_by_default {
#       sse_algorithm = "AES256"
#     }
#   }
# }

# # IAM policy for Mountpoint CSI driver access to pipeline buckets - per tenant
# resource "aws_iam_policy" "mountpoint_pipelines_policy" {
#   for_each = var.tenants
#   name     = "${var.name}-${each.key}-mountpoint-pipelines-policy"
  
#   policy = jsonencode({
#     Version = "2012-10-17"
#     Statement = [
#       {
#         Sid    = "MountpointFullBucketAccess"
#         Effect = "Allow"
#         Action = ["s3:ListBucket"]
#         Resource = [aws_s3_bucket.pipelines_storage[each.key].arn]
#       },
#       {
#         Sid    = "MountpointFullObjectAccess"
#         Effect = "Allow"
#         Action = [
#           "s3:GetObject",
#           "s3:PutObject", 
#           "s3:AbortMultipartUpload",
#           "s3:DeleteObject"
#         ]
#         Resource = ["${aws_s3_bucket.pipelines_storage[each.key].arn}/*"]
#       }
#     ]
#   })

#   tags = local.tags
# }

# # IAM role for Mountpoint CSI driver (system-level)
# resource "aws_iam_role" "mountpoint_s3_csi_driver_role" {
#   name = "${var.name}-mountpoint-s3-csi-driver-role"

#   assume_role_policy = jsonencode({
#     Version = "2012-10-17"
#     Statement = [
#       {
#         Effect = "Allow"
#         Principal = {
#           Federated = module.eks.oidc_provider_arn
#         }
#         Action = "sts:AssumeRoleWithWebIdentity"
#         Condition = {
#           StringEquals = {
#             "${replace(module.eks.cluster_oidc_issuer_url, "https://", "")}:sub" = "system:serviceaccount:kube-system:s3-csi-driver-sa"
#             "${replace(module.eks.cluster_oidc_issuer_url, "https://", "")}:aud" = "sts.amazonaws.com"
#           }
#         }
#       }
#     ]
#   })

#   tags = local.tags
# }

# # Attach all tenant policies to the CSI driver role
# resource "aws_iam_role_policy_attachment" "mountpoint_csi_driver_policies" {
#   for_each   = var.tenants
#   role       = aws_iam_role.mountpoint_s3_csi_driver_role.name
#   policy_arn = aws_iam_policy.mountpoint_pipelines_policy[each.key].arn
# }

# # IAM roles for pipeline service accounts - per tenant (OIDC-based)
# resource "aws_iam_role" "pipelines_service_account_role" {
#   for_each = var.tenants
#   name     = "${var.name}-${each.key}-pipelines-sa-role"

#   assume_role_policy = jsonencode({
#     Version = "2012-10-17"
#     Statement = [
#       {
#         Effect = "Allow"
#         Principal = {
#           Federated = module.eks.oidc_provider_arn
#         }
#         Action = "sts:AssumeRoleWithWebIdentity"
#         Condition = {
#           StringEquals = {
#             "${replace(module.eks.cluster_oidc_issuer_url, "https://", "")}:sub" = "system:serviceaccount:${each.value.namespace}:pipelines-${each.key}-sa"
#             "${replace(module.eks.cluster_oidc_issuer_url, "https://", "")}:aud" = "sts.amazonaws.com"
#           }
#         }
#       }
#     ]
#   })

#   tags = local.tags
# }

# # Attach the Mountpoint policy to pipeline service account roles
# resource "aws_iam_role_policy_attachment" "pipelines_sa_mountpoint_policy" {
#   for_each   = var.tenants
#   role       = aws_iam_role.pipelines_service_account_role[each.key].name
#   policy_arn = aws_iam_policy.mountpoint_pipelines_policy[each.key].arn
# }

# # EKS add-on for Mountpoint CSI driver
# resource "aws_eks_addon" "mountpoint_s3_csi" {
#   cluster_name             = module.eks.cluster_name
#   addon_name              = "aws-mountpoint-s3-csi-driver"
#   addon_version           = "v1.8.0-eksbuild.1"
#   service_account_role_arn = aws_iam_role.mountpoint_s3_csi_driver_role.arn
  
#   resolve_conflicts_on_create = "OVERWRITE"
#   resolve_conflicts_on_update = "OVERWRITE"

#   depends_on = [
#     module.eks,
#     aws_iam_role.mountpoint_s3_csi_driver_role
#   ]

#   tags = local.tags
# }

# # S3 Bucket Policy for VPC Endpoint Security - per tenant (pipelines)
# resource "aws_s3_bucket_policy" "pipelines_storage_policy" {
#   for_each = var.tenants
#   bucket   = aws_s3_bucket.pipelines_storage[each.key].id

#   policy = jsonencode({
#     Version = "2012-10-17"
#     Statement = [
#       {
#         Sid    = "AllowVPCEndpointAccess"
#         Effect = "Allow"
#         Principal = "*"
#         Action = [
#           "s3:GetObject",
#           "s3:PutObject",
#           "s3:DeleteObject",
#           "s3:ListBucket",
#           "s3:AbortMultipartUpload"
#         ]
#         Resource = [
#           aws_s3_bucket.pipelines_storage[each.key].arn,
#           "${aws_s3_bucket.pipelines_storage[each.key].arn}/*"
#         ]
#         Condition = {
#           StringEquals = {
#             "aws:sourceVpce" = aws_vpc_endpoint.s3.id
#           }
#         }
#       },
#       {
#         Sid    = "AllowServiceAccountAccess"
#         Effect = "Allow"
#         Principal = {
#           AWS = aws_iam_role.pipelines_service_account_role[each.key].arn
#         }
#         Action = [
#           "s3:GetObject",
#           "s3:PutObject",
#           "s3:DeleteObject",
#           "s3:ListBucket",
#           "s3:AbortMultipartUpload"
#         ]
#         Resource = [
#           aws_s3_bucket.pipelines_storage[each.key].arn,
#           "${aws_s3_bucket.pipelines_storage[each.key].arn}/*"
#         ]
#       },
#       {
#         Sid    = "DenyInsecureConnections"
#         Effect = "Deny"
#         Principal = "*"
#         Action = "s3:*"
#         Resource = [
#           aws_s3_bucket.pipelines_storage[each.key].arn,
#           "${aws_s3_bucket.pipelines_storage[each.key].arn}/*"
#         ]
#         Condition = {
#           Bool = {
#             "aws:SecureTransport" = "false"
#           }
#         }
#       }
#     ]
#   })

#   depends_on = [
#     aws_s3_bucket_public_access_block.pipelines_storage
#   ]
# }
