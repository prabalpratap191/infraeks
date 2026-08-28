#!/bin/bash

# Jenkins Terraform Wrapper Script
# This script should be called from Jenkins pipeline to ensure proper EKS connectivity

set -e

# Configuration
CLUSTER_NAME="meracommerce-dev-cluster"
REGION="us-east-1"
TERRAFORM_DIR="terraform"
TFVARS_FILE="environments/dev.tfvars"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo "======================================"
echo "Jenkins Terraform Deployment Wrapper"
echo "======================================"

# Function to check command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Verify prerequisites
echo -e "${YELLOW}Checking prerequisites...${NC}"

if ! command_exists aws; then
    echo -e "${RED}ERROR: AWS CLI not found${NC}"
    exit 1
fi

if ! command_exists terraform; then
    echo -e "${RED}ERROR: Terraform not found${NC}"
    exit 1
fi

if ! command_exists kubectl; then
    echo -e "${RED}ERROR: kubectl not found${NC}"
    exit 1
fi

echo -e "${GREEN}Prerequisites OK${NC}"

# Verify AWS credentials
echo -e "${YELLOW}Verifying AWS credentials...${NC}"
AWS_IDENTITY=$(aws sts get-caller-identity 2>&1)
if [ $? -ne 0 ]; then
    echo -e "${RED}ERROR: AWS credentials not configured${NC}"
    echo "$AWS_IDENTITY"
    exit 1
fi
echo -e "${GREEN}AWS Identity: $(echo $AWS_IDENTITY | jq -r '.Arn')${NC}"

# Update kubeconfig
echo -e "${YELLOW}Updating kubeconfig for cluster: $CLUSTER_NAME${NC}"
aws eks update-kubeconfig --name "$CLUSTER_NAME" --region "$REGION" 2>&1
if [ $? -ne 0 ]; then
    echo -e "${YELLOW}Warning: Could not update kubeconfig. Cluster might not exist yet.${NC}"
else
    echo -e "${GREEN}Kubeconfig updated${NC}"
    
    # Test cluster connectivity
    echo -e "${YELLOW}Testing cluster connectivity...${NC}"
    if kubectl cluster-info &>/dev/null; then
        echo -e "${GREEN}Cluster is reachable${NC}"
    else
        echo -e "${YELLOW}Warning: Cannot connect to cluster API. This is normal for initial deployment.${NC}"
    fi
fi

# Change to terraform directory
cd "$TERRAFORM_DIR"

# Initialize Terraform
echo -e "${YELLOW}Initializing Terraform...${NC}"
terraform init -upgrade
if [ $? -ne 0 ]; then
    echo -e "${RED}ERROR: Terraform init failed${NC}"
    exit 1
fi
echo -e "${GREEN}Terraform initialized${NC}"

# Validate Terraform configuration
echo -e "${YELLOW}Validating Terraform configuration...${NC}"
terraform validate
if [ $? -ne 0 ]; then
    echo -e "${RED}ERROR: Terraform validation failed${NC}"
    exit 1
fi
echo -e "${GREEN}Terraform configuration valid${NC}"

# Plan Terraform changes
echo -e "${YELLOW}Planning Terraform changes...${NC}"
terraform plan -var-file="$TFVARS_FILE" -out=tfplan
if [ $? -ne 0 ]; then
    echo -e "${RED}ERROR: Terraform plan failed${NC}"
    exit 1
fi
echo -e "${GREEN}Terraform plan created${NC}"

# Apply Terraform changes
echo -e "${YELLOW}Applying Terraform changes...${NC}"
terraform apply -auto-approve tfplan
APPLY_EXIT_CODE=$?

if [ $APPLY_EXIT_CODE -eq 0 ]; then
    echo -e "${GREEN}Terraform apply successful!${NC}"
    
    # Update kubeconfig again after cluster creation
    echo -e "${YELLOW}Updating kubeconfig post-deployment...${NC}"
    aws eks update-kubeconfig --name "$CLUSTER_NAME" --region "$REGION"
    
    # Verify deployment
    echo -e "${YELLOW}Verifying deployment...${NC}"
    
    echo -e "${YELLOW}Cluster nodes:${NC}"
    kubectl get nodes
    
    echo -e "${YELLOW}Namespaces:${NC}"
    kubectl get namespaces | grep -E '(order-service-ns|catalog-service-ns|customer-service-ns)'
    
    echo -e "${YELLOW}Load Balancer Controller:${NC}"
    kubectl get pods -n kube-system | grep aws-load-balancer-controller
    
    echo -e "${GREEN}======================================${NC}"
    echo -e "${GREEN}Deployment completed successfully!${NC}"
    echo -e "${GREEN}======================================${NC}"
    
    exit 0
else
    echo -e "${RED}======================================${NC}"
    echo -e "${RED}Terraform apply failed${NC}"
    echo -e "${RED}======================================${NC}"
    
    echo -e "${YELLOW}Common issues and solutions:${NC}"
    echo "1. Timeout errors: Increase timeout values in module files"
    echo "2. Security group issues: Check EC2 and cluster security groups"
    echo "3. IAM permissions: Verify Jenkins role has EKS permissions"
    echo "4. Network issues: Ensure Jenkins EC2 is in same VPC as cluster"
    
    echo -e "\n${YELLOW}For detailed troubleshooting, see:${NC}"
    echo "terraform/TERRAFORM_EKS_CONNECTIVITY_FIX.md"
    
    exit $APPLY_EXIT_CODE
fi
