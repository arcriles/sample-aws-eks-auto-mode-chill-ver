# Custom OpenWebUI Image - GAR GPT Branding

This directory contains the files and scripts needed to build a custom OpenWebUI image with GAR GPT branding.

## Private ECR Setup (Recommended)

For production use, it's recommended to use AWS Private ECR instead of Public ECR for better security and access control.

### Prerequisites

- AWS CLI installed and configured
- Proper IAM permissions for ECR operations:
  - `ecr:DescribeRepositories`
  - `ecr:CreateRepository`
  - `ecr:GetAuthorizationToken`
  - `ecr:BatchCheckLayerAvailability`
  - `ecr:GetDownloadUrlForLayer`
  - `ecr:BatchGetImage`
  - `ecr:InitiateLayerUpload`
  - `ecr:UploadLayerPart`
  - `ecr:CompleteLayerUpload`
  - `ecr:PutImage`

### Step 1: Create Private ECR Repository

Run the automated setup script to create your private ECR repository:

```bash
# Make the script executable
chmod +x setup-private-ecr.sh

# Run the setup script
./setup-private-ecr.sh
```

The script will:
- Auto-detect your AWS Account ID and Region
- Ask for confirmation or allow you to override
- Check if the repository already exists
- Create the repository if needed
- Provide you with the exact commands for authentication and building

### Step 2: Verify Setup

After running the script, you should see output similar to:

```
🎉 Private ECR Setup Complete!
📋 Repository Details:
  Registry: 123456789012.dkr.ecr.us-east-1.amazonaws.com
  Repository: openwebui/custom-build
  Full URL: 123456789012.dkr.ecr.us-east-1.amazonaws.com/openwebui/custom-build
```

Copy the authentication and build commands provided by the script for use in the next steps.

## Version 0.1.0 - Minimal Approach

Version 0.1.0 uses a **minimal approach** that maintains full database compatibility while adding GAR GPT branding. This approach was developed after discovering that complex permission fixes and environment variable modifications were causing database connection issues.

### Key Features

- ✅ **Database Compatible**: Works with PostgreSQL/RDS without connection issues
- ✅ **GAR GPT Branding**: Complete branding replacement with JavaScript
- ✅ **Minimal Dockerfile**: Only copies necessary files, no system modifications
- ✅ **Proper Asset Extraction**: Uses current OpenWebUI image as source
- ✅ **Local Static Assets**: Favicon points to local GAR logo

## Files Overview

```
custom-image/
├── Dockerfile                    # Minimal Dockerfile (v0.1.0)
├── setup-private-ecr.sh          # Script to create private ECR repository
├── extract-and-modify-index.sh   # Script to extract and modify index.html
├── build-image.sh              # Build script for version 0.1.0
├── README.md                     # This file
├── static/                       # Static assets directory
│   ├── gar-logo.png             # GAR logo (required)
│   ├── splash.png               # Splash screen logo
│   └── splash-dark.png          # Dark theme splash logo
├── index.html                    # Modified index.html (generated)
└── index-original.html           # Backup of original (generated)
```

## Quick Start

### Prerequisites

- Docker installed and running
- AWS CLI configured (for ECR push)
- GAR logo image file

### Step 1: Prepare Static Assets

Create the required static assets in the `static/` directory:

```bash
# Ensure you have these files:
static/gar-logo.png      # Your GAR logo (32x32 or larger PNG)
static/splash.png        # Can be same as gar-logo.png
static/splash-dark.png   # Can be same as gar-logo.png
```

### Step 2: Extract and Modify index.html

```bash
# Run the extraction script
./extract-and-modify-index.sh
```

This script will:
- Pull the latest OpenWebUI image
- Extract the current `index.html`
- Add GAR GPT branding scripts
- Create the modified `index.html`

### Step 3: Build the Custom Image

**For Private ECR (Recommended):**
```bash
# Use the image URL provided by setup-private-ecr.sh
./build-image.sh --image <account-id>.dkr.ecr.<region>.amazonaws.com/openwebui/custom-build:v0.1.0
```

**For Public ECR (Default):**
```bash
# Uses default public ECR (backward compatibility)
./build-image.sh
```

### Step 4: Push to Registry

**For Private ECR (Recommended):**
```bash
# Use the commands provided by the setup-private-ecr.sh script
# Example (replace with your actual account ID and region):
aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin 123456789012.dkr.ecr.us-east-1.amazonaws.com

# Build and push the images
docker build -t 123456789012.dkr.ecr.us-east-1.amazonaws.com/openwebui/custom-build:v0.1.0 .
docker tag 123456789012.dkr.ecr.us-east-1.amazonaws.com/openwebui/custom-build:v0.1.0 123456789012.dkr.ecr.us-east-1.amazonaws.com/openwebui/custom-build:latest
docker push 123456789012.dkr.ecr.us-east-1.amazonaws.com/openwebui/custom-build:v0.1.0
docker push 123456789012.dkr.ecr.us-east-1.amazonaws.com/openwebui/custom-build:latest
```

**For Public ECR (Legacy):**
```bash
# Login to ECR
aws ecr-public get-login-password --region us-east-1 | docker login --username AWS --password-stdin public.ecr.aws/v2f5y6u4

# Push the images
docker push public.ecr.aws/v2f5y6u4/openwebui/custom-build:v0.1.0
docker push public.ecr.aws/v2f5y6u4/openwebui/custom-build:latest
```

## Deploying to EKS Cluster

After building and pushing your custom GAR GPT image to private ECR, you'll need to configure your EKS cluster to pull the image. The configuration depends on whether your ECR repository is in the same AWS account as your EKS cluster or in a different account.

