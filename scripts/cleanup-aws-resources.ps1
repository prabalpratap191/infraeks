# cleanup-aws-resources.ps1
# Cleanup orphaned AWS resources before Terraform deployment

param(
    [string]$ClusterName = "meracommerce-dev",
    [string]$Region = "us-east-1"
)

# Color functions for better output
function Write-Success { param([string]$Message) Write-Host $Message -ForegroundColor Green }
function Write-Info { param([string]$Message) Write-Host $Message -ForegroundColor Cyan }
function Write-Warning { param([string]$Message) Write-Host $Message -ForegroundColor Yellow }
function Write-Failure { param([string]$Message) Write-Host $Message -ForegroundColor Red }

Write-Host ""
Write-Host "========================================" -ForegroundColor Magenta
Write-Host "  AWS Resource Cleanup Script" -ForegroundColor Magenta
Write-Host "========================================" -ForegroundColor Magenta
Write-Host ""
Write-Info "Cluster: $ClusterName"
Write-Info "Region: $Region"
Write-Host ""

# Check AWS CLI availability
Write-Info "[1/6] Checking AWS CLI..."
try {
    $awsVersion = aws --version 2>&1
    Write-Success "✅ AWS CLI found: $awsVersion"
} catch {
    Write-Failure "❌ AWS CLI not found! Please install AWS CLI first."
    exit 1
}

# Verify AWS credentials
Write-Info "`n[2/6] Verifying AWS credentials..."
try {
    $identity = aws sts get-caller-identity 2>&1 | ConvertFrom-Json
    Write-Success "✅ Authenticated as: $($identity.Arn)"
} catch {
    Write-Failure "❌ AWS credentials not configured or invalid!"
    Write-Warning "Run: aws configure"
    exit 1
}

# Delete KMS alias
Write-Info "`n[3/6] Deleting KMS alias..."
$kmsAliasName = "alias/eks/$ClusterName"
try {
    $result = aws kms delete-alias --alias-name $kmsAliasName --region $Region 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-Success "✅ KMS alias deleted: $kmsAliasName"
    } else {
        Write-Warning "⚠️ KMS alias not found or already deleted"
    }
} catch {
    Write-Warning "⚠️ KMS alias not found or already deleted"
}

# Delete CloudWatch log group
Write-Info "`n[4/6] Deleting CloudWatch log group..."
$logGroupName = "/aws/eks/$ClusterName/cluster"
try {
    $result = aws logs delete-log-group --log-group-name $logGroupName --region $Region 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-Success "✅ CloudWatch log group deleted: $logGroupName"
    } else {
        Write-Warning "⚠️ Log group not found or already deleted"
    }
} catch {
    Write-Warning "⚠️ Log group not found or already deleted"
}

# Check for EKS cluster
Write-Info "`n[5/6] Checking for EKS cluster..."
try {
    $cluster = aws eks describe-cluster --name $ClusterName --region $Region 2>&1 | ConvertFrom-Json
    if ($cluster.cluster) {
        Write-Failure "❌ EKS cluster '$ClusterName' still exists!"
        Write-Warning "`nYou need to destroy it first:"
        Write-Host "  cd terraform" -ForegroundColor White
        Write-Host "  terraform destroy -var-file=meracommerce-dev.tfvars -auto-approve" -ForegroundColor White
        Write-Host ""
        Write-Warning "Or delete manually:"
        Write-Host "  aws eks delete-cluster --name $ClusterName --region $Region" -ForegroundColor White
    } else {
        Write-Success "✅ No EKS cluster found"
    }
} catch {
    Write-Success "✅ No EKS cluster found"
}

# Check for IAM roles
Write-Info "`n[6/6] Checking for IAM roles..."
try {
    $roles = aws iam list-roles --query "Roles[?contains(RoleName, '$ClusterName')].RoleName" --output json 2>&1 | ConvertFrom-Json
    if ($roles.Count -gt 0) {
        Write-Warning "⚠️ Found $($roles.Count) IAM role(s) with cluster name:"
        foreach ($role in $roles) {
            Write-Host "  - $role" -ForegroundColor Yellow
        }
        Write-Info "`nThese will be managed by Terraform or can be deleted manually if orphaned."
    } else {
        Write-Success "✅ No IAM roles found with cluster name"
    }
} catch {
    Write-Success "✅ No IAM roles found with cluster name"
}

# Summary
Write-Host ""
Write-Host "========================================" -ForegroundColor Magenta
Write-Host "  Cleanup Summary" -ForegroundColor Magenta
Write-Host "========================================" -ForegroundColor Magenta
Write-Host ""
Write-Success "✅ KMS alias: Deleted or didn't exist"
Write-Success "✅ CloudWatch log group: Deleted or didn't exist"
Write-Info "ℹ️ EKS cluster: Checked"
Write-Info "ℹ️ IAM roles: Checked"
Write-Host ""
Write-Host "🎉 Cleanup complete!" -ForegroundColor Green
Write-Host ""
Write-Info "Next steps:"
Write-Host "  1. cd terraform" -ForegroundColor White
Write-Host "  2. terraform init" -ForegroundColor White
Write-Host "  3. terraform apply -var-file=meracommerce-dev.tfvars -auto-approve" -ForegroundColor White
Write-Host ""
