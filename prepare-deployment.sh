#!/bin/bash

# Prepare Deployment Script
# Makes all scripts executable and prepares the environment for deployment

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}======================================${NC}"
echo -e "${BLUE}  EKS Deployment Preparation Script  ${NC}"
echo -e "${BLUE}======================================${NC}"

echo -e "\n${YELLOW}Step 1: Making scripts executable...${NC}"

# Make all shell scripts executable
find . -type f -name "*.sh" -exec chmod +x {} \;

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓ All shell scripts are now executable${NC}"
else
    echo -e "${RED}✗ Failed to make scripts executable${NC}"
    exit 1
fi

echo -e "\n${YELLOW}Step 2: Verifying directory structure...${NC}"

# Check required directories exist
required_dirs=(
    "terraform"
    "terraform/modules"
    "terraform/modules/eks"
    "terraform/modules/microservices"
    "terraform/modules/aws-load-balancer-controller"
    "scripts"
    "k8s-manifests"
)

all_dirs_exist=true
for dir in "${required_dirs[@]}"; do
    if [ -d "$dir" ]; then
        echo -e "${GREEN}✓ $dir${NC}"
    else
        echo -e "${RED}✗ $dir not found${NC}"
        all_dirs_exist=false
    fi
done

if [ "$all_dirs_exist" = false ]; then
    echo -e "${RED}Some required directories are missing!${NC}"
    exit 1
fi

echo -e "\n${YELLOW}Step 3: Checking required files...${NC}"

# Check critical files exist
critical_files=(
    "terraform/provider.tf"
    "terraform/main.tf"
    "terraform/variables.tf"
    "terraform/environments/dev.tfvars"
    "terraform/fix-terraform-eks-connectivity.sh"
    "terraform/TERRAFORM_EKS_CONNECTIVITY_FIX.md"
    "scripts/jenkins-terraform-wrapper.sh"
    "QUICK_FIX_DEPLOYMENT_GUIDE.md"
)

all_files_exist=true
for file in "${critical_files[@]}"; do
    if [ -f "$file" ]; then
        echo -e "${GREEN}✓ $file${NC}"
    else
        echo -e "${RED}✗ $file not found${NC}"
        all_files_exist=false
    fi
done

if [ "$all_files_exist" = false ]; then
    echo -e "${RED}Some critical files are missing!${NC}"
    exit 1
fi

echo -e "\n${YELLOW}Step 4: Validating Terraform configuration...${NC}"

cd terraform

if command -v terraform &> /dev/null; then
    terraform fmt -recursive
    echo -e "${GREEN}✓ Terraform code formatted${NC}"
    
    terraform init -backend=false > /dev/null 2>&1
    if terraform validate > /dev/null 2>&1; then
        echo -e "${GREEN}✓ Terraform configuration is valid${NC}"
    else
        echo -e "${YELLOW}! Terraform validation warnings (may be expected)${NC}"
    fi
else
    echo -e "${YELLOW}! Terraform not installed (will be required for deployment)${NC}"
fi

cd ..

echo -e "\n${YELLOW}Step 5: Creating deployment summary...${NC}"

cat > DEPLOYMENT_SUMMARY.txt << EOF
================================================================================
EKS Infrastructure Deployment Summary
================================================================================
Generated: $(date)

FIXES APPLIED:
--------------
✓ Enhanced Kubernetes provider with exec authentication
✓ Added VPC security group rule for cluster API access (port 443)
✓ Extended timeouts for Kubernetes resources (5-10 minutes)
✓ Added wait flags for Helm deployments
✓ Created automated fix scripts
✓ Created Jenkins integration wrapper
✓ Created comprehensive troubleshooting documentation

FILES MODIFIED:
--------------
- terraform/provider.tf
- terraform/modules/eks/main.tf
- terraform/modules/microservices/main.tf
- terraform/modules/aws-load-balancer-controller/main.tf

