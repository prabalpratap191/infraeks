#!/bin/bash

# Fix Terraform EKS Connectivity Issues
# This script addresses the timeout errors when creating Kubernetes resources from EC2

set -e

echo "======================================"
echo "EKS Connectivity Fix Script"
echo "======================================"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

CLUSTER_NAME="meracommerce-dev-cluster"
REGION="us-east-1"

echo -e "${YELLOW}Step 1: Checking prerequisites...${NC}"

# Check if AWS CLI is installed
if ! command -v aws &> /dev/null; then
    echo -e "${RED}ERROR: AWS CLI is not installed. Please install it first.${NC}"
    exit 1
fi

# Check if kubectl is installed
if ! command -v kubectl &> /dev/null; then
    echo -e "${RED}ERROR: kubectl is not installed. Please install it first.${NC}"
    exit 1
fi

echo -e "${GREEN}Prerequisites check passed!${NC}"

echo -e "${YELLOW}Step 2: Updating kubeconfig...${NC}"
# Update kubeconfig to use the cluster
aws eks update-kubeconfig --name $CLUSTER_NAME --region $REGION

if [ $? -eq 0 ]; then
    echo -e "${GREEN}Kubeconfig updated successfully!${NC}"
else
    echo -e "${RED}Failed to update kubeconfig. Check your AWS credentials and cluster name.${NC}"
    exit 1
fi

echo -e "${YELLOW}Step 3: Testing cluster connectivity...${NC}"
# Test cluster connectivity
kubectl cluster-info

if [ $? -eq 0 ]; then
    echo -e "${GREEN}Cluster connectivity test passed!${NC}"
else
    echo -e "${RED}Cannot connect to the cluster. Possible issues:${NC}"
    echo -e "${RED}  1. EC2 instance security group doesn't allow access to cluster${NC}"
    echo -e "${RED}  2. Cluster endpoint is not accessible from this EC2 instance${NC}"
    echo -e "${RED}  3. IAM permissions are insufficient${NC}"
    exit 1
fi

echo -e "${YELLOW}Step 4: Checking existing Kubernetes resources...${NC}"
# Check if namespaces already exist
for ns in order-service-ns catalog-service-ns customer-service-ns; do
    if kubectl get namespace $ns &> /dev/null; then
        echo -e "${YELLOW}Namespace $ns already exists. Importing to Terraform state...${NC}"
        terraform import module.${ns%-ns}_service.kubernetes_namespace.microservice $ns || true
    fi
done

# Check if service account exists
if kubectl get serviceaccount aws-load-balancer-controller -n kube-system &> /dev/null; then
    echo -e "${YELLOW}Service account aws-load-balancer-controller already exists. Importing...${NC}"
    terraform import module.aws_load_balancer_controller.kubernetes_service_account.aws_load_balancer_controller kube-system/aws-load-balancer-controller || true
fi

echo -e "${YELLOW}Step 5: Re-initializing Terraform...${NC}"
terraform init -upgrade

echo -e "${GREEN}======================================${NC}"
echo -e "${GREEN}Fix applied successfully!${NC}"
echo -e "${GREEN}======================================${NC}"

echo -e "${YELLOW}Next steps:${NC}"
echo "1. Run: terraform plan -var-file=environments/dev.tfvars"
echo "2. Review the plan carefully"
echo "3. Run: terraform apply -var-file=environments/dev.tfvars"

echo -e "\n${YELLOW}If you still encounter timeout errors:${NC}"
echo "1. Check EC2 instance security group allows outbound HTTPS (443)"
echo "2. Ensure EC2 instance has proper IAM role with EKS permissions"
echo "3. Verify VPC DNS resolution is enabled"
echo "4. Check if cluster endpoint is reachable: curl -k https://\$(aws eks describe-cluster --name $CLUSTER_NAME --region $REGION --query 'cluster.endpoint' --output text)"
