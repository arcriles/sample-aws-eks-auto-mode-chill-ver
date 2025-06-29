# LiteLLM Setup

> **🔄 Integration Component**: Multi-provider AI gateway deployed before OpenWebUI for automatic integration  
> **Prerequisites**: ✅ Infrastructure Setup, ✅ Custom Image Build

## Setup Flow
- **Previous**: [Custom Image Build](../build-custom-image/)
- **Current**: LiteLLM Gateway Setup
- **Next**: Choose your path:
  - **Optional**: [Web Search](../setup-searxng/) - HR tenant only, then [Multi-Tenant OpenWebUI](../setup-openwebui/)
  - **Direct**: [Multi-Tenant OpenWebUI](../setup-openwebui/)

## Overview

This directory contains the configuration files and deployment manifests for setting up LiteLLM as a multi-provider AI gateway on EKS Auto Mode. LiteLLM provides a unified interface to access multiple LLM providers, cost tracking, rate limiting, and caching capabilities.

## Why LiteLLM Comes First

LiteLLM is deployed **before OpenWebUI** to enable **automatic integration**:

✅ **Automatic Connection**: OpenWebUI automatically discovers and connects to LiteLLM service  
✅ **Pre-configured Models**: All LiteLLM models are immediately available in OpenWebUI  
✅ **Seamless Setup**: No manual configuration required in OpenWebUI admin panel  
✅ **Consistent Configuration**: All tenants get the same LiteLLM integration automatically  
✅ **Zero Downtime**: Models are ready when OpenWebUI starts up

## Architecture

LiteLLM is deployed with the following components:

- **LiteLLM Gateway**: Main proxy service that routes requests to different LLM providers
- **PostgreSQL (RDS)**: Stores LiteLLM configuration, user management, and usage tracking
- **AWS Secrets Manager**: Securely stores database credentials and API keys
- **External Secrets Operator**: Syncs secrets from AWS Secrets Manager to Kubernetes

> **Note**: Redis/ElastiCache caching has been disabled as most cloud providers (OpenAI, Azure OpenAI, Anthropic, etc.) now provide built-in prompt caching, making additional caching layers redundant.

## Prerequisites

Before deploying LiteLLM, ensure you have:

1. ✅ **Completed**: Main Terraform infrastructure deployment ([see main README](../README.md))
2. ✅ **Completed**: Custom image build ([see Custom Image README](../build-custom-image/))
3. ✅ **Completed**: Shared components setup (storage class, ClusterSecretStore, Apache Tika)

> **Note**: LiteLLM is deployed **before** OpenWebUI tenants to enable automatic integration. The shared components from the OpenWebUI setup directory should be deployed first.

## Deployment Steps

### 1. Navigate to LiteLLM Directory

```bash
cd setup-litellm
```

### 2. (Optional) Add External Provider API Keys

If you want to use external providers (Azure OpenAI, OpenAI, Anthropic, etc.):

```bash
# Update API keys in AWS Secrets Manager
chmod +x update-secrets.sh
./update-secrets.sh
```

This script will:
- Read API keys from your `.env` file (created in the main directory)
- Update the AWS Secrets Manager secret with your keys
- The External Secrets Operator will automatically sync these to Kubernetes

> **Note**: You can run this script anytime to update API keys without redeploying.

### 3. Deploy Kubernetes Resources

Deploy the resources in the following order:

```bash
# Create namespace
kubectl apply -f namespace.yaml

# Create service account with Pod Identity
kubectl apply -f serviceaccount.yaml

# Apply External Secrets to fetch credentials from AWS Secrets Manager
# Note: ClusterSecretStore already exists from OpenWebUI setup
kubectl apply -f secret.yaml

# Create ConfigMap with LiteLLM configuration
kubectl apply -f configmap.yaml

# Deploy LiteLLM application
kubectl apply -f deployment.yaml

# Create service
kubectl apply -f service.yaml

# Create ingress for external access (uses EKS Auto Mode format)
kubectl apply -f ingress.yaml
```

> **Note**: The ClusterSecretStore (`aws-secretsmanager`) was already created during OpenWebUI setup and is shared between both applications.

### 3. Verify Deployment

Check that all components are running:

```bash
# Check pods
kubectl get pods -n litellm

# Check services
kubectl get svc -n litellm

# Check ingress and IngressClass
kubectl get ingress -n litellm
kubectl get ingressclass -n litellm

# Check secrets (should be populated by External Secrets Operator)
kubectl get secrets -n litellm
```

### 4. Get Access URL

Get the ALB URL for accessing LiteLLM:

