#!/bin/bash

# Apply Terraform with Targeted Updates
# This script updates only the EKS module first to apply security group changes

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}======================================${NC}"
echo -e "${BLUE}Targeted Terraform Apply${NC}"
echo -e "${BLUE}======================================${NC}"

echo -e "\n${YELLOW}Step 1: Initialize Terraform...${NC}"
terraform init -upgrade

echo -e "\n${YELLOW}Step 2: Apply ONLY EKS module changes (security groups)...${NC}"
echo -e "${BLUE}This will update the cluster security group with the VPC access rule${NC}"

terraform apply \
  -target=module.eks \
  -var-file=environments/dev.tfvars \
  -auto-approve

if [ $? -eq 0 ]; then
    echo -e "\n${GREEN}✓ EKS module updated successfully!${NC}"
else
    echo -e "\n${RED}✗ Failed to update EKS module${NC}"
    exit 1
fi

echo -e "\n${YELLOW}Step 3: Waiting for security group changes to propagate...${NC}"
sleep 10

echo -e "\n${YELLOW}Step 4: Testing cluster connectivity...${NC}"
kubectl cluster-info

if [ $? -eq 0 ]; then
    echo -e "\n${GREEN}✓ Cluster is now reachable!${NC}"
    
    echo -e "\n${YELLOW}Step 5: Applying remaining Terraform resources...${NC}"
    terraform apply -var-file=environments/dev.tfvars -auto-approve
    
    if [ $? -eq 0 ]; then
        echo -e "\n${GREEN}======================================${NC}"
        echo -e "${GREEN}✓ Complete deployment successful!${NC}"
        echo -e "${GREEN}======================================${NC}"
        
        echo -e "\n${BLUE}Verifying deployment...${NC}"
        kubectl get nodes
        kubectl get namespaces | grep service-ns
        kubectl get sa -A | grep -E 'order-sa|catalog-sa|customer-sa'
    else
        echo -e "\n${RED}Failed to apply remaining resources${NC}"
        exit 1
    fi
else
    echo -e "\n${RED}Still cannot reach cluster after security group update${NC}"
    echo -e "${YELLOW}Run emergency-fix-security-group.sh for detailed diagnostics${NC}"
    exit 1
fi
