#!/bin/bash

# =============================================================================
# Multi-Tenant AI Platform Deployment Script
# Based on sample-aws-eks-auto-mode project
# =============================================================================

set -e  # Exit on any error

# =============================================================================
# PARAMETER HANDLING
# =============================================================================

# Check if hugging-face-token is provided as argument
HF_TOKEN=""
DEPLOY_VLLM=false

if [ $# -eq 1 ]; then
    HF_TOKEN="$1"
    DEPLOY_VLLM=true
    echo "🤖 vLLM deployment enabled with provided Hugging Face token"
elif [ $# -gt 1 ]; then
    echo "❌ Error: Too many arguments provided"
    echo "Usage: $0 [hugging-face-token]"
    echo "  - No arguments: Deploy without vLLM inference service"
    echo "  - With token: Deploy with vLLM inference service"
    exit 1
fi

echo "🚀 Starting Multi-Tenant AI Platform Deployment..."
echo "📅 Started at: $(date)"

# Check if we're in the correct directory structure
# First check if we're already in the sample-aws-eks-auto-mode directory
if [ -d "terraform" ] && [ -d "setup-openwebui" ] && [ -d "setup-searxng" ] && [ -d "setup-litellm" ] && [ -d "setup-o11y" ]; then
    echo "✅ Already in sample-aws-eks-auto-mode directory"
    echo "📁 Current directory: $(pwd)"
elif [ -d "sample-aws-eks-auto-mode" ]; then
    echo "✅ Found sample-aws-eks-auto-mode directory, navigating to it..."
    cd sample-aws-eks-auto-mode
    echo "📁 Current directory: $(pwd)"
else
    echo "❌ Error: sample-aws-eks-auto-mode directory structure not found"
    echo "Please run this script from either:"
    echo "  1. Inside the sample-aws-eks-auto-mode directory, or"
    echo "  2. From the directory containing sample-aws-eks-auto-mode"
    exit 1
fi

# Verify all required subdirectories exist
for dir in terraform setup-openwebui setup-searxng setup-litellm setup-o11y; do
    if [ ! -d "$dir" ]; then
        echo "❌ Error: Required directory '$dir' not found"
        exit 1
    fi
done

echo "✅ All required directories found"

# =============================================================================
# REGION VALIDATION
# =============================================================================

echo ""
echo "🌍 === VALIDATING AWS REGION ==="

# Check current AWS region configuration
CURRENT_REGION=$(aws configure get region 2>/dev/null)
EXPECTED_REGION="ap-southeast-3"

echo "Current AWS CLI region: ${CURRENT_REGION:-<not set>}"
echo "Expected region: $EXPECTED_REGION"

if [ "$CURRENT_REGION" != "$EXPECTED_REGION" ]; then
    echo "❌ Error: AWS CLI region mismatch!"
    echo ""
    echo "This deployment script is designed for the ap-southeast-3 region."
    echo "Your AWS CLI is configured for: ${CURRENT_REGION:-<not set>}"
    echo ""
    echo "Please run the following command to set the correct region:"
    echo "  aws configure set region $EXPECTED_REGION"
    echo ""
    echo "Then re-run this script."
    exit 1
fi

echo "✅ AWS region validation passed"

# =============================================================================
# INFRASTRUCTURE SETUP
# =============================================================================

echo ""
echo "🏗️ === SETTING UP INFRASTRUCTURE ==="

# Navigate to Terraform directory
cd terraform

echo "📍 Current directory: $(pwd)"

# Initialize and apply Terraform
echo "🔧 Initializing Terraform..."
terraform init

echo "🚀 Applying Terraform configuration..."
terraform apply -auto-approve

# Configure kubectl
echo "⚙️ Configuring kubectl..."
$(terraform output -raw configure_kubectl)

echo "✅ Infrastructure setup completed"

# =============================================================================
# SHARED COMPONENTS SETUP
# =============================================================================

echo ""
echo "🔧 === SETTING UP SHARED COMPONENTS ==="

cd ../setup-openwebui

echo "📍 Current directory: $(pwd)"

# Deploy shared storage class
echo "💾 Deploying shared storage class..."
kubectl apply -f shared/sc.yaml

# Deploy shared ClusterSecretStore (External Secrets Operator)
echo "🔐 Deploying ClusterSecretStore..."
kubectl apply -f shared/cluster-secret-store.yaml

# Create vllm-inference namespace
echo "📦 Creating vllm-inference namespace..."
kubectl apply -f shared/namespace.yaml

# Deploy Apache Tika for document processing (shared across all tenants)
echo "📄 Adding Tika Helm repository..."
helm repo add tika https://apache.jfrog.io/artifactory/tika
helm repo update

echo "🚀 Deploying Apache Tika..."
helm upgrade --install tika tika/tika -f shared/tika-values.yaml -n vllm-inference

# =============================================================================
# VLLM INFERENCE SERVICE SETUP (OPTIONAL)
# =============================================================================

if [ "$DEPLOY_VLLM" = true ]; then
    echo ""
    echo "🤖 === SETTING UP VLLM INFERENCE SERVICE ==="
    
    # Create Hugging Face secret with provided token
    echo "🔑 Creating Hugging Face secret..."
    kubectl create secret generic hf-secret -n vllm-inference --from-literal=hf_api_token="$HF_TOKEN" --dry-run=client -o yaml | kubectl apply -f -
    
    # Deploy GPU nodepool for vLLM
    echo "🖥️ Deploying GPU nodepool..."
    kubectl apply -f ../nodepools/gpu-nodepool.yaml
    
    # Deploy vLLM inference service
    echo "🚀 Deploying vLLM inference service..."
    kubectl apply -f shared/llm.yaml
    
    echo "✅ vLLM inference service setup completed"
else
    echo "ℹ️ Skipping vLLM deployment (no Hugging Face token provided)"
fi

echo "✅ Shared components setup completed"

# =============================================================================
# LITELLM SETUP
# =============================================================================

echo ""
echo "🔄 === SETTING UP LITELLM ==="

cd ../setup-litellm

echo "📍 Current directory: $(pwd)"

# Update API keys in AWS Secrets Manager
echo "🔑 Updating API keys in AWS Secrets Manager..."
chmod +x update-secrets.sh
./update-secrets.sh || echo "⚠️ API keys update failed, continuing with default configuration..."

# Create namespace
echo "📦 Creating LiteLLM namespace..."
kubectl apply -f namespace.yaml

# Create service account with Pod Identity
echo "👤 Creating service account..."
kubectl apply -f serviceaccount.yaml

# Apply External Secrets to fetch credentials from AWS Secrets Manager
echo "🔐 Applying External Secrets..."
kubectl apply -f secret.yaml

# Create ConfigMap with LiteLLM configuration
echo "⚙️ Creating ConfigMap..."
kubectl apply -f configmap.yaml

# Deploy LiteLLM application
echo "🚀 Deploying LiteLLM application..."
kubectl apply -f deployment.yaml

# Create service
echo "🌐 Creating service..."
kubectl apply -f service.yaml

# Create ingress for external access (uses EKS Auto Mode format)
echo "🌍 Creating ingress..."
kubectl apply -f ingress.yaml

echo "✅ LiteLLM setup completed"

# =============================================================================
# SEARXNG SETUP
# =============================================================================

echo ""
echo "🔍 === SETTING UP SEARXNG (HR TENANT ONLY) ==="

cd ../setup-searxng

echo "📍 Current directory: $(pwd)"

# Enable Network Policy Controller in AWS VPC CNI
echo "🛡️ Enabling Network Policy Controller..."
kubectl apply -f enable-network-policy.yaml

# Wait for VPC CNI pods to restart (critical for network policies to work)
echo "⏳ Waiting for VPC CNI pods to restart (120 seconds)..."
sleep 120

# Add the SearXNG Helm repository
echo "📦 Adding SearXNG Helm repository..."
helm repo add searxng https://charts.searxng.org
helm repo update

# Deploy Network Policies for SearXNG tenant isolation
echo "🛡️ Deploying Network Policies for tenant isolation..."
kubectl apply -f network-policies.yaml

# Deploy SearXNG with optimized configuration
echo "🚀 Deploying SearXNG..."
helm upgrade --install searxng searxng/searxng -f searxng-values.yaml -n vllm-inference

echo "✅ SearXNG setup completed"

# =============================================================================
# HR TENANT SETUP
# =============================================================================

echo ""
echo "👥 === SETTING UP HR TENANT ==="

cd ../setup-openwebui

echo "📍 Current directory: $(pwd)"

export TENANT=hr
export NAMESPACE=hr-webui

echo "🔐 Updating OAuth secrets for HR tenant..."
if [ -x "./update-oauth-secrets.sh" ]; then
    ./update-oauth-secrets.sh $TENANT || echo "⚠️ OAuth secrets update failed, continuing..."
else
    echo "⚠️ update-oauth-secrets.sh not found or not executable, skipping..."
fi

# Navigate to tenant directory
cd $TENANT

echo "📍 Current directory: $(pwd)"

# Deploy tenant namespace
echo "📦 Deploying HR tenant namespace..."
kubectl apply -f namespace.yaml

# Deploy tenant OAuth configuration
echo "🔐 Deploying OAuth configuration..."
kubectl apply -f oauth-config.yaml

# Deploy secrets and database setup (generated by Terraform)
echo "🔑 Deploying secrets..."
kubectl apply -f secret.yaml
kubectl apply -f oauth-secret.yaml

# Create the pgvector extension for this tenant's database
echo "🗄️ Creating pgvector extension..."
kubectl apply -f pgvector-job.yaml

# Add OpenWebUI Helm repository
echo "📦 Adding OpenWebUI Helm repository..."
helm repo add open-webui https://helm.openwebui.com/
helm repo update

# Deploy OpenWebUI for this tenant
echo "🚀 Deploying OpenWebUI for HR tenant..."
helm upgrade --install open-webui-$TENANT open-webui/open-webui -f values.yaml -n $NAMESPACE

# Deploy tenant-specific load balancer
echo "⚖️ Deploying load balancer..."
kubectl apply -f lb.yaml

echo "✅ HR tenant setup completed"

# =============================================================================
# LEGAL TENANT SETUP
# =============================================================================

echo ""
echo "👥 === SETTING UP LEGAL TENANT ==="

cd ..

echo "📍 Current directory: $(pwd)"

export TENANT=legal
export NAMESPACE=legal-webui

echo "🔐 Updating OAuth secrets for Legal tenant..."
if [ -x "./update-oauth-secrets.sh" ]; then
    ./update-oauth-secrets.sh $TENANT || echo "⚠️ OAuth secrets update failed, continuing..."
else
    echo "⚠️ update-oauth-secrets.sh not found or not executable, skipping..."
fi

# Navigate to tenant directory
cd $TENANT

echo "📍 Current directory: $(pwd)"

# Deploy tenant namespace
echo "📦 Deploying Legal tenant namespace..."
kubectl apply -f namespace.yaml

# Deploy tenant OAuth configuration
echo "🔐 Deploying OAuth configuration..."
kubectl apply -f oauth-config.yaml

# Deploy secrets and database setup (generated by Terraform)
echo "🔑 Deploying secrets..."
kubectl apply -f secret.yaml
kubectl apply -f oauth-secret.yaml

# Create the pgvector extension for this tenant's database
echo "🗄️ Creating pgvector extension..."
kubectl apply -f pgvector-job.yaml

# Deploy OpenWebUI for this tenant
echo "🚀 Deploying OpenWebUI for Legal tenant..."
helm upgrade --install open-webui-$TENANT open-webui/open-webui -f values.yaml -n $NAMESPACE

# Deploy tenant-specific load balancer
echo "⚖️ Deploying load balancer..."
kubectl apply -f lb.yaml

echo "✅ Legal tenant setup completed"

# =============================================================================
# US TENANT SETUP
# =============================================================================

echo ""
echo "👥 === SETTING UP US TENANT ==="

cd ..

echo "📍 Current directory: $(pwd)"

export TENANT=us
export NAMESPACE=us-webui

echo "🔐 Updating OAuth secrets for US tenant..."
if [ -x "./update-oauth-secrets.sh" ]; then
    ./update-oauth-secrets.sh $TENANT || echo "⚠️ OAuth secrets update failed, continuing..."
else
    echo "⚠️ update-oauth-secrets.sh not found or not executable, skipping..."
fi

# Navigate to tenant directory
cd $TENANT

echo "📍 Current directory: $(pwd)"

# Deploy tenant namespace
echo "📦 Deploying US tenant namespace..."
kubectl apply -f namespace.yaml

# Deploy tenant OAuth configuration
echo "🔐 Deploying OAuth configuration..."
kubectl apply -f oauth-config.yaml

# Deploy secrets and database setup (generated by Terraform)
echo "🔑 Deploying secrets..."
kubectl apply -f secret.yaml
kubectl apply -f oauth-secret.yaml

# Create the pgvector extension for this tenant's database
echo "🗄️ Creating pgvector extension..."
kubectl apply -f pgvector-job.yaml

# Deploy OpenWebUI for this tenant
echo "🚀 Deploying OpenWebUI for US tenant..."
helm upgrade --install open-webui-$TENANT open-webui/open-webui -f values.yaml -n $NAMESPACE

# Deploy tenant-specific load balancer
echo "⚖️ Deploying load balancer..."
kubectl apply -f lb.yaml

echo "✅ US tenant setup completed"

# =============================================================================
# OBSERVABILITY SETUP (GOLDILOCKS & KUBECOST)
# =============================================================================

echo ""
echo "📊 === SETTING UP OBSERVABILITY (GOLDILOCKS & KUBECOST) ==="

cd ../../setup-o11y

echo "📍 Current directory: $(pwd)"

# Install metrics server
echo "📈 Installing metrics server..."
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml

# Create namespaces for VPA and Goldilocks
echo "📦 Creating VPA and Goldilocks namespaces..."
kubectl create namespace vpa || echo "⚠️ VPA namespace already exists"
kubectl create namespace goldilocks || echo "⚠️ Goldilocks namespace already exists"

# Add Fairwinds Helm repository
echo "📦 Adding Fairwinds Helm repository..."
helm repo add fairwinds-stable https://charts.fairwinds.com/stable
helm repo update

# Install VPA with minimal configuration (recommender only)
echo "🚀 Installing VPA..."
helm upgrade --install vpa fairwinds-stable/vpa --namespace vpa -f goldilocks/vpa-values.yaml

# Install Goldilocks dashboard
echo "🚀 Installing Goldilocks dashboard..."
helm upgrade --install goldilocks fairwinds-stable/goldilocks --namespace goldilocks

# Deploy LoadBalancer service for dashboard access
echo "⚖️ Deploying LoadBalancer for Goldilocks..."
kubectl apply -f goldilocks/goldilocks-lb.yaml

# Enable monitoring for key namespaces
echo "🏷️ Enabling monitoring for key namespaces..."
kubectl label ns goldilocks goldilocks.fairwinds.com/enabled=true --overwrite
kubectl label ns vpa goldilocks.fairwinds.com/enabled=true --overwrite
kubectl label ns vllm-inference goldilocks.fairwinds.com/enabled=true --overwrite
kubectl label ns litellm goldilocks.fairwinds.com/enabled=true --overwrite
kubectl label ns hr-webui goldilocks.fairwinds.com/enabled=true --overwrite
kubectl label ns legal-webui goldilocks.fairwinds.com/enabled=true --overwrite
kubectl label ns us-webui goldilocks.fairwinds.com/enabled=true --overwrite

echo "✅ Goldilocks setup completed"

# =============================================================================
# KUBECOST SETUP
# =============================================================================

echo ""
echo "💰 === SETTING UP KUBECOST (KUBERNETES COST MONITORING) ==="

# Navigate to Terraform directory
cd ../terraform

echo "📍 Current directory: $(pwd)"

# KubeCost needs to be setup after storage class is deployed (not during initial terraform apply)
# as it requires PVC which is provided by the storage class deployed earlier
echo "🔧 Enabling KubeCost EKS add-on..."
echo "💡 Note: KubeCost requires storage class to be available for PVC creation"

# Apply KubeCost using terraform variable instead of modifying tfvars file
echo "🚀 Deploying KubeCost via Terraform..."
terraform apply -var="enable_kubecost=true" -auto-approve

# Deploy LoadBalancer service for dashboard access
echo "⚖️ Deploying LoadBalancer for KubeCost..."
kubectl apply -f ../setup-o11y/kubecost/kubecost-lb.yaml

echo "✅ KubeCost setup completed"

echo "✅ Complete observability setup finished"

# =============================================================================
# DEPLOYMENT COMPLETION & URL OUTPUT
# =============================================================================

echo ""
echo "🎉 === DEPLOYMENT COMPLETED ==="
echo "📅 Completed at: $(date)"

echo ""
echo "⏳ Waiting for LoadBalancers and ALB to be ready (this may take 5-10 minutes)..."
echo "💡 You can check the status with:"
echo "   - LoadBalancers: kubectl get svc --all-namespaces | grep LoadBalancer"
echo "   - ALB (LiteLLM):  kubectl get ingress litellm-ingress -n litellm"

echo ""
echo "🌐 === ACCESS URLS ==="
echo ""

# Function to get LoadBalancer URL with fallback
get_lb_url() {
    local service=$1
    local namespace=$2
    local url=$(kubectl get svc "$service" -n "$namespace" -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null || echo "")
    if [ -z "$url" ] || [ "$url" = "null" ]; then
        echo "<pending>"
    else
        echo "http://$url"
    fi
}

# Function to get Ingress URL (ALB) with fallback
get_ingress_url() {
    local ingress=$1
    local namespace=$2
    local url=$(kubectl get ingress "$ingress" -n "$namespace" -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null || echo "")
    if [ -z "$url" ] || [ "$url" = "null" ]; then
        echo "<pending>"
    else
        echo "http://$url"
    fi
}

echo "👥 TENANT ACCESS URLS:"
echo "  HR OpenWebUI:    $(get_lb_url "open-webui-service" "hr-webui")"
echo "  Legal OpenWebUI: $(get_lb_url "open-webui-service" "legal-webui")"
echo "  US OpenWebUI:    $(get_lb_url "open-webui-service" "us-webui")"

echo ""
echo "🔄 LITELLM GATEWAY:"
echo "  LiteLLM API:     $(get_ingress_url "litellm-ingress" "litellm")"
if [ -f "../setup-litellm/ingress.yaml" ]; then
    echo "  Admin Panel:     Access via LiteLLM URL + /ui"
fi

echo ""
echo "📊 OBSERVABILITY:"
echo "  Goldilocks:      $(get_lb_url "goldilocks-dashboard-lb" "goldilocks")"
echo "  KubeCost:        $(get_lb_url "kubecost-dashboard-lb" "kubecost")"

echo ""
echo "🔑 === LOGIN CREDENTIALS ==="
echo ""

# Get LiteLLM master key if available
echo "🔄 LiteLLM Admin Panel:"
echo "  Username: admin"
LITELLM_KEY=$(kubectl get secret litellm-master-salt -n litellm -o jsonpath='{.data.LITELLM_MASTER_KEY}' 2>/dev/null | base64 -d 2>/dev/null || echo "<not available yet>")
echo "  Password: $LITELLM_KEY"

echo ""
echo "📋 === NEXT STEPS ==="
echo ""
echo "1. 🕐 Wait for all LoadBalancers to get external IPs (5-10 minutes)"
echo "2. 🌐 Access the URLs above to verify deployments"
echo "3. 🔧 Configure OpenWebUI admin settings in each tenant"
echo "4. ✅ LiteLLM integration is automatically configured - both vLLM and LiteLLM models available"
echo "5. 🔍 Enable web search in HR tenant (SearXNG is already deployed)"
echo "6. 📊 Monitor resources using Goldilocks dashboard"
echo "7. 💰 Track costs and optimize spending using KubeCost dashboard"

echo ""
echo "🎊 Multi-Tenant AI Platform deployment completed successfully!"
echo "📖 Refer to the individual README files for detailed configuration instructions."
