#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# Build RAGFlow Docker image and push to ECR
# -----------------------------------------------------------------------------
# Usage:
#   ./build-and-push.sh --env devtest [--tag v1.0.0]
#
# Prerequisites:
#   - Docker installed and running
#   - AWS CLI configured with credentials that can push to ECR
#   - Terraform applied (ECR repo exists)
# -----------------------------------------------------------------------------

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
ENV=""
TAG="latest"
PLATFORM="linux/amd64"

usage() {
  echo "Usage: $0 --env <devtest|dev|test|prod> [--tag <tag>] [--platform <platform>]"
  exit 1
}

while [[ $# -gt 0 ]]; do
  case $1 in
    --env)
      ENV="$2"
      shift 2
      ;;
    --tag)
      TAG="$2"
      shift 2
      ;;
    --platform)
      PLATFORM="$2"
      shift 2
      ;;
    -h|--help)
      usage
      ;;
    *)
      echo "Unknown option: $1"
      usage
      ;;
  esac
done

if [[ -z "$ENV" ]]; then
  echo "Error: --env is required"
  usage
fi

# Get ECR repo URL and region from Terraform output
cd "$SCRIPT_DIR/../terraform"
ECR_URL=$(terraform output -raw ecr_repository_url 2>/dev/null || true)
REGION=$(terraform output -raw aws_region 2>/dev/null || echo "us-east-1")
if [[ -z "$ECR_URL" ]]; then
  echo "Error: Could not get ecr_repository_url from Terraform. Run 'terraform apply' first."
  exit 1
fi

# ECR login
echo "Logging into ECR..."
aws ecr get-login-password --region "${AWS_REGION:-$REGION}" | \
  docker login --username AWS --password-stdin "${ECR_URL%%/*}"

# Build from repo root (parent of deploy/)
echo "Building RAGFlow image (platform=$PLATFORM)..."
cd "$REPO_ROOT"
docker build --platform "$PLATFORM" -f Dockerfile -t "${ECR_URL}:${TAG}" .

echo "Pushing to ECR..."
docker push "${ECR_URL}:${TAG}"

echo "Done. Image: ${ECR_URL}:${TAG}"
