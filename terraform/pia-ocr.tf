module "bda_pod_identity" {
  source = "terraform-aws-modules/eks-pod-identity/aws"
  name = "bda-workflow-gar"
  attach_custom_policy = true
  policy_statements = [
    {
      sid = "S3BDAAccess"
      actions = [
        "s3:GetObject",
        "s3:PutObject",
        "s3:DeleteObject",
        "s3:ListBucket"
      ]
      resources = [
        "arn:aws:s3:::bda-multimodal-rag",
        "arn:aws:s3:::bda-multimodal-rag/*"
      ]
    },
    {
      sid = "BedrockFullAccess"
      actions = [
        "bedrock:*"
      ]
      resources = ["*"]
    }
  ]
  associations = {
    bda_workflow = {
      service_account = "bda-workflow-sa"
      namespace       = "gar-webui"
      cluster_name    = module.eks.cluster_name
    }
  }
  tags = merge(local.tags, {
    Environment = var.name
    Application = "bda-workflow"
  })

}
