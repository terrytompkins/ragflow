#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# Deploy or update RAGFlow on ECS
# -----------------------------------------------------------------------------
# Usage:
#   ./deploy.sh --env devtest --action <plan|apply|deploy>
#
# Actions:
#   plan   - Terraform plan only
#   apply  - Terraform apply (creates/updates infrastructure)
#   deploy - Update ECS service with new image (after build-and-push)
#   all   - build-and-push + deploy
# -----------------------------------------------------------------------------

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TERRAFORM_DIR="$SCRIPT_DIR/../terraform"
ENV=""
ACTION=""
TAG="latest"

usage() {
  echo "Usage: $0 --env <devtest|dev|test|prod> --action <plan|apply|deploy|all> [--tag <image-tag>]"
  exit 1
}

while [[ $# -gt 0 ]]; do
  case $1 in
    --env)
      ENV="$2"
      shift 2
      ;;
    --action)
      ACTION="$2"
      shift 2
      ;;
    --tag)
      TAG="$2"
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

if [[ -z "$ENV" ]] || [[ -z "$ACTION" ]]; then
  echo "Error: --env and --action are required"
  usage
fi

VAR_FILE="$SCRIPT_DIR/../terraform/environments/${ENV}/terraform.tfvars"
BACKEND_CONFIG="$SCRIPT_DIR/../terraform/environments/${ENV}/backend.tfvars"

cd "$TERRAFORM_DIR"

case "$ACTION" in
  plan|apply)
    if [[ ! -f "$VAR_FILE" ]]; then
      echo "Error: $VAR_FILE not found. Copy from terraform.tfvars.example and fill in values."
      exit 1
    fi
    ;;
esac

case "$ACTION" in
  plan)
    echo "Running terraform plan..."
    terraform init -backend-config="$BACKEND_CONFIG"
    terraform plan -var-file="$VAR_FILE" -out=tfplan
    echo "Run 'terraform apply tfplan' to apply, or use --action apply"
    ;;

  apply)
    echo "Running terraform apply..."
    terraform init -backend-config="$BACKEND_CONFIG"
    terraform apply -var-file="$VAR_FILE" -auto-approve
    echo "Infrastructure updated. Use --action deploy to push a new image."
    ;;

  deploy)
    echo "Updating ECS service with image tag: $TAG"
    CLUSTER=$(terraform output -raw ecs_cluster_name)
    SERVICE=$(terraform output -raw ecs_service_name)
    REGION="${AWS_REGION:-us-east-1}"

    # Force new deployment (pulls latest image with specified tag)
    aws ecs update-service \
      --cluster "$CLUSTER" \
      --service "$SERVICE" \
      --force-new-deployment \
      --region "$REGION" \
      --output text

    echo "Deployment started. Check status with:"
    echo "  aws ecs describe-services --cluster $CLUSTER --services $SERVICE --region $REGION"
    echo ""
    echo "Get ALB URL: terraform output alb_dns_name"
    ;;

  all)
    "$SCRIPT_DIR/build-and-push.sh" --env "$ENV" --tag "$TAG"
    "$SCRIPT_DIR/deploy.sh" --env "$ENV" --action deploy --tag "$TAG"
    ;;

  *)
    echo "Error: Unknown action: $ACTION"
    usage
    ;;
esac