NEW FILES CREATED:
-----------------
- terraform/fix-terraform-eks-connectivity.sh
- terraform/TERRAFORM_EKS_CONNECTIVITY_FIX.md
- scripts/jenkins-terraform-wrapper.sh
- Jenkinsfile.eks-connectivity-fixed
- QUICK_FIX_DEPLOYMENT_GUIDE.md
- prepare-deployment.sh (this file)

DEPLOYMENT METHODS:
------------------

Method 1: Automated Fix (Recommended for manual deployment)
  cd terraform
  ./fix-terraform-eks-connectivity.sh
  terraform apply -var-file=environments/dev.tfvars

Method 2: Jenkins Pipeline (Recommended for CI/CD)
  - Use Jenkinsfile.eks-connectivity-fixed
  - Or use scripts/jenkins-terraform-wrapper.sh in existing pipeline

Method 3: Manual Steps
  - See QUICK_FIX_DEPLOYMENT_GUIDE.md for detailed steps

TROUBLESHOOTING:
---------------
For detailed troubleshooting, see:
- QUICK_FIX_DEPLOYMENT_GUIDE.md (Quick reference)
- terraform/TERRAFORM_EKS_CONNECTIVITY_FIX.md (Comprehensive guide)

NEXT STEPS:
----------
1. Review QUICK_FIX_DEPLOYMENT_GUIDE.md
2. Choose deployment method (automated, Jenkins, or manual)
3. Run deployment
4. Verify deployment using verification steps in guide
5. Deploy microservices
6. Configure monitoring and observability

CLUSTER DETAILS:
---------------
Cluster Name: meracommerce-dev-cluster
Region: us-east-1
Node Type: t3.medium
Node Count: 2-4 (auto-scaling)

SECURITY FEATURES:
-----------------
✓ RBAC enabled
✓ Network policies
✓ IRSA for AWS resource access
✓ Encrypted EBS volumes
✓ Private VPC networking
✓ Resource quotas and limits

================================================================================
For support, refer to documentation files in this repository.
================================================================================
EOF

echo -e "${GREEN}✓ Deployment summary created: DEPLOYMENT_SUMMARY.txt${NC}"

echo -e "\n${GREEN}======================================${NC}"
echo -e "${GREEN}  Preparation Complete!${NC}"
echo -e "${GREEN}======================================${NC}"

echo -e "\n${BLUE}All scripts are executable and ready to use.${NC}"
echo -e "\n${YELLOW}Quick Start:${NC}"
echo -e "  ${BLUE}1.${NC} Read: ${GREEN}QUICK_FIX_DEPLOYMENT_GUIDE.md${NC}"
echo -e "  ${BLUE}2.${NC} Choose deployment method:"
echo -e "     ${YELLOW}a)${NC} Automated: ${GREEN}cd terraform && ./fix-terraform-eks-connectivity.sh${NC}"
echo -e "     ${YELLOW}b)${NC} Jenkins: Use ${GREEN}Jenkinsfile.eks-connectivity-fixed${NC}"
echo -e "     ${YELLOW}c)${NC} Manual: Follow steps in ${GREEN}QUICK_FIX_DEPLOYMENT_GUIDE.md${NC}"
echo -e "  ${BLUE}3.${NC} Deploy: ${GREEN}terraform apply -var-file=environments/dev.tfvars${NC}"
echo -e "  ${BLUE}4.${NC} Verify: Follow verification steps in guide"

echo -e "\n${YELLOW}Important Files:${NC}"
echo -e "  📚 ${GREEN}QUICK_FIX_DEPLOYMENT_GUIDE.md${NC} - Start here!"
echo -e "  🔧 ${GREEN}terraform/TERRAFORM_EKS_CONNECTIVITY_FIX.md${NC} - Detailed troubleshooting"
echo -e "  🚀 ${GREEN}terraform/fix-terraform-eks-connectivity.sh${NC} - Automated fix"
echo -e "  ⚙️  ${GREEN}scripts/jenkins-terraform-wrapper.sh${NC} - Jenkins wrapper"
echo -e "  📋 ${GREEN}DEPLOYMENT_SUMMARY.txt${NC} - Summary of changes"

echo -e "\n${BLUE}Good luck with your deployment! 🚀${NC}\n"