```bash
# Wait for ALB to be provisioned (may take a few minutes)

# Get the load balancer URL
export LB_URL=$(kubectl get ingress litellm-ingress -n litellm -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')

# Display the URL
echo "LiteLLM is available at: http://$LB_URL"
```

Click on the *LiteLLM Admin Panel on /ui* hyperlink. 

Login Details:
```bash
echo "Username: admin"
echo "Password: $(kubectl get secret litellm-master-salt -n litellm -o jsonpath='{.data.LITELLM_MASTER_KEY}' | base64 -d)"
```

## Usage

### Basic API Usage

Once deployed, you can use LiteLLM's OpenAI-compatible API:

```bash
# Get the master key from secrets
MASTER_KEY=$(kubectl get secret litellm-master-salt -n litellm -o jsonpath='{.data.LITELLM_MASTER_KEY}' | base64 -d)

# Make a request to the deepseek model through LiteLLM
curl -X POST "http://$LB_URL/v1/chat/completions" \
  -H "Authorization: Bearer $MASTER_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "model": "deepseek",
    "messages": [{"role": "user", "content": "Hello, how are you?"}]
  }'
```

### Integration with OpenWebUI

To use LiteLLM as a proxy for OpenWebUI:

```bash
# Get the LiteLLM master key
MASTER_KEY=$(kubectl get secret litellm-master-salt -n litellm -o jsonpath='{.data.LITELLM_MASTER_KEY}' | base64 -d)
```

Go to settings --> admin settings --> Go to connections --> Create a new OpenAI API Connection

Use the following values:
```bash
echo "URL: http://litellm-service.litellm.svc.cluster.local:4000/v1"
echo "API Key: $MASTER_KEY"
```

Now go create a new chat and you should have new model.
- deepseek is the deepseek model via litellm
- deepseek-ai/DeepSeek-R1-Distill-Qwen-32B is the mdoel directly served by vLLM

## Security Considerations

- All database credentials are stored in AWS Secrets Manager
- Pod Identity is used for secure access to AWS services
- PostgreSQL uses encryption in transit and at rest
- API keys for external providers are managed through AWS Secrets Manager
- ClusterSecretStore is shared securely between OpenWebUI and LiteLLM
- No Redis credentials stored in ConfigMaps (security improvement)

## Cost Optimization

- PostgreSQL uses `db.t3.micro` instance class for cost efficiency
- No ElastiCache costs (Redis removed)
- Consider adjusting PostgreSQL instance size based on your usage patterns
- Monitor costs through LiteLLM's built-in usage tracking
- Reduced infrastructure complexity = lower operational costs

## Cleanup

To remove LiteLLM resources:

```bash
# Delete Kubernetes resources
kubectl delete -f ingress.yaml
kubectl delete -f service.yaml
kubectl delete -f deployment.yaml
kubectl delete -f configmap.yaml
kubectl delete -f secret.yaml
kubectl delete -f serviceaccount.yaml
kubectl delete -f namespace.yaml

# Remove AWS infrastructure (from terraform directory)
cd ../terraform
# Note: ElastiCache resources are commented out, no need to destroy
# terraform destroy -target=aws_elasticache_replication_group.litellm_redis
terraform destroy -target=aws_db_instance.litellm_postgres
terraform destroy -target=aws_secretsmanager_secret.litellm_master_salt
terraform destroy -target=aws_secretsmanager_secret.litellm_api_keys
```

## Completion

🎉 **LiteLLM Setup Complete!** You now have a multi-provider AI gateway with:

- **Multi-Provider Access**: Route requests to different LLM providers
- **Cost Tracking**: Monitor usage and costs across providers
- **Usage Analytics**: Track and analyze API usage
- **🤖 Ready for OpenWebUI Integration**: Service is ready for automatic discovery

## Next Steps

Choose your deployment path:

### **Option 1: Direct to OpenWebUI** (Recommended for most users)
**👉 Next: [Setup Multi-Tenant OpenWebUI](../setup-openwebui/)**

OpenWebUI will automatically:
- Discover the LiteLLM service
- Configure all models for immediate use
- Enable multi-provider AI access across all tenants

### **Option 2: Add Web Search First** (HR Enhanced Path)
**👉 Next: [Setup SearXNG](../setup-searxng/)** → Then [Setup OpenWebUI](../setup-openwebui/)

This path adds web search capabilities for the HR tenant before deploying OpenWebUI.

Both paths result in OpenWebUI tenants with automatic LiteLLM integration - no manual configuration required!

## Support

For issues and questions:
- Check the [LiteLLM documentation](https://docs.litellm.ai/)
- Review logs using the troubleshooting steps above
- Ensure all prerequisites are met
- Verify the sequential setup flow was followed
