#!/bin/bash

# Quick Fix - Runs all fixes in sequence

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}  EKS Connectivity - QUICK FIX${NC}"
echo -e "${BLUE}========================================${NC}"

echo -e "\n${YELLOW}Running emergency security group fix...${NC}"
chmod +x emergency-fix-security-group.sh
./emergency-fix-security-group.sh

echo -e "\n${YELLOW}Waiting 10 seconds for changes to propagate...${NC}"
sleep 10

echo -e "\n${YELLOW}Testing connectivity...${NC}"
if kubectl cluster-info &>/dev/null; then
    echo -e "${GREEN}✓ Cluster is reachable! Proceeding with Terraform...${NC}"
    
    chmod +x apply-terraform-with-target.sh
    ./apply-terraform-with-target.sh
else
    echo -e "${RED}✗ Cluster still not reachable${NC}"
    echo -e "${YELLOW}Please review sg-debug-info.txt for diagnostics${NC}"
    echo -e "\n${YELLOW}Common solutions:${NC}"
    echo "1. Check if cluster endpoint is public:"
    echo "   aws eks describe-cluster --name meracommerce-dev-cluster --region us-east-1 --query 'cluster.resourcesVpcConfig.endpointPublicAccess'"
    echo ""
    echo "2. Enable public access if needed:"
    echo "   aws eks update-cluster-config --name meracommerce-dev-cluster --region us-east-1 --resources-vpc-config endpointPublicAccess=true"
    echo ""
    echo "3. Check VPC DNS:"
    echo "   aws ec2 describe-vpc-attribute --vpc-id <vpc-id> --attribute enableDnsHostnames"
    echo "   aws ec2 describe-vpc-attribute --vpc-id <vpc-id> --attribute enableDnsSupport"
    exit 1
fi
