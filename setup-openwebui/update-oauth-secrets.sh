#!/bin/bash

# Script to update OpenWebUI OAuth credentials in AWS Secrets Manager
# This script reads from ../.env-oauth file and updates the secret created by Terraform
# Usage: ./update-oauth-secrets.sh [TENANT]
# TENANT: hr, legal, or us (optional - will prompt if not provided)

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${GREEN}OpenWebUI Multi-Tenant OAuth Credentials Update Script${NC}"
echo "========================================================"

# Function to display usage
usage() {
    echo "Usage: $0 [TENANT]"
    echo "TENANT: hr, legal, or us"
    echo ""
    echo "Examples:"
    echo "  $0 hr      # Update OAuth credentials for HR tenant"
    echo "  $0 legal   # Update OAuth credentials for Legal tenant"
    echo "  $0 us      # Update OAuth credentials for US tenant"
    echo "  $0         # Interactive mode - will prompt for tenant selection"
    exit 1
}

# Get tenant from command line argument or prompt user
TENANT="$1"
if [ -z "$TENANT" ]; then
    echo -e "${BLUE}Available tenants: hr, legal, us${NC}"
    echo -n "Please select a tenant: "
    read TENANT
fi

# Validate tenant selection
case "$TENANT" in
    hr|legal|us)
        echo -e "Selected tenant: ${YELLOW}$TENANT${NC}"
        NAMESPACE="${TENANT}-webui"
        ;;
    *)
        echo -e "${RED}Error: Invalid tenant '$TENANT'. Must be one of: hr, legal, us${NC}"
        usage
        ;;
esac

# Check if .env-oauth file exists
ENV_FILE="../.env-oauth"
if [ ! -f "$ENV_FILE" ]; then
    echo -e "${RED}Error: .env-oauth file not found at $ENV_FILE${NC}"
    echo "Please create .env-oauth file from .env-oauth.tpl template and add your OAuth credentials"
    exit 1
fi

# Get the secret name from Terraform output
echo "Getting OAuth secret name from Terraform..."
cd ../terraform
SECRET_ARN=$(terraform output -raw openwebui_oauth_secret_arn 2>/dev/null)
if [ -z "$SECRET_ARN" ]; then
    echo -e "${RED}Error: Could not get OAuth secret ARN from Terraform output${NC}"
    echo "Make sure you have run 'terraform apply' first and that the OAuth secret is created"
    exit 1
fi
# Extract just the secret name without the version suffix
SECRET_NAME=$(echo $SECRET_ARN | awk -F: '{print $7}' | awk -F- '{for(i=1;i<=NF-1;i++) printf "%s%s", $i, (i<NF-1?"-":"")}')
cd - > /dev/null

echo -e "OAuth secret name: ${YELLOW}$SECRET_NAME${NC}"

# Parse .env-oauth file and create JSON dynamically
echo "Parsing .env-oauth file for OAuth credentials..."
echo "{" > /tmp/openwebui-oauth-credentials.json

# Read .env-oauth file and extract all KEY=VALUE pairs (excluding comments and empty lines)
first_entry=true
while IFS='=' read -r key value; do
    # Skip comments and empty lines
    if [[ ! "$key" =~ ^[[:space:]]*# ]] && [[ -n "$key" ]]; then
        # Remove leading/trailing whitespace
        key=$(echo "$key" | xargs)
        value=$(echo "$value" | xargs)
        
        # Remove quotes if present
        value="${value%\"}"
        value="${value#\"}"
        value="${value%\'}"
        value="${value#\'}"
        
        # Add comma for all entries except the first
        if [ "$first_entry" = true ]; then
            first_entry=false
        else
            echo "," >> /tmp/openwebui-oauth-credentials.json
        fi
        
        # Write the key-value pair to JSON
        printf '  "%s": "%s"' "$key" "$value" >> /tmp/openwebui-oauth-credentials.json
    fi
done < "$ENV_FILE"

echo "" >> /tmp/openwebui-oauth-credentials.json
echo "}" >> /tmp/openwebui-oauth-credentials.json

# Show what credentials were found
echo "Found the following OAuth credentials:"
grep -E '^\s*"[^"]+":' /tmp/openwebui-oauth-credentials.json | sed 's/.*"\([^"]*\)".*/  - \1/'

# Update the secret in AWS Secrets Manager
echo "Updating OAuth secret in AWS Secrets Manager..."
if aws secretsmanager put-secret-value \
    --secret-id "$SECRET_NAME" \
    --secret-string file:///tmp/openwebui-oauth-credentials.json \
    --region $(aws configure get region) 2>/dev/null; then
    echo -e "${GREEN}✓ OAuth secret updated successfully!${NC}"
else
    echo -e "${RED}Error: Failed to update OAuth secret${NC}"
    rm -f /tmp/openwebui-oauth-credentials.json
    exit 1
fi

# Clean up
rm -f /tmp/openwebui-oauth-credentials.json

# Check if External Secrets Operator will sync
echo ""
echo "Checking External Secrets sync status for $TENANT tenant..."
kubectl get externalsecret oauth-external-secret -n $NAMESPACE -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}' 2>/dev/null | grep -q "True"
if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓ External Secrets Operator is ready and will sync the changes${NC}"
else
    echo -e "${YELLOW}⚠ External Secrets Operator sync status unknown. It may take a few minutes to sync.${NC}"
fi

echo ""
echo -e "${GREEN}OAuth credentials have been updated in AWS Secrets Manager for $TENANT tenant!${NC}"
echo ""
echo "Next steps:"
echo "1. Wait for External Secrets Operator to sync (usually within 15 minutes)"
echo "2. Restart OpenWebUI deployment to pick up new OAuth credentials:"
echo "   kubectl rollout restart deployment open-webui -n $NAMESPACE"
echo ""
echo "To verify the secret was synced to Kubernetes:"
echo "   kubectl get secret openwebui-oauth-credentials -n $NAMESPACE"
echo ""
echo "To check OAuth configuration:"
echo "   kubectl describe secret openwebui-oauth-credentials -n $NAMESPACE"
