#!/bin/bash

###############################################################################
# Terraform Cleanup Script
# Purpose: Safely remove .terraform directory and lock files with proper
#          permission handling for both Linux and Git-tracked files
###############################################################################

set -e  # Exit on error

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${YELLOW}========================================${NC}"
echo -e "${YELLOW}  Terraform Cleanup Script${NC}"
echo -e "${YELLOW}========================================${NC}"
echo ""

# Function to print status messages
print_status() {
    echo -e "${GREEN}✓${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}⚠${NC} $1"
}

print_error() {
    echo -e "${RED}✗${NC} $1"
}

# Get the directory to clean (default to current directory)
TERRAFORM_DIR="${1:-.}"

if [ ! -d "$TERRAFORM_DIR" ]; then
    print_error "Directory not found: $TERRAFORM_DIR"
    exit 1
fi

cd "$TERRAFORM_DIR"
echo "Working directory: $(pwd)"
echo ""

# Step 1: Remove .terraform directory
if [ -d ".terraform" ]; then
    echo "[1/3] Removing .terraform directory..."
    
    # Reset permissions on all files and directories
    # This handles Git hook files and other protected files
    find .terraform -type f -exec chmod 644 {} \; 2>/dev/null || true
    find .terraform -type d -exec chmod 755 {} \; 2>/dev/null || true
    
    # Remove the directory
    rm -rf .terraform
    
    if [ ! -d ".terraform" ]; then
        print_status ".terraform directory removed successfully"
    else
        print_error "Failed to remove .terraform directory"
        exit 1
    fi
else
    print_warning ".terraform directory not found (already clean)"
fi

echo ""

# Step 2: Remove .terraform.lock.hcl file
if [ -f ".terraform.lock.hcl" ]; then
    echo "[2/3] Removing .terraform.lock.hcl file..."
    rm -f .terraform.lock.hcl
    
    if [ ! -f ".terraform.lock.hcl" ]; then
        print_status ".terraform.lock.hcl removed successfully"
    else
        print_error "Failed to remove .terraform.lock.hcl"
        exit 1
    fi
else
    print_warning ".terraform.lock.hcl not found (already clean)"
fi

echo ""

# Step 3: Verify cleanup
echo "[3/3] Verifying cleanup..."
if [ ! -d ".terraform" ] && [ ! -f ".terraform.lock.hcl" ]; then
    print_status "Cleanup verification passed"
else
    print_error "Cleanup verification failed"
    exit 1
fi

echo ""
echo -e "${YELLOW}========================================${NC}"
echo -e "${GREEN}✓ Cleanup completed successfully!${NC}"
echo -e "${YELLOW}========================================${NC}"
echo ""
echo "You can now run:"
echo "  terraform init"
echo ""

exit 0
