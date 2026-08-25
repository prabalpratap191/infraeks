#!/bin/bash
# Bash Script to Initialize Git and Push to Remote Repository
# Run this script from the project root directory

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Functions
print_success() { echo -e "${GREEN}$1${NC}"; }
print_info() { echo -e "${CYAN}$1${NC}"; }
print_warning() { echo -e "${YELLOW}$1${NC}"; }
print_error() { echo -e "${RED}$1${NC}"; }

# Header
print_info "======================================"
print_info "Git Repository Setup Script"
print_info "======================================"
echo ""

# Get user input
read -p "Enter your Git remote repository URL: " remoteUrl
read -p "Enter branch name (default: main): " branchName
branchName=${branchName:-main}

read -p "Enter your Git username: " userName
read -p "Enter your Git email: " userEmail

echo ""
print_info "======================================"
print_info "Configuration Summary:"
print_info "======================================"
print_info "Remote URL: $remoteUrl"
print_info "Branch: $branchName"
print_info "Username: $userName"
print_info "Email: $userEmail"
echo ""

read -p "Proceed with Git setup? (y/n): " confirm
if [ "$confirm" != "y" ]; then
    print_warning "Setup cancelled."
    exit 0
fi

echo ""
print_info "Starting Git setup..."
echo ""

# Step 1: Check Git installation
print_info "[1/8] Checking Git installation..."
if command -v git &> /dev/null; then
    gitVersion=$(git --version)
    print_success "  ✓ Git is installed: $gitVersion"
else
    print_error "  ✗ Git is not installed. Please install Git first."
    print_info "  Download from: https://git-scm.com/downloads"
    exit 1
fi

# Step 2: Initialize Git
print_info "[2/8] Initializing Git repository..."
if [ -d ".git" ]; then
    print_warning "  ! Git repository already initialized"
else
    git init
    if [ $? -eq 0 ]; then
        print_success "  ✓ Git repository initialized"
    else
        print_error "  ✗ Failed to initialize Git repository"
        exit 1
    fi
fi

# Step 3: Configure Git user
print_info "[3/8] Configuring Git user..."
git config user.name "$userName"
git config user.email "$userEmail"
print_success "  ✓ Git user configured"

# Step 4: Check .gitignore
print_info "[4/8] Checking .gitignore..."
if [ -f ".gitignore" ]; then
    print_success "  ✓ .gitignore exists"
else
    print_warning "  ! .gitignore not found. Please create it first."
fi

# Step 5: Stage files
print_info "[5/8] Staging files..."
git add .
if [ $? -eq 0 ]; then
    fileCount=$(git diff --cached --numstat | wc -l)
    print_success "  ✓ Staged $fileCount files"
else
    print_error "  ✗ Failed to stage files"
    exit 1
fi

# Step 6: Show status
print_info "[6/8] Files to be committed:"
git status --short
echo ""

read -p "Proceed with commit? (y/n): " confirmCommit
if [ "$confirmCommit" != "y" ]; then
    print_warning "Commit cancelled. Files are still staged."
    exit 0
fi

# Step 7: Create commit
print_info "[7/8] Creating initial commit..."
git commit -m "Initial commit: Multi-microservices EKS infrastructure

- Added Terraform modules for microservices (order, catalog, customer)
- Added AWS Load Balancer Controller module
- Created Kubernetes manifests for all services
- Added Jenkins CI/CD pipeline templates
- Implemented IRSA, RBAC, and Network Policies
- Added comprehensive documentation"

if [ $? -eq 0 ]; then
    print_success "  ✓ Initial commit created"
else
    print_error "  ✗ Failed to create commit"
    exit 1
fi

# Set branch name
print_info "Setting branch name to '$branchName'..."
git branch -M $branchName
print_success "  ✓ Branch set to '$branchName'"

# Step 8: Add remote and push
print_info "[8/8] Adding remote and pushing..."

# Check existing remote
existingRemote=$(git remote get-url origin 2>/dev/null)
if [ -n "$existingRemote" ]; then
    print_warning "  ! Remote 'origin' already exists: $existingRemote"
    read -p "Update remote URL? (y/n): " updateRemote
    if [ "$updateRemote" = "y" ]; then
        git remote set-url origin $remoteUrl
        print_success "  ✓ Remote URL updated"
    fi
else
    git remote add origin $remoteUrl
    print_success "  ✓ Remote 'origin' added"
fi

# Push
print_info "Pushing to remote repository..."
print_warning "You may be prompted for credentials."
echo ""

git push -u origin $branchName

if [ $? -eq 0 ]; then
    echo ""
    print_success "======================================"
    print_success "  SUCCESS! Repository pushed to remote"
    print_success "======================================"
    echo ""
    print_info "Repository URL: $remoteUrl"
    print_info "Branch: $branchName"
    echo ""
    print_success "Next steps:"
    print_success "1. Verify files on $remoteUrl"
    print_success "2. Follow IMPLEMENTATION_GUIDE.md to deploy infrastructure"
    print_success "3. Setup Jenkins pipelines for microservices"
else
    echo ""
    print_error "======================================"
    print_error "  FAILED to push to remote repository"
    print_error "======================================"
    echo ""
    print_warning "Common issues:"
    print_warning "1. Authentication failed - Use Personal Access Token (PAT)"
    print_warning "2. Remote not empty - Try: git pull origin $branchName --allow-unrelated-histories"
    print_warning "3. Network issues - Check internet connection"
    echo ""
    print_info "For troubleshooting, see GIT_SETUP_GUIDE.md"
    exit 1
fi
