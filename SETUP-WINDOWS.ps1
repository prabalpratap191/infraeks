# Windows Setup Script for EKS Connectivity Fix
# Run this on Windows to prepare files for Linux/EC2 deployment

Write-Host "======================================" -ForegroundColor Blue
Write-Host "  Windows Setup - EKS Connectivity Fix" -ForegroundColor Blue
Write-Host "======================================" -ForegroundColor Blue
Write-Host ""

Write-Host "Step 1: Converting line endings to Unix format..." -ForegroundColor Yellow

$scriptFiles = @(
    "prepare-deployment.sh",
    "terraform\fix-terraform-eks-connectivity.sh",
    "scripts\jenkins-terraform-wrapper.sh",
    "scripts\kubeconfig.sh",
    "scripts\cleanup-aws-resources.sh",
    "scripts\cleanup-terraform.sh",
    "scripts\verify-eks-prerequisites.sh"
)

foreach ($file in $scriptFiles) {
    if (Test-Path $file) {
        $content = Get-Content -Path $file -Raw
        # Convert CRLF to LF
        $content = $content -replace "`r`n", "`n"
        Set-Content -Path $file -Value $content -NoNewline
        Write-Host "  ✓ $file" -ForegroundColor Green
    } else {
        Write-Host "  ⚠ $file not found (might be optional)" -ForegroundColor Yellow
    }
}

Write-Host ""
Write-Host "Step 2: Verifying critical files exist..." -ForegroundColor Yellow

$criticalFiles = @(
    "terraform\provider.tf",
    "terraform\main.tf",
    "terraform\variables.tf",
    "terraform\environments\dev.tfvars",
    "QUICK_FIX_DEPLOYMENT_GUIDE.md",
    "FINAL_FIX_SUMMARY.md"
)

$allExist = $true
foreach ($file in $criticalFiles) {
    if (Test-Path $file) {
        Write-Host "  ✓ $file" -ForegroundColor Green
    } else {
        Write-Host "  ✗ $file MISSING" -ForegroundColor Red
        $allExist = $false
    }
}

if (-not $allExist) {
    Write-Host ""
    Write-Host "ERROR: Some critical files are missing!" -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "Step 3: Creating deployment package info..." -ForegroundColor Yellow

$info = @"
================================================================================
EKS Connectivity Fix - Deployment Package
================================================================================
Prepared on: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
Workstation: $env:COMPUTERNAME
User: $env:USERNAME

FIXES INCLUDED:
--------------
✓ Enhanced Kubernetes provider authentication
✓ Security group rules for cluster API access
✓ Extended timeouts for all resources
✓ Automated deployment scripts
✓ Comprehensive documentation

FILES MODIFIED:
--------------
- terraform/provider.tf
- terraform/modules/eks/main.tf
- terraform/modules/microservices/main.tf
- terraform/modules/aws-load-balancer-controller/main.tf

NEW FILES ADDED:
---------------
- terraform/fix-terraform-eks-connectivity.sh
- terraform/TERRAFORM_EKS_CONNECTIVITY_FIX.md
- scripts/jenkins-terraform-wrapper.sh
- Jenkinsfile.eks-connectivity-fixed
- QUICK_FIX_DEPLOYMENT_GUIDE.md
- EKS_CONNECTIVITY_FIX_README.md
- FINAL_FIX_SUMMARY.md
- prepare-deployment.sh

NEXT STEPS ON EC2/LINUX:
-----------------------
1. Transfer this project to EC2 instance
2. Run: chmod +x prepare-deployment.sh
3. Run: ./prepare-deployment.sh
4. Follow QUICK_FIX_DEPLOYMENT_GUIDE.md

DEPLOYMENT OPTIONS:
------------------
Option 1 (Automated): cd terraform && ./fix-terraform-eks-connectivity.sh
Option 2 (Jenkins): Use Jenkinsfile.eks-connectivity-fixed
Option 3 (Manual): Follow QUICK_FIX_DEPLOYMENT_GUIDE.md

================================================================================
"@

Set-Content -Path "DEPLOYMENT_PACKAGE_INFO.txt" -Value $info
Write-Host "  ✓ DEPLOYMENT_PACKAGE_INFO.txt created" -ForegroundColor Green

Write-Host ""
Write-Host "Step 4: Creating Git commit helper..." -ForegroundColor Yellow

$gitCommands = @"
# Git Commands to Commit and Push Fixes
# Run these commands to push changes to your repository

git add .
git status
git commit -m "Applied EKS connectivity fixes - Complete solution

Fixes applied:
- Enhanced Kubernetes/Helm provider authentication
- Added security group rules for cluster API access
- Extended timeouts for Kubernetes resources
- Created automated deployment scripts
- Added comprehensive documentation

New files:
- Automated fix scripts
- Jenkins wrapper script  
- Improved Jenkinsfile
- Complete documentation suite

Ready for deployment via Jenkins or manual execution."

git push origin mainbranch

echo "Changes pushed successfully!"
echo "Next: Run Jenkins pipeline or deploy manually on EC2"
"@

Set-Content -Path "git-commit-fixes.sh" -Value $gitCommands
Write-Host "  ✓ git-commit-fixes.sh created" -ForegroundColor Green

Write-Host ""
Write-Host "======================================" -ForegroundColor Green
Write-Host "  Setup Complete!" -ForegroundColor Green  
Write-Host "======================================" -ForegroundColor Green

Write-Host ""
Write-Host "What was done:" -ForegroundColor Cyan
Write-Host "  ✓ Converted shell scripts to Unix line endings" -ForegroundColor White
Write-Host "  ✓ Verified all critical files exist" -ForegroundColor White
Write-Host "  ✓ Created deployment package info" -ForegroundColor White
Write-Host "  ✓ Created Git commit helper script" -ForegroundColor White

Write-Host ""
Write-Host "Next Steps:" -ForegroundColor Cyan
Write-Host "  1. Review: FINAL_FIX_SUMMARY.md" -ForegroundColor Yellow
Write-Host "  2. Commit changes:" -ForegroundColor Yellow
Write-Host "     git add ." -ForegroundColor White
Write-Host "     git commit -m 'Applied EKS connectivity fixes'" -ForegroundColor White
Write-Host "     git push origin mainbranch" -ForegroundColor White
Write-Host "  3. On EC2: Run prepare-deployment.sh" -ForegroundColor Yellow
Write-Host "  4. Deploy: Follow QUICK_FIX_DEPLOYMENT_GUIDE.md" -ForegroundColor Yellow

Write-Host ""
Write-Host "Documentation:" -ForegroundColor Cyan
Write-Host "  📚 Start here: QUICK_FIX_DEPLOYMENT_GUIDE.md" -ForegroundColor White
Write-Host "  🔧 Troubleshooting: terraform/TERRAFORM_EKS_CONNECTIVITY_FIX.md" -ForegroundColor White
Write-Host "  📋 Summary: FINAL_FIX_SUMMARY.md" -ForegroundColor White

Write-Host ""
Write-Host "Ready to deploy! 🚀" -ForegroundColor Green
Write-Host ""
