# PowerShell Script to Initialize Git and Push to Remote Repository
# Run this script from the project root directory

# Color output functions
function Write-Success { param($msg) Write-Host $msg -ForegroundColor Green }
function Write-Info { param($msg) Write-Host $msg -ForegroundColor Cyan }
function Write-Warning { param($msg) Write-Host $msg -ForegroundColor Yellow }
function Write-Error { param($msg) Write-Host $msg -ForegroundColor Red }

# Configuration
Write-Info "======================================"
Write-Info "Git Repository Setup Script"
Write-Info "======================================"
Write-Host ""

# Get user input for remote repository
$remoteUrl = Read-Host "Enter your Git remote repository URL (e.g., https://github.com/username/infraeks.git)"
$branchName = Read-Host "Enter branch name (default: main)"
if ([string]::IsNullOrWhiteSpace($branchName)) {
    $branchName = "main"
}

# Get user details
$userName = Read-Host "Enter your Git username"
$userEmail = Read-Host "Enter your Git email"

Write-Host ""
Write-Info "======================================"
Write-Info "Configuration Summary:"
Write-Info "======================================"
Write-Info "Remote URL: $remoteUrl"
Write-Info "Branch: $branchName"
Write-Info "Username: $userName"
Write-Info "Email: $userEmail"
Write-Host ""

$confirm = Read-Host "Proceed with Git setup? (y/n)"
if ($confirm -ne "y") {
    Write-Warning "Setup cancelled."
    exit
}

Write-Host ""
Write-Info "Starting Git setup..."
Write-Host ""

# Step 1: Check if Git is installed
Write-Info "[1/8] Checking Git installation..."
try {
    $gitVersion = git --version
    Write-Success "  ✓ Git is installed: $gitVersion"
} catch {
    Write-Error "  ✗ Git is not installed. Please install Git first."
    Write-Info "  Download from: https://git-scm.com/downloads"
    exit 1
}

# Step 2: Initialize Git repository
Write-Info "[2/8] Initializing Git repository..."
if (Test-Path ".git") {
    Write-Warning "  ! Git repository already initialized"
} else {
    git init
    if ($LASTEXITCODE -eq 0) {
        Write-Success "  ✓ Git repository initialized"
    } else {
        Write-Error "  ✗ Failed to initialize Git repository"
        exit 1
    }
}

# Step 3: Configure Git user
Write-Info "[3/8] Configuring Git user..."
git config user.name "$userName"
git config user.email "$userEmail"
Write-Success "  ✓ Git user configured"

# Step 4: Create/verify .gitignore
Write-Info "[4/8] Checking .gitignore..."
if (Test-Path ".gitignore") {
    Write-Success "  ✓ .gitignore already exists"
} else {
    Write-Warning "  ! .gitignore not found. Please create it first."
}

# Step 5: Stage all files
Write-Info "[5/8] Staging files..."
git add .
if ($LASTEXITCODE -eq 0) {
    $fileCount = (git diff --cached --numstat | Measure-Object).Count
    Write-Success "  ✓ Staged $fileCount files"
} else {
    Write-Error "  ✗ Failed to stage files"
    exit 1
}

# Step 6: Show files to be committed
Write-Info "[6/8] Files to be committed:"
git status --short
Write-Host ""

$confirmCommit = Read-Host "Proceed with commit? (y/n)"
if ($confirmCommit -ne "y") {
    Write-Warning "Commit cancelled. Files are still staged."
    exit
}

# Step 7: Create initial commit
Write-Info "[7/8] Creating initial commit..."
$commitMessage = @"
Initial commit: Multi-microservices EKS infrastructure

- Added Terraform modules for microservices (order, catalog, customer)
- Added AWS Load Balancer Controller module
- Created Kubernetes manifests for all services
- Added Jenkins CI/CD pipeline templates
- Implemented IRSA, RBAC, and Network Policies
- Added comprehensive documentation
"@

git commit -m "$commitMessage"
if ($LASTEXITCODE -eq 0) {
    Write-Success "  ✓ Initial commit created"
} else {
    Write-Error "  ✗ Failed to create commit"
    exit 1
}

# Set branch name
Write-Info "Setting branch name to '$branchName'..."
git branch -M $branchName
Write-Success "  ✓ Branch set to '$branchName'"

# Step 8: Add remote and push
Write-Info "[8/8] Adding remote and pushing..."

# Check if remote already exists
$existingRemote = git remote get-url origin 2>$null
if ($existingRemote) {
    Write-Warning "  ! Remote 'origin' already exists: $existingRemote"
    $updateRemote = Read-Host "Update remote URL? (y/n)"
    if ($updateRemote -eq "y") {
        git remote set-url origin $remoteUrl
        Write-Success "  ✓ Remote URL updated"
    }
} else {
    git remote add origin $remoteUrl
    Write-Success "  ✓ Remote 'origin' added"
}

# Push to remote
Write-Info "Pushing to remote repository..."
Write-Warning "You may be prompted for credentials."
Write-Host ""

git push -u origin $branchName

if ($LASTEXITCODE -eq 0) {
    Write-Host ""
    Write-Success "======================================"
    Write-Success "  SUCCESS! Repository pushed to remote"
    Write-Success "======================================"
    Write-Host ""
    Write-Info "Repository URL: $remoteUrl"
    Write-Info "Branch: $branchName"
    Write-Host ""
    Write-Success "Next steps:"
    Write-Success "1. Verify files on $remoteUrl"
    Write-Success "2. Follow IMPLEMENTATION_GUIDE.md to deploy infrastructure"
    Write-Success "3. Setup Jenkins pipelines for microservices"
} else {
    Write-Host ""
    Write-Error "======================================"
    Write-Error "  FAILED to push to remote repository"
    Write-Error "======================================"
    Write-Host ""
    Write-Warning "Common issues:"
    Write-Warning "1. Authentication failed - Use Personal Access Token (PAT) instead of password"
    Write-Warning "2. Remote repository not empty - Try: git pull origin $branchName --allow-unrelated-histories"
    Write-Warning "3. Network issues - Check your internet connection"
    Write-Host ""
    Write-Info "For detailed troubleshooting, see GIT_SETUP_GUIDE.md"
    exit 1
}
