#!/bin/bash

################################################################################
# Terraform Cleanup Script
# Purpose: Clean Terraform cache and lock files before deployment
# Usage: ./cleanup-terraform.sh [terraform_directory]
################################################################################

set -e

TERRAFORM_DIR="${1:-.}"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo "========================================"
echo "Terraform Cleanup Script"
echo "========================================"
echo "Target directory: $TERRAFORM_DIR"
echo ""

cd "$TERRAFORM_DIR"

echo -e "${YELLOW}[1/4] Removing Terraform cache...${NC}"
if [ -d ".terraform" ]; then
    rm -rf .terraform
    echo -e "${GREEN}✓ Removed .terraform directory${NC}"
else
    echo "  No .terraform directory found"
fi

echo ""
echo -e "${YELLOW}[2/4] Removing lock file...${NC}"
if [ -f ".terraform.lock.hcl" ]; then
    rm -f .terraform.lock.hcl
    echo -e "${GREEN}✓ Removed .terraform.lock.hcl${NC}"
else
    echo "  No lock file found"
fi

echo ""
echo -e "${YELLOW}[3/4] Cleaning backup files...${NC}"
if [ -f "terraform.tfstate.backup" ]; then
    rm -f terraform.tfstate.backup
    echo -e "${GREEN}✓ Removed terraform.tfstate.backup${NC}"
else
    echo "  No backup file found"
fi

echo ""
echo -e "${YELLOW}[4/4] Removing plan files...${NC}"
rm -f *.tfplan 2>/dev/null || true
rm -f .terraform.tfstate.lock.info 2>/dev/null || true
echo -e "${GREEN}✓ Cleaned plan files${NC}"

echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}✓ Terraform cleanup complete!${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo "Ready for: terraform init"
