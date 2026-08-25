#!/bin/bash

################################################################################
# EKS Prerequisites Verification Script
# Purpose: Verify AWS environment is ready for EKS node deployment
# Usage: ./verify-eks-prerequisites.sh <cluster-name> <region>
################################################################################

set -e

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Default values
CLUSTER_NAME="${1:-meracommerce-dev}"
REGION="${2:-us-east-1}"
MIN_AVAILABLE_IPS=10
REQUIRED_AZS=("us-east-1a" "us-east-1b" "us-east-1c")
INSTANCE_TYPE="t3.medium"

echo "========================================"
echo "EKS Prerequisites Verification"
echo "========================================"
echo "Cluster Name: $CLUSTER_NAME"
echo "Region: $REGION"
echo "Instance Type: $INSTANCE_TYPE"
echo "Required AZs: ${REQUIRED_AZS[*]}"
echo "========================================"
echo ""

# Track overall status
ALL_CHECKS_PASSED=true

################################################################################
# Check 1: AWS CLI Authentication
################################################################################
echo "[1/8] Checking AWS CLI authentication..."
if aws sts get-caller-identity --region "$REGION" &> /dev/null; then
    ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
    USER_ARN=$(aws sts get-caller-identity --query Arn --output text)
    echo -e "${GREEN}✓ Authenticated${NC}"
    echo "    Account: $ACCOUNT_ID"
    echo "    User/Role: $USER_ARN"
else
    echo -e "${RED}✗ AWS authentication failed${NC}"
    echo "    Please configure AWS credentials"
    ALL_CHECKS_PASSED=false
fi
echo ""

################################################################################
# Check 2: VPC and Subnets
################################################################################
echo "[2/8] Checking VPC and subnet availability..."
VPC_ID=$(aws ec2 describe-vpcs --region "$REGION" --filters Name=isDefault,Values=true --query 'Vpcs[0].VpcId' --output text 2>/dev/null || echo "")

if [ -n "$VPC_ID" ] && [ "$VPC_ID" != "None" ]; then
    echo -e "${GREEN}✓ Default VPC found${NC}"
    echo "    VPC ID: $VPC_ID"
    
    # Check subnets in required AZs
    for az in "${REQUIRED_AZS[@]}"; do
        SUBNET_INFO=$(aws ec2 describe-subnets \
            --region "$REGION" \
            --filters \
                "Name=vpc-id,Values=$VPC_ID" \
                "Name=availability-zone,Values=$az" \
                "Name=state,Values=available" \
            --query 'Subnets[0].{SubnetId:SubnetId,AvailableIPs:AvailableIpAddressCount}' \
            --output json 2>/dev/null)
        
        if [ -n "$SUBNET_INFO" ] && [ "$SUBNET_INFO" != "null" ]; then
            SUBNET_ID=$(echo "$SUBNET_INFO" | jq -r '.SubnetId // empty')
            AVAILABLE_IPS=$(echo "$SUBNET_INFO" | jq -r '.AvailableIPs // 0')
            
            if [ -n "$SUBNET_ID" ]; then
                if [ "$AVAILABLE_IPS" -ge "$MIN_AVAILABLE_IPS" ]; then
                    echo -e "${GREEN}✓ $az: $SUBNET_ID ($AVAILABLE_IPS available IPs)${NC}"
                else
                    echo -e "${YELLOW}⚠ $az: $SUBNET_ID (only $AVAILABLE_IPS IPs available, need $MIN_AVAILABLE_IPS+)${NC}"
                    ALL_CHECKS_PASSED=false
                fi
            else
                echo -e "${RED}✗ $az: No suitable subnet found${NC}"
                ALL_CHECKS_PASSED=false
            fi
        else
            echo -e "${RED}✗ $az: No available subnet${NC}"
            ALL_CHECKS_PASSED=false
        fi
    done
else
    echo -e "${RED}✗ No default VPC found${NC}"
    ALL_CHECKS_PASSED=false
fi
echo ""

################################################################################
# Check 3: Instance Type Availability
################################################################################
echo "[3/8] Checking instance type availability..."
for az in "${REQUIRED_AZS[@]}"; do
    AVAILABLE=$(aws ec2 describe-instance-type-offerings \
        --location-type availability-zone \
        --filters "Name=instance-type,Values=$INSTANCE_TYPE" "Name=location,Values=$az" \
        --region "$REGION" \
        --query 'InstanceTypeOfferings[0].InstanceType' \
        --output text 2>/dev/null)
    
    if [ "$AVAILABLE" == "$INSTANCE_TYPE" ]; then
        echo -e "${GREEN}✓ $INSTANCE_TYPE available in $az${NC}"
    else
        echo -e "${RED}✗ $INSTANCE_TYPE NOT available in $az${NC}"
        ALL_CHECKS_PASSED=false
    fi
done
echo ""

################################################################################
# Check 4: IAM Permissions
################################################################################
echo "[4/8] Checking IAM permissions..."
REQUIRED_ACTIONS=(
    "eks:CreateCluster"
    "eks:DescribeCluster"
    "ec2:DescribeSubnets"
    "ec2:DescribeVpcs"
    "iam:CreateRole"
)

