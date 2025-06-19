#!/bin/bash
set -e

# Default configuration (backward compatibility)
DEFAULT_VERSION="v0.1.0"
DEFAULT_IMAGE_NAME="openwebui/custom-build"
DEFAULT_REGISTRY="public.ecr.aws/v2f5y6u4"
DEFAULT_FULL_IMAGE_NAME="$DEFAULT_REGISTRY/$DEFAULT_IMAGE_NAME:$DEFAULT_VERSION"

# Parse command line arguments
CUSTOM_IMAGE=""
SHOW_HELP=false

while [[ $# -gt 0 ]]; do
  case $1 in
    --image|-i)
      CUSTOM_IMAGE="$2"
      shift 2
      ;;
    --help|-h)
      SHOW_HELP=true
      shift
      ;;
    *)
      echo "❌ Unknown option: $1"
      echo "Use --help for usage information"
      exit 1
      ;;
  esac
done

# Show help if requested
if [ "$SHOW_HELP" = true ]; then
    echo "🏗️  Custom OpenWebUI Image Builder"
    echo "=================================="
    echo ""
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  --image, -i IMAGE    Full image name to build (e.g., 905418162160.dkr.ecr.ap-southeast-1.amazonaws.com/openwebui/custom-build:v0.1.0)"
    echo "  --help, -h           Show this help message"
    echo ""
    echo "Examples:"
    echo "  # Private ECR"
    echo "  $0 --image 905418162160.dkr.ecr.ap-southeast-1.amazonaws.com/openwebui/custom-build:v0.1.0"
    echo ""
    echo "  # Public ECR (default if no --image specified)"
    echo "  $0 --image public.ecr.aws/v2f5y6u4/openwebui/custom-build:v0.1.0"
    echo ""
    echo "  # Docker Hub"
    echo "  $0 --image mycompany/openwebui-custom:v0.1.0"
    echo ""
    echo "  # Use default (backward compatibility)"
    echo "  $0"
    exit 0
fi

# Determine which image to build
if [ -n "$CUSTOM_IMAGE" ]; then
    FULL_IMAGE_NAME="$CUSTOM_IMAGE"
    echo "🏗️  Building Custom OpenWebUI Image"
    echo "===================================="
    echo "Custom Image: $FULL_IMAGE_NAME"
else
    FULL_IMAGE_NAME="$DEFAULT_FULL_IMAGE_NAME"
    echo "🏗️  Building Custom OpenWebUI Image $DEFAULT_VERSION"
    echo "============================================="
    echo "Default Image: $FULL_IMAGE_NAME"
fi
echo ""

# Verify required files exist
echo "📋 Checking required files..."
if [ ! -f "index.html" ]; then
    echo "❌ Error: index.html not found"
    echo "Please run ./extract-and-modify-index.sh first to create the modified index.html"
    exit 1
fi

if [ ! -f "static/gar-logo.png" ]; then
    echo "❌ Error: static/gar-logo.png not found"
    echo "Please ensure the GAR logo is present in the static/ directory"
    exit 1
fi

if [ ! -f "static/splash.png" ]; then
    echo "❌ Error: static/splash.png not found"
    echo "Please ensure splash.png is present in the static/ directory"
    exit 1
fi

if [ ! -f "static/splash-dark.png" ]; then
    echo "❌ Error: static/splash-dark.png not found"
    echo "Please ensure splash-dark.png is present in the static/ directory"
    exit 1
fi

echo "✅ All required files found"
echo ""

# Build the image
echo "📦 Building $FULL_IMAGE_NAME..."
docker build -t $FULL_IMAGE_NAME .

# Extract registry and image info for additional operations
if [[ "$FULL_IMAGE_NAME" =~ ^([^/]+\.[^/]+)/(.+):([^:]+)$ ]]; then
    # Handle registry URLs with dots (like ECR)
    REGISTRY="${BASH_REMATCH[1]}"
    IMAGE_PATH="${BASH_REMATCH[2]}"
    TAG="${BASH_REMATCH[3]}"
elif [[ "$FULL_IMAGE_NAME" =~ ^([^/]+)/(.+):([^:]+)$ ]]; then
    # Handle simple registry/image:tag format
    REGISTRY="${BASH_REMATCH[1]}"
    IMAGE_PATH="${BASH_REMATCH[2]}"
    TAG="${BASH_REMATCH[3]}"
else
    # Fallback parsing for complex formats
    if [[ "$FULL_IMAGE_NAME" == *":"* ]]; then
        TAG=$(echo "$FULL_IMAGE_NAME" | rev | cut -d':' -f1 | rev)
        IMAGE_WITHOUT_TAG=$(echo "$FULL_IMAGE_NAME" | rev | cut -d':' -f2- | rev)
    else
        TAG="latest"
        IMAGE_WITHOUT_TAG="$FULL_IMAGE_NAME"
    fi
    
    if [[ "$IMAGE_WITHOUT_TAG" == *"/"* ]]; then
        REGISTRY=$(echo "$IMAGE_WITHOUT_TAG" | cut -d'/' -f1)
        IMAGE_PATH=$(echo "$IMAGE_WITHOUT_TAG" | cut -d'/' -f2-)
    else
        REGISTRY="docker.io"
        IMAGE_PATH="$IMAGE_WITHOUT_TAG"
    fi
fi

# Create latest tag if not already latest
if [ "$TAG" != "latest" ]; then
    LATEST_IMAGE_NAME="$REGISTRY/$IMAGE_PATH:latest"
    echo "🏷️  Tagging as latest..."
    docker tag $FULL_IMAGE_NAME $LATEST_IMAGE_NAME
fi

echo ""
echo "✅ Image built successfully!"
echo ""
echo "📊 Image Details:"
docker images $FULL_IMAGE_NAME --format "table {{.Repository}}\t{{.Tag}}\t{{.Size}}\t{{.CreatedAt}}"
echo ""
echo "🧪 Test locally:"
echo "   docker run -d -p 3000:8080 --name test-openwebui-custom $FULL_IMAGE_NAME"
echo "   # Access at http://localhost:3000"
echo "   # Stop with: docker stop test-openwebui-custom && docker rm test-openwebui-custom"
echo ""

# Provide registry-specific push instructions
echo "🚀 Push to registry:"

# Detect registry type and provide appropriate instructions
if [[ "$REGISTRY" == *".ecr."*".amazonaws.com" ]]; then
    # Private ECR
    REGION=$(echo "$REGISTRY" | cut -d'.' -f4)
    echo "   # Login to Private ECR:"
    echo "   aws ecr get-login-password --region $REGION | docker login --username AWS --password-stdin $REGISTRY"
elif [[ "$REGISTRY" == "public.ecr.aws" ]]; then
    # Public ECR
    echo "   # Login to Public ECR:"
    echo "   aws ecr-public get-login-password --region us-east-1 | docker login --username AWS --password-stdin $REGISTRY"
elif [[ "$REGISTRY" == "docker.io" ]] || [[ "$REGISTRY" != *"."* ]]; then
    # Docker Hub
    echo "   # Login to Docker Hub:"
    echo "   docker login"
else
    # Generic registry
    echo "   # Login to registry:"
    echo "   docker login $REGISTRY"
fi

echo "   # Push images:"
echo "   docker push $FULL_IMAGE_NAME"
if [ "$TAG" != "latest" ]; then
    echo "   docker push $LATEST_IMAGE_NAME"
fi
echo ""

# Provide values.yaml.tpl update instructions
echo "📝 Update values.yaml.tpl to use:"
echo "   image:"
echo "     repository: $REGISTRY/$IMAGE_PATH"
echo "     tag: $TAG"
