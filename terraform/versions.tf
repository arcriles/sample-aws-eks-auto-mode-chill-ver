terraform {
  required_version = ">= 1.3"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.34"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = ">= 2.10"
    }
    helm = {
      source  = "hashicorp/helm"
      version = ">= 2.9"
    }
    null = {
      source  = "hashicorp/null"
      version = ">= 3.1"
    }
    random = {
      source  = "hashicorp/random"
      version = ">= 3.5"
    }
  }
  backend "s3" {
    bucket         = var.remote_state_bucket     # Your S3 bucket name
    key            = "state/terraform.tfstate"   # Path within the bucket
    region         = var.region                  # Bucket region
    encrypt        = true                        # Enable encryption
  }
}