# Note: This is a basic check. Full permission validation requires more complex logic
if aws iam get-user &> /dev/null || aws sts get-caller-identity &> /dev/null; then
    echo -e "${GREEN}✓ IAM credentials valid${NC}"
    echo "    Note: Ensure your IAM user/role has EKS full access"
else
    echo -e "${RED}✗ Cannot verify IAM permissions${NC}"
    ALL_CHECKS_PASSED=false
fi
echo ""

################################################################################
# Check 5: Check for Existing Cluster
################################################################################
echo "[5/8] Checking for existing cluster..."
CLUSTER_STATUS=$(aws eks describe-cluster \
    --name "$CLUSTER_NAME" \
    --region "$REGION" \
    --query 'cluster.status' \
    --output text 2>/dev/null || echo "NOT_FOUND")

if [ "$CLUSTER_STATUS" == "NOT_FOUND" ]; then
    echo -e "${GREEN}✓ No existing cluster (ready for fresh deployment)${NC}"
elif [ "$CLUSTER_STATUS" == "ACTIVE" ]; then
    echo -e "${YELLOW}⚠ Cluster already exists and is ACTIVE${NC}"
    echo "    This deployment will update the existing cluster"
elif [ "$CLUSTER_STATUS" == "FAILED" ] || [ "$CLUSTER_STATUS" == "CREATE_FAILED" ]; then
    echo -e "${RED}✗ Cluster exists in FAILED state${NC}"
    echo "    Recommendation: Delete failed cluster before proceeding"
    echo "    Command: aws eks delete-cluster --name $CLUSTER_NAME --region $REGION"
    ALL_CHECKS_PASSED=false
else
    echo -e "${YELLOW}⚠ Cluster in state: $CLUSTER_STATUS${NC}"
fi
echo ""

################################################################################
# Check 6: Service Quotas
################################################################################
echo "[6/8] Checking AWS service quotas..."

# Check EC2 instance quota
EC2_QUOTA=$(aws service-quotas get-service-quota \
    --service-code ec2 \
    --quota-code L-1216C47A \
    --region "$REGION" \
    --query 'Quota.Value' \
    --output text 2>/dev/null || echo "unknown")

if [ "$EC2_QUOTA" != "unknown" ]; then
    echo -e "${GREEN}✓ Running On-Demand Standard instances quota: $EC2_QUOTA${NC}"
    if (( $(echo "$EC2_QUOTA < 5" | bc -l 2>/dev/null || echo 0) )); then
        echo -e "${YELLOW}⚠ Quota might be low for production use${NC}"
    fi
else
    echo -e "${YELLOW}⚠ Could not retrieve EC2 quota${NC}"
fi

# Check EKS cluster quota
EKS_CLUSTER_QUOTA=$(aws service-quotas get-service-quota \
    --service-code eks \
    --quota-code L-1194D53C \
    --region "$REGION" \
    --query 'Quota.Value' \
    --output text 2>/dev/null || echo "unknown")

if [ "$EKS_CLUSTER_QUOTA" != "unknown" ]; then
    echo -e "${GREEN}✓ EKS clusters quota: $EKS_CLUSTER_QUOTA${NC}"
else
    echo -e "${YELLOW}⚠ Could not retrieve EKS quota${NC}"
fi
echo ""

################################################################################
# Check 7: Terraform State
################################################################################
echo "[7/8] Checking Terraform state..."
if [ -f "terraform/terraform.tfstate" ]; then
    echo -e "${YELLOW}⚠ Terraform state file exists${NC}"
    echo "    Location: terraform/terraform.tfstate"
    
    # Check if state has resources
    RESOURCE_COUNT=$(grep -c '"type":' terraform/terraform.tfstate 2>/dev/null || echo "0")
    echo "    Approximate resources in state: $RESOURCE_COUNT"
else
    echo -e "${GREEN}✓ No local Terraform state (fresh start)${NC}"
fi
echo ""

################################################################################
# Check 8: Configuration Files
################################################################################
echo "[8/8] Checking Terraform configuration files..."
REQUIRED_FILES=(
    "terraform/main.tf"
    "terraform/variables.tf"
    "terraform/meracommerce-dev.tfvars"
    "terraform/modules/eks/main.tf"
)

for file in "${REQUIRED_FILES[@]}"; do
    if [ -f "$file" ]; then
        echo -e "${GREEN}✓ $file exists${NC}"
    else
        echo -e "${RED}✗ $file NOT FOUND${NC}"
        ALL_CHECKS_PASSED=false
    fi
done
echo ""

################################################################################
# Summary
################################################################################
echo "========================================"
echo "VERIFICATION SUMMARY"
echo "========================================"

if [ "$ALL_CHECKS_PASSED" = true ]; then
    echo -e "${GREEN}✓ All critical checks passed!${NC}"
    echo ""
    echo "You can proceed with Terraform deployment:"
    echo "  cd terraform"
    echo "  terraform init"
    echo "  terraform plan -var-file=meracommerce-dev.tfvars"
    echo "  terraform apply -var-file=meracommerce-dev.tfvars"
    exit 0
else
    echo -e "${RED}✗ Some checks failed${NC}"
    echo ""
    echo "Please address the issues above before deployment."
    echo "Refer to: terraform/eks-troubleshooting-guide.md"
    exit 1
fi
