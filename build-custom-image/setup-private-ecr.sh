#!/bin/bash
set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Repository name
REPO_NAME="openwebui/custom-build"

echo -e "${BLUE}🔧 Setting up Private ECR Repository for GAR GPT Custom Image${NC}"
echo "=================================================="

# Check if AWS CLI is installed and configured
echo -e "${BLUE}📋 Checking AWS CLI configuration...${NC}"
if ! command -v aws &> /dev/null; then
    echo -e "${RED}❌ AWS CLI is not installed. Please install AWS CLI first.${NC}"
    exit 1
fi

# Check if AWS CLI is configured
if ! aws sts get-caller-identity &> /dev/null; then
    echo -e "${RED}❌ AWS CLI is not configured or credentials are invalid.${NC}"
    echo "Please run 'aws configure' to set up your credentials."
    exit 1
fi

echo -e "${GREEN}✅ AWS CLI is configured${NC}"

# Auto-detect AWS Account ID
echo -e "${BLUE}🔍 Detecting AWS Account ID...${NC}"
DETECTED_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text 2>/dev/null)
if [ -z "$DETECTED_ACCOUNT_ID" ]; then
    echo -e "${RED}❌ Could not detect AWS Account ID${NC}"
    exit 1
fi

echo -e "${YELLOW}Detected AWS Account ID: ${DETECTED_ACCOUNT_ID}${NC}"
read -p "Is this the correct account for creating the ECR repository? (y/n): " confirm_account

if [[ $confirm_account != "y" && $confirm_account != "Y" ]]; then
    read -p "Please enter the AWS Account ID you want to use: " ACCOUNT_ID
    if [ -z "$ACCOUNT_ID" ]; then
        echo -e "${RED}❌ Account ID cannot be empty${NC}"
        exit 1
    fi
else
    ACCOUNT_ID=$DETECTED_ACCOUNT_ID
fi

# Auto-detect AWS Region
echo -e "${BLUE}🌍 Detecting AWS Region...${NC}"
DETECTED_REGION=$(aws configure get region 2>/dev/null)
if [ -z "$DETECTED_REGION" ]; then
    DETECTED_REGION=$(aws configure get region --profile default 2>/dev/null || echo "us-east-1")
fi

echo -e "${YELLOW}Detected AWS Region: ${DETECTED_REGION}${NC}"
read -p "Is this the correct region for creating the ECR repository? (y/n): " confirm_region

if [[ $confirm_region != "y" && $confirm_region != "Y" ]]; then
    read -p "Please enter the AWS Region you want to use: " REGION
    if [ -z "$REGION" ]; then
        echo -e "${RED}❌ Region cannot be empty${NC}"
        exit 1
    fi
else
    REGION=$DETECTED_REGION
fi

# Construct ECR registry URL
ECR_REGISTRY="${ACCOUNT_ID}.dkr.ecr.${REGION}.amazonaws.com"
FULL_REPO_URL="${ECR_REGISTRY}/${REPO_NAME}"

echo ""
echo -e "${BLUE}📝 Configuration Summary:${NC}"
echo "  Account ID: ${ACCOUNT_ID}"
echo "  Region: ${REGION}"
echo "  Repository: ${REPO_NAME}"
echo "  Full URL: ${FULL_REPO_URL}"
echo ""

read -p "Proceed with this configuration? (y/n): " confirm_proceed
if [[ $confirm_proceed != "y" && $confirm_proceed != "Y" ]]; then
    echo -e "${YELLOW}⏹️  Setup cancelled by user${NC}"
    exit 0
fi

# Check ECR permissions
echo -e "${BLUE}🔐 Checking ECR permissions...${NC}"
if ! aws ecr describe-repositories --region "$REGION" --max-items 1 &> /dev/null; then
    echo -e "${RED}❌ Insufficient ECR permissions. Please ensure you have the following permissions:${NC}"
    echo "  - ecr:DescribeRepositories"
    echo "  - ecr:CreateRepository"
    echo "  - ecr:GetAuthorizationToken"
    exit 1
fi

echo -e "${GREEN}✅ ECR permissions verified${NC}"

# Check if repository already exists
echo -e "${BLUE}🔍 Checking if repository already exists...${NC}"
if aws ecr describe-repositories --region "$REGION" --repository-names "$REPO_NAME" &> /dev/null; then
    echo -e "${YELLOW}⚠️  Repository '${REPO_NAME}' already exists in region '${REGION}'${NC}"
    echo -e "${GREEN}✅ Repository URL: ${FULL_REPO_URL}${NC}"
else
    # Create the repository
    echo -e "${BLUE}🏗️  Creating ECR repository...${NC}"
    if aws ecr create-repository --region "$REGION" --repository-name "$REPO_NAME" &> /dev/null; then
        echo -e "${GREEN}✅ Successfully created repository '${REPO_NAME}'${NC}"
    else
        echo -e "${RED}❌ Failed to create repository. Please check your permissions and try again.${NC}"
        exit 1
    fi
fi

# Success output
echo ""
echo -e "${GREEN}🎉 Private ECR Setup Complete!${NC}"
echo "=================================================="
echo -e "${BLUE}📋 Repository Details:${NC}"
echo "  Registry: ${ECR_REGISTRY}"
echo "  Repository: ${REPO_NAME}"
echo "  Full URL: ${FULL_REPO_URL}"
echo ""
echo -e "${BLUE}🔑 Authentication Command:${NC}"
echo "  aws ecr get-login-password --region ${REGION} | docker login --username AWS --password-stdin ${ECR_REGISTRY}"
echo ""
echo -e "${BLUE}🏗️  Build Commands (using enhanced build script):${NC}"
echo "  # Use the enhanced build script with your private ECR:"
echo "  ./build-image.sh --image ${FULL_REPO_URL}:v0.1.0"
echo ""
echo -e "${BLUE}🏗️  Manual Build Commands (alternative):${NC}"
echo "  docker build -t ${FULL_REPO_URL}:v0.1.0 ."
echo "  docker tag ${FULL_REPO_URL}:v0.1.0 ${FULL_REPO_URL}:latest"
echo "  docker push ${FULL_REPO_URL}:v0.1.0"
echo "  docker push ${FULL_REPO_URL}:latest"
echo ""
echo -e "${YELLOW}💡 Next Steps:${NC}"
echo "  1. Run the authentication command above"
echo "  2. Build your custom image using: ./build-image.sh --image ${FULL_REPO_URL}:v0.1.0"
echo "  3. The build script will automatically provide the correct push commands"
echo "  4. Update your Kubernetes deployments to use the new private registry URL"
echo ""
echo -e "${GREEN}✅ Setup completed successfully!${NC}"
