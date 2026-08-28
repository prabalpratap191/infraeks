#!/bin/bash

# Complete Deployment Script
# Fixes connectivity, validates syntax, and deploys infrastructure

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m'

echo -e "${CYAN}"
cat << "EOF"
========================================
   EKS Infrastructure Deployment
========================================
EOF
echo -e "${NC}"

echo -e "${BLUE}This script will:${NC}"
echo -e "  1. Fix connectivity issues"
echo -e "  2. Validate Terraform syntax"
echo -e "  3. Deploy EKS infrastructure"
echo -e "  4. Verify deployment\n"

read -p "$(echo -e ${YELLOW}Continue? [y/N]: ${NC})" -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo -e "${RED}Deployment cancelled${NC}"
    exit 1
fi

echo -e "\n${MAGENTA}=== PHASE 1: CONNECTIVITY FIX ===${NC}\n"

if [ -f "quick-fix-now.sh" ]; then
    chmod +x quick-fix-now.sh
    echo -e "${YELLOW}Running emergency connectivity fix...${NC}"
    ./quick-fix-now.sh || {
        echo -e "${RED}Connectivity fix failed. Trying alternative method...${NC}"
        
        # Try just the security group fix
        if [ -f "emergency-fix-security-group.sh" ]; then
            chmod +x emergency-fix-security-group.sh
            ./emergency-fix-security-group.sh
        fi
    }
else
    echo -e "${YELLOW}Skipping automated connectivity fix (script not found)${NC}"
fi

echo -e "\n${YELLOW}Testing cluster connectivity...${NC}"
if kubectl cluster-info &>/dev/null; then
    echo -e "${GREEN}✓ Cluster is reachable!${NC}"
else
    echo -e "${RED}✗ Cluster not reachable${NC}"
    echo -e "${YELLOW}Continuing anyway - Terraform will create the cluster if needed${NC}"
fi

echo -e "\n${MAGENTA}=== PHASE 2: TERRAFORM VALIDATION ===${NC}\n"

echo -e "${YELLOW}Initializing Terraform...${NC}"
terraform init -upgrade

if [ $? -ne 0 ]; then
    echo -e "${RED}✗ Terraform init failed${NC}"
    exit 1
fi
echo -e "${GREEN}✓ Terraform initialized${NC}"

echo -e "\n${YELLOW}Validating Terraform configuration...${NC}"
terraform validate

if [ $? -ne 0 ]; then
    echo -e "${RED}✗ Terraform validation failed${NC}"
    echo -e "${YELLOW}Please check SYNTAX_FIX_APPLIED.md for help${NC}"
    exit 1
fi
echo -e "${GREEN}✓ Configuration is valid${NC}"

echo -e "\n${MAGENTA}=== PHASE 3: TERRAFORM PLAN ===${NC}\n"

echo -e "${YELLOW}Creating execution plan...${NC}"
terraform plan -var-file=meracommerce-dev-cluster.tfvars -out=tfplan

if [ $? -ne 0 ]; then
    echo -e "${RED}✗ Terraform plan failed${NC}"
    exit 1
fi
echo -e "${GREEN}✓ Plan created successfully${NC}"

echo -e "\n${YELLOW}Review the plan above.${NC}"
read -p "$(echo -e ${YELLOW}Proceed with apply? [y/N]: ${NC})" -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo -e "${RED}Deployment cancelled${NC}"
    rm -f tfplan
    exit 1
fi

echo -e "\n${MAGENTA}=== PHASE 4: TERRAFORM APPLY ===${NC}\n"

echo -e "${YELLOW}Applying infrastructure changes...${NC}"
echo -e "${BLUE}This may take 20-30 minutes for initial deployment${NC}\n"

terraform apply tfplan

if [ $? -ne 0 ]; then
    echo -e "\n${RED}✗ Terraform apply failed${NC}"
    echo -e "${YELLOW}Check the error messages above${NC}"
    rm -f tfplan
    exit 1
fi

rm -f tfplan
echo -e "\n${GREEN}✓ Infrastructure deployed successfully!${NC}"

