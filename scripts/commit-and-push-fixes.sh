#!/bin/bash

################################################################################
# Commit and Push EKS Fixes to GitHub
# Purpose: Automate git commit and push of all EKS node launch failure fixes
################################################################################

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}Git Commit and Push - EKS Fixes${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

# Change to repository root
cd "$(dirname "$0")/.."

echo -e "${YELLOW}[1/5] Checking git status...${NC}"
git status
echo ""

echo -e "${YELLOW}[2/5] Adding changes to git...${NC}"
git add terraform/modules/eks/main.tf
git add terraform/modules/eks/variables.tf
git add *.md 2>/dev/null || true
git add scripts/*.sh 2>/dev/null || true

echo -e "${GREEN}✓ Files staged${NC}"
echo ""

echo -e "${YELLOW}[3/5] Creating commit...${NC}"
git commit -m "Fix EKS node launch failures - IMDSv2 and bootstrap issues

Critical fixes:
- Changed http_tokens from 'required' to 'optional' to fix AL2023 bootstrap compatibility
- Fixed cluster_version to use variable instead of hardcoded value  
- Removed pre_bootstrap_user_data to prevent bootstrap process interference
- Corrected default cluster version from invalid 1.33 to stable 1.31

Documentation added:
- Comprehensive troubleshooting guide
- Quick fix summary and immediate action guides
- Deployment checklist and change documentation
- Diagnostic and verification scripts

Resolves: NodeCreationFailure - Instances failed to join kubernetes cluster
Resolves: Client.InternalError - Client error on launch

Tested: Fixes verified locally, ready for Jenkins deployment"

echo -e "${GREEN}✓ Commit created${NC}"
echo ""

echo -e "${YELLOW}[4/5] Pushing to GitHub (mainbranch)...${NC}"
if git push origin mainbranch; then
    echo -e "${GREEN}✓ Successfully pushed to GitHub!${NC}"
else
    echo -e "${RED}✗ Push failed!${NC}"
    echo ""
    echo "Possible reasons:"
    echo "1. Authentication required - configure git credentials"
    echo "2. Remote branch diverged - need to pull first"
    echo "3. Network issues - check internet connection"
    echo ""
    echo "Try manual push:"
    echo "  git pull origin mainbranch --rebase"
    echo "  git push origin mainbranch"
    exit 1
fi
echo ""

echo -e "${YELLOW}[5/5] Verifying push...${NC}"
LATEST_COMMIT=$(git log -1 --pretty=format:"%h - %s" 2>/dev/null)
echo -e "Latest commit: ${GREEN}$LATEST_COMMIT${NC}"
echo ""

echo -e "${BLUE}========================================${NC}"
echo -e "${GREEN}✓ SUCCESS!${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""
echo "Next steps:"
echo "1. Verify on GitHub:"
echo "   https://github.com/prabalpratap191/infraeks/commits/mainbranch"
echo ""
echo "2. Check Jenkins pipeline:"
echo "   - Should auto-trigger if webhooks configured"
echo "   - Or manually trigger new build"
echo ""
echo "3. Verify Terraform plan shows:"
echo "   http_tokens = \"optional\""
echo ""
echo "4. Monitor deployment:"
echo "   - EKS cluster: ~10-12 min"
echo "   - Node group: ~5-7 min"
echo "   - Total: ~20 min"
echo ""
echo -e "${GREEN}Good luck with deployment! 🚀${NC}"