### Scenario 1: Same Account Deployment (Recommended)

When your private ECR repository is in the **same AWS account and region** as your EKS cluster, authentication works automatically.

#### ✅ What Works Automatically

- **EKS Node Groups** automatically get ECR permissions through AWS managed policies
- **No additional IAM configuration** needed
- **No image pull secrets** required
- **Seamless authentication** via the node's IAM role

#### Required Configuration Changes

**1. Update your Helm values file** (e.g., `setup-openwebui/templates/values.yaml.tpl`):

```yaml
# Change from public ECR:
image:
  repository: public.ecr.aws/v2f5y6u4/openwebui/custom-build
  tag: v0.1.0
  pullPolicy: IfNotPresent

# To private ECR:
image:
  repository: ${account_id}.dkr.ecr.${region}.amazonaws.com/openwebui/custom-build
  tag: v0.1.0
  pullPolicy: IfNotPresent
```

**2. Update the existing Terraform templating** to include account ID for private ECR:

The project already has a `setup_openwebui_values` resource in `terraform/setup.tf`. Update it to include account ID:

```hcl
# Get current AWS account ID
data "aws_caller_identity" "current" {}

# Update the existing setup_openwebui_values resource
resource "local_file" "setup_openwebui_values" {
  content = templatefile("${path.module}/../setup-openwebui/templates/values.yaml.tpl", {
    account_id     = data.aws_caller_identity.current.account_id  # Add this line
    s3_bucket_name = aws_s3_bucket.openwebui_docs.id
    region         = var.region
    rds_endpoint   = aws_db_instance.postgres.endpoint
  })
  filename = "${path.module}/../setup-openwebui/values.yaml"
}
```

This leverages the existing Terraform structure and simply adds the `account_id` parameter to the template variables.

**3. Deploy normally** - no special configuration needed:

```bash
# Deploy with updated values
helm upgrade --install open-webui open-webui/open-webui -f values.yaml -n vllm-inference
```

#### Why This Works

EKS node groups automatically include these AWS managed policies:
- `AmazonEKSWorkerNodePolicy`
- `AmazonEKS_CNI_Policy` 
- `AmazonEC2ContainerRegistryReadOnly`

The `AmazonEC2ContainerRegistryReadOnly` policy provides read access to ECR repositories in the same account.

### Scenario 2: Cross-Account Deployment

When your private ECR repository is in a **different AWS account** than your EKS cluster, additional cross-account permissions are required.

#### Required Steps

**1. Configure ECR Repository Policy (Source Account)**

The account hosting the ECR repository must grant access to the EKS account:

```bash
# Create repository policy JSON
cat > ecr-cross-account-policy.json << EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "AllowCrossAccountAccess",
      "Effect": "Allow",
      "Principal": {
        "AWS": "arn:aws:iam::EKS-ACCOUNT-ID:root"
      },
      "Action": [
        "ecr:BatchCheckLayerAvailability",
        "ecr:GetDownloadUrlForLayer",
        "ecr:BatchGetImage"
      ]
    }
  ]
}
EOF

# Apply the policy to your ECR repository
aws ecr set-repository-policy \
  --repository-name openwebui/custom-build \
  --policy-text file://ecr-cross-account-policy.json
```

**2. Configure EKS Node Role Policy (Target Account)**

The EKS cluster account needs permissions to access the external ECR:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "ecr:GetAuthorizationToken"
      ],
      "Resource": "*"
    },
    {
      "Effect": "Allow",
      "Action": [
        "ecr:BatchCheckLayerAvailability",
        "ecr:GetDownloadUrlForLayer",
        "ecr:BatchGetImage"
      ],
      "Resource": "arn:aws:ecr:REGION:ECR-ACCOUNT-ID:repository/openwebui/custom-build"
    }
  ]
}
```

**3. Create Image Pull Secrets**

For cross-account scenarios, explicit image pull secrets are recommended:

```bash
# Get ECR login token from the ECR account
aws ecr get-login-password --region REGION --profile ecr-account-profile | \
kubectl create secret docker-registry ecr-cross-account-secret \
  --docker-server=ECR-ACCOUNT-ID.dkr.ecr.REGION.amazonaws.com \
  --docker-username=AWS \
  --docker-password-stdin \
  --namespace=vllm-inference
```

**4. Update Helm Values**

```yaml
image:
  repository: ECR-ACCOUNT-ID.dkr.ecr.REGION.amazonaws.com/openwebui/custom-build
  tag: v0.1.0
  pullPolicy: IfNotPresent

imagePullSecrets:
  - name: ecr-cross-account-secret
```

#### Token Rotation Considerations

ECR tokens expire after 12 hours. For production cross-account deployments, consider:

- **Automated token refresh** using a CronJob
- **External Secrets Operator** to manage ECR credentials
- **IRSA (IAM Roles for Service Accounts)** for more secure authentication


## Technical Details

### Minimal Dockerfile Approach

The v0.1.0 Dockerfile is intentionally minimal:

```dockerfile
FROM ghcr.io/open-webui/open-webui:main

# Copy the modified index.html with GAR GPT branding
COPY index.html /app/build/index.html

# Copy static assets (GAR logo, splash images)
COPY static/* /app/build/static/
```

**What we DON'T do (that caused issues in previous versions):**
- ❌ No user switching (`USER root` → `USER 1000`)
- ❌ No permission modifications (`chown`, `chmod`)
- ❌ No working directory changes (`WORKDIR`)
- ❌ No environment variables (`ENV PGSSLMODE`, etc.)
- ❌ No complex filesystem operations


**Proceed over to [Setup OpenWebUI](./../setup-openwebui/)**
