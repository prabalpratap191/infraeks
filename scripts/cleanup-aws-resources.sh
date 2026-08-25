#!/bin/bash
# cleanup-aws-resources.sh
# Cleanup orphaned AWS resources before Terraform deployment

set -e

# Configuration
CLUSTER_NAME="${1:-meracommerce-dev}"
REGION="${2:-us-east-1}"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m' # No Color

echo ""
echo -e "${MAGENTA}========================================${NC}"
echo -e "${MAGENTA}  AWS Resource Cleanup Script${NC}"
echo -e "${MAGENTA}========================================${NC}"
echo ""
echo -e "${CYAN}Cluster: $CLUSTER_NAME${NC}"
echo -e "${CYAN}Region: $REGION${NC}"
echo ""

# Check AWS CLI
echo -e "${CYAN}[1/6] Checking AWS CLI...${NC}"
if command -v aws &> /dev/null; then
    AWS_VERSION=$(aws --version)
    echo -e "${GREEN}✅ AWS CLI found: $AWS_VERSION${NC}"
else
    echo -e "${RED}❌ AWS CLI not found! Please install AWS CLI first.${NC}"
    exit 1
fi

# Verify AWS credentials
echo -e "\n${CYAN}[2/6] Verifying AWS credentials...${NC}"
if IDENTITY=$(aws sts get-caller-identity 2>&1); then
    ARN=$(echo $IDENTITY | jq -r '.Arn')
    echo -e "${GREEN}✅ Authenticated as: $ARN${NC}"
else
    echo -e "${RED}❌ AWS credentials not configured or invalid!${NC}"
    echo -e "${YELLOW}Run: aws configure${NC}"
    exit 1
fi

# Delete KMS alias
echo -e "\n${CYAN}[3/6] Deleting KMS alias...${NC}"
KMS_ALIAS_NAME="alias/eks/$CLUSTER_NAME"
if aws kms delete-alias --alias-name "$KMS_ALIAS_NAME" --region "$REGION" 2>/dev/null; then
    echo -e "${GREEN}✅ KMS alias deleted: $KMS_ALIAS_NAME${NC}"
else
    echo -e "${YELLOW}⚠️ KMS alias not found or already deleted${NC}"
fi

# Delete CloudWatch log group
echo -e "\n${CYAN}[4/6] Deleting CloudWatch log group...${NC}"
LOG_GROUP_NAME="/aws/eks/$CLUSTER_NAME/cluster"
if aws logs delete-log-group --log-group-name "$LOG_GROUP_NAME" --region "$REGION" 2>/dev/null; then
    echo -e "${GREEN}✅ CloudWatch log group deleted: $LOG_GROUP_NAME${NC}"
else
    echo -e "${YELLOW}⚠️ Log group not found or already deleted${NC}"
fi

# Check for EKS cluster
echo -e "\n${CYAN}[5/6] Checking for EKS cluster...${NC}"
if aws eks describe-cluster --name "$CLUSTER_NAME" --region "$REGION" &>/dev/null; then
    echo -e "${RED}❌ EKS cluster '$CLUSTER_NAME' still exists!${NC}"
    echo -e "\n${YELLOW}You need to destroy it first:${NC}"
    echo "  cd terraform"
    echo "  terraform destroy -var-file=meracommerce-dev.tfvars -auto-approve"
    echo ""
    echo -e "${YELLOW}Or delete manually:${NC}"
    echo "  aws eks delete-cluster --name $CLUSTER_NAME --region $REGION"
else
    echo -e "${GREEN}✅ No EKS cluster found${NC}"
fi

# Check for IAM roles
echo -e "\n${CYAN}[6/6] Checking for IAM roles...${NC}"
ROLES=$(aws iam list-roles --query "Roles[?contains(RoleName, '$CLUSTER_NAME')].RoleName" --output json 2>/dev/null)
ROLE_COUNT=$(echo "$ROLES" | jq '. | length')

if [ "$ROLE_COUNT" -gt 0 ]; then
    echo -e "${YELLOW}⚠️ Found $ROLE_COUNT IAM role(s) with cluster name:${NC}"
    echo "$ROLES" | jq -r '.[]' | while read role; do
        echo -e "  - ${YELLOW}$role${NC}"
    done
    echo -e "\n${CYAN}These will be managed by Terraform or can be deleted manually if orphaned.${NC}"
else
    echo -e "${GREEN}✅ No IAM roles found with cluster name${NC}"
fi

# Summary
echo ""
echo -e "${MAGENTA}========================================${NC}"
echo -e "${MAGENTA}  Cleanup Summary${NC}"
echo -e "${MAGENTA}========================================${NC}"
echo ""
echo -e "${GREEN}✅ KMS alias: Deleted or didn't exist${NC}"
echo -e "${GREEN}✅ CloudWatch log group: Deleted or didn't exist${NC}"
echo -e "${CYAN}ℹ️ EKS cluster: Checked${NC}"
echo -e "${CYAN}ℹ️ IAM roles: Checked${NC}"
echo ""
echo -e "${GREEN}🎉 Cleanup complete!${NC}"
echo ""
echo -e "${CYAN}Next steps:${NC}"
echo "  1. cd terraform"
echo "  2. terraform init"
echo "  3. terraform apply -var-file=meracommerce-dev.tfvars -auto-approve"
echo ""
