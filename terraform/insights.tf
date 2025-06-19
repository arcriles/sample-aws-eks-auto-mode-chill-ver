# IAM role for CloudWatch agent with EKS Pod Identity
resource "aws_iam_role" "cloudwatch_agent" {
  name = "${var.name}-cloudwatch-agent-role"
  
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "sts:AssumeRole",
          "sts:TagSession"
        ]
        Effect = "Allow"
        Principal = {
          Service = "pods.eks.amazonaws.com"
        }
      }
    ]
  })

  tags = local.tags
}

# Attach the required CloudWatchAgentServerPolicy
resource "aws_iam_role_policy_attachment" "cloudwatch_agent_policy" {
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
  role       = aws_iam_role.cloudwatch_agent.name
}

# Amazon CloudWatch Observability EKS add-on with built-in Pod Identity
resource "aws_eks_addon" "amazon_cloudwatch_observability" {
  cluster_name  = module.eks.cluster_name
  addon_name    = "amazon-cloudwatch-observability"
  addon_version = "v4.1.0-eksbuild.1"  # Add this line
  
  # Disable container logs to optimize costs while keeping Container Insights metrics
  configuration_values = jsonencode({
    containerLogs = {
      enabled = false
    }
  })
  
  pod_identity_association {
    role_arn        = aws_iam_role.cloudwatch_agent.arn
    service_account = "cloudwatch-agent"
  }
  
  tags = local.tags
}
# KubeCost EKS Add-on (Optional - Free Standard Bundle)
resource "aws_eks_addon" "kubecost" {
  count         = var.enable_kubecost ? 1 : 0
  cluster_name  = module.eks.cluster_name
  addon_name    = "kubecost_kubecost"
  addon_version = "v1.97.0-eksbuild.1"
  
  tags = local.tags
}