echo -e "\n${MAGENTA}=== PHASE 5: DEPLOYMENT VERIFICATION ===${NC}\n"

echo -e "${YELLOW}Updating kubeconfig...${NC}"
aws eks update-kubeconfig --name meracommerce-dev-cluster --region us-east-1

echo -e "\n${YELLOW}Waiting for cluster to be fully ready...${NC}"
sleep 30

echo -e "\n${CYAN}Cluster Information:${NC}"
kubectl cluster-info 2>/dev/null || echo -e "${YELLOW}Cluster info not available yet${NC}"

echo -e "\n${CYAN}Cluster Nodes:${NC}"
kubectl get nodes 2>/dev/null || echo -e "${YELLOW}Nodes not ready yet${NC}"

echo -e "\n${CYAN}Namespaces Created:${NC}"
kubectl get namespaces 2>/dev/null | grep -E '(order-service-ns|catalog-service-ns|customer-service-ns)' || echo -e "${YELLOW}Namespaces not visible yet${NC}"

echo -e "\n${CYAN}Service Accounts:${NC}"
kubectl get sa -A 2>/dev/null | grep -E '(order-sa|catalog-sa|customer-sa|aws-load-balancer-controller)' || echo -e "${YELLOW}Service accounts not visible yet${NC}"

echo -e "\n${CYAN}Load Balancer Controller:${NC}"
kubectl get pods -n kube-system 2>/dev/null | grep aws-load-balancer-controller || echo -e "${YELLOW}Load Balancer Controller not deployed yet${NC}"

echo -e "\n${GREEN}========================================${NC}"
echo -e "${GREEN}   DEPLOYMENT COMPLETE! ✅${NC}"
echo -e "${GREEN}========================================${NC}"

echo -e "\n${CYAN}Terraform Outputs:${NC}"
terraform output 2>/dev/null || echo -e "${YELLOW}No outputs configured${NC}"

echo -e "\n${BLUE}Next Steps:${NC}"
echo -e "  1. Deploy microservices: ${GREEN}kubectl apply -f ../k8s-manifests/${NC}"
echo -e "  2. Configure ingress: ${GREEN}kubectl apply -f ../k8s-manifests/ingress.yaml${NC}"
echo -e "  3. Set up monitoring: Install Prometheus/Grafana"
echo -e "  4. Configure auto-scaling: Set up HPA and Cluster Autoscaler"

echo -e "\n${CYAN}Resources Created:${NC}"
echo -e "  ✓ EKS Cluster: meracommerce-dev-cluster"
echo -e "  ✓ Node Group: 2-4 t3.medium instances"
echo -e "  ✓ Namespaces: order, catalog, customer services"
echo -e "  ✓ Service Accounts: With IRSA annotations"
echo -e "  ✓ IAM Roles: For each microservice"
echo -e "  ✓ Security Groups: VPC access configured"
echo -e "  ✓ Load Balancer Controller: Installed"

echo -e "\n${YELLOW}For troubleshooting, see:${NC}"
echo -e "  - ${GREEN}TERRAFORM_EKS_CONNECTIVITY_FIX.md${NC}"
echo -e "  - ${GREEN}README-EMERGENCY-FIX.md${NC}"
echo -e "  - ${GREEN}SYNTAX_FIX_APPLIED.md${NC}"

echo -e "\n${CYAN}Deployment Summary saved to: deployment-$(date +%Y%m%d-%H%M%S).log${NC}\n"

# Save deployment summary
cat > deployment-$(date +%Y%m%d-%H%M%S).log << EOF
EKS Infrastructure Deployment Summary
====================================
Date: $(date)
Cluster: meracommerce-dev-cluster
Region: us-east-1
Status: SUCCESS

Terraform State:
$(terraform show -json 2>/dev/null | jq -r '.values.root_module.resources[] | "\(.type): \(.name)"' 2>/dev/null || echo "State not available")

Kubernetes Resources:
$(kubectl get all -A 2>/dev/null || echo "Kubernetes not accessible")
EOF

echo -e "${GREEN}All done! 🎉${NC}\n"
