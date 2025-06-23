variable "name" {
  description = "Name of the VPC and EKS Cluster"
  default     = "automode-cluster"
  type        = string
}

variable "region" {
  description = "region"
  default     = "ap-southeast-3" 
  type        = string
}

variable "eks_cluster_version" {
  description = "EKS Cluster version"
  default     = "1.31"
  type        = string
}

# VPC with 65536 IPs (10.0.0.0/16) for 3 AZs
variable "vpc_cidr" {
  description = "VPC CIDR. This should be a valid private (RFC 1918) CIDR range"
  default     = "10.0.0.0/16"
  type        = string
}

variable "enable_kubecost" {
  description = "Enable KubeCost EKS add-on for Kubernetes-native cost monitoring (free standard bundle)"
  type        = bool
  default     = false
}

# Multi-tenant configuration
variable "tenants" {
  description = "Map of tenant configurations for multi-tenant OpenWebUI setup"
  type = map(object({
    name      = string
    namespace = string
  }))
  default = {
    legal = {
      name      = "legal"
      namespace = "legal-webui"
    }
    hr = {
      name      = "hr"
      namespace = "hr-webui"
    }
    us = {
      name      = "us"
      namespace = "us-webui"
    }
  }
}
