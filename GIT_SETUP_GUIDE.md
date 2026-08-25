# Git Setup and Push Guide

## Scenario
You have:
- ✅ A **new local folder** with all the infrastructure code
- ✅ An **existing empty Git repository** (already created on GitHub/GitLab/Bitbucket)
- ❓ Need to initialize Git and push all changes

---

## Step-by-Step Instructions

### Step 1: Verify Your Current Location

```bash
# Make sure you're in the project root directory
pwd
# Output should be: c:\Users\prasingh80\Music\Legacy\MS Legacy\infraeks-master

cd "c:\Users\prasingh80\Music\Legacy\MS Legacy\infraeks-master"
```

### Step 2: Initialize Git Repository

```bash
# Initialize Git in this folder
git init

# Output:
# Initialized empty Git repository in c:/Users/prasingh80/Music/Legacy/MS Legacy/infraeks-master/.git/
```

### Step 3: Configure Git User (if not already configured)

```bash
# Set your name and email (replace with your details)
git config user.name "Your Name"
git config user.email "your.email@example.com"

# Optional: Set these globally for all repos
git config --global user.name "Your Name"
git config --global user.email "your.email@example.com"

# Verify configuration
git config --list
```

### Step 4: Create .gitignore File

```bash
# Create .gitignore to exclude unnecessary files
cat > .gitignore << 'EOF'
# Terraform
.terraform/
.terraform.lock.hcl
*.tfstate
*.tfstate.*
*.tfvars.backup
terraform.tfstate.d/
crash.log
crash.*.log
*.tfplan

# IDE
.idea/
.vscode/
*.swp
*.swo
*~

# OS
.DS_Store
Thumbs.db

# Logs
*.log

# Environment
.env
.env.local

# Build artifacts
target/
build/
dist/
*.jar
*.war

# Jenkins
.jenkins/

# Secrets (IMPORTANT - never commit secrets!)
*secret*
*password*
*credentials*
*.pem
*.key
EOF

echo ".gitignore created successfully"
```

### Step 5: Check Repository Status

```bash
# See all untracked files
git status

# Output will show:
# On branch main (or master)
# No commits yet
#
# Untracked files:
#   CHANGES_SUMMARY.md
#   DEPLOYMENT_CHECKLIST.md
#   EKS_NODE_GROUP_TROUBLESHOOTING.md
#   IMPLEMENTATION_GUIDE.md
#   ... (many more files)
```

### Step 6: Stage All Files

```bash
# Add all files to staging area
git add .

# Verify what's staged
git status

# Output should show files in green (staged for commit)
```

### Step 7: Create First Commit

```bash
# Commit with a descriptive message
git commit -m "Initial commit: Multi-microservices EKS infrastructure

- Added Terraform modules for microservices (order, catalog, customer)
- Added AWS Load Balancer Controller module
- Created Kubernetes manifests for all services
- Added Jenkins CI/CD pipeline templates
- Implemented IRSA, RBAC, and Network Policies
- Added comprehensive documentation
"

# Output:
# [main (root-commit) abc1234] Initial commit: Multi-microservices EKS infrastructure
#  XX files changed, XXXX insertions(+)
```

### Step 8: Set Default Branch Name (Optional)

```bash
# If your repo uses 'main' instead of 'master'
git branch -M main

# Or keep 'master' if that's what your remote repo uses
# git branch -M master
```

### Step 9: Add Remote Repository

**Choose your Git hosting platform:**

#### Option A: GitHub

```bash
# Replace with your actual repository URL
git remote add origin https://github.com/your-username/infraeks.git

# Or using SSH (if you have SSH key configured)
git remote add origin git@github.com:your-username/infraeks.git
```

#### Option B: GitLab

```bash
git remote add origin https://gitlab.com/your-username/infraeks.git

# Or SSH
git remote add origin git@gitlab.com:your-username/infraeks.git
```

#### Option C: Bitbucket

```bash
git remote add origin https://bitbucket.org/your-username/infraeks.git

# Or SSH
git remote add origin git@bitbucket.org:your-username/infraeks.git
```

#### Option D: Azure DevOps

```bash
git remote add origin https://dev.azure.com/your-org/your-project/_git/infraeks
```

### Step 10: Verify Remote Configuration

```bash
# Check if remote is added correctly
git remote -v

# Output:
# origin  https://github.com/your-username/infraeks.git (fetch)
# origin  https://github.com/your-username/infraeks.git (push)
```

### Step 11: Push to Remote Repository

```bash
# Push to remote repository (first time)
git push -u origin main

# Or if using 'master' branch:
# git push -u origin master

# You may be prompted for credentials
# Enter your username and password/token
```

**If using HTTPS and prompted for password:**
- For **GitHub**: Use Personal Access Token (PAT), NOT your password
- For **GitLab**: Use Personal Access Token or password
- For **Bitbucket**: Use App Password

### Step 12: Verify Push Success

```bash
# Check remote branches
git branch -a

# Output:
# * main
#   remotes/origin/main

# Check last commit
git log --oneline -1
```

---

## Alternative: If Remote Repository Already Has Content

### Scenario: Remote repo has README.md or initial commit

```bash
# Step 1: Add remote (same as Step 9)
git remote add origin https://github.com/your-username/infraeks.git

# Step 2: Fetch remote content
git fetch origin

# Step 3: Merge remote with local (allow unrelated histories)
git merge origin/main --allow-unrelated-histories

# Or for 'master' branch:
# git merge origin/master --allow-unrelated-histories

# Step 4: Resolve any conflicts if they exist
# Edit conflicting files, then:
git add .
git commit -m "Merge remote repository with local changes"

# Step 5: Push
git push -u origin main
```

---

## Complete Command Sequence (Quick Reference)

### For Fresh Remote Repository:

```bash
# Navigate to project folder
cd "c:\Users\prasingh80\Music\Legacy\MS Legacy\infraeks-master"

# Initialize Git
git init

# Configure user (if needed)
git config user.name "Your Name"
git config user.email "your.email@example.com"

# Create .gitignore
cat > .gitignore << 'EOF'
.terraform/
*.tfstate
*.tfstate.*
.env
EOF

# Stage all files
git add .

# Commit
git commit -m "Initial commit: Multi-microservices EKS infrastructure"

# Set branch name
git branch -M main

# Add remote (REPLACE WITH YOUR REPO URL)
git remote add origin https://github.com/your-username/infraeks.git

# Push
git push -u origin main
```

---

## Troubleshooting

### Issue 1: Authentication Failed

**Problem:**
```
remote: Support for password authentication was removed.
fatal: Authentication failed
```

**Solution for GitHub:**
```bash
# Generate Personal Access Token (PAT)
# 1. Go to GitHub → Settings → Developer settings → Personal access tokens
# 2. Generate new token (classic)
# 3. Select scopes: repo (full control)
# 4. Copy the token

# Use token as password when prompted
# Username: your-github-username
# Password: ghp_xxxxxxxxxxxxxxxxxxxx (your PAT)
```

**Or configure Git to use SSH:**
```bash
# Generate SSH key (if not exists)
ssh-keygen -t ed25519 -C "your.email@example.com"

# Add SSH key to ssh-agent
eval "$(ssh-agent -s)"
ssh-add ~/.ssh/id_ed25519

# Copy public key
cat ~/.ssh/id_ed25519.pub

# Add to GitHub → Settings → SSH and GPG keys → New SSH key

# Change remote URL to SSH
git remote set-url origin git@github.com:your-username/infraeks.git

# Push again
git push -u origin main
```

### Issue 2: Remote Repository Not Empty

**Problem:**
```
! [rejected]        main -> main (fetch first)
error: failed to push some refs to 'https://github.com/...'
```

**Solution:**
```bash
# Option 1: Pull first, then push
git pull origin main --allow-unrelated-histories
git push -u origin main

# Option 2: Force push (USE WITH CAUTION - overwrites remote)
git push -u origin main --force
```

### Issue 3: Wrong Branch Name

**Problem:**
You created 'main' but remote expects 'master' (or vice versa)

**Solution:**
```bash
# Check current branch
git branch

# Rename branch
git branch -M master  # or 'main'

# Push with correct branch name
git push -u origin master
```

### Issue 4: Large Files Error

**Problem:**
```
remote: error: File terraform/some-large-file.zip is 123 MB; exceeds GitHub's file size limit of 100 MB
```

**Solution:**
```bash
# Remove large file from staging
git rm --cached terraform/some-large-file.zip

# Add to .gitignore
echo "terraform/some-large-file.zip" >> .gitignore

# Commit and push
git add .gitignore
git commit -m "Remove large file and update .gitignore"
git push -u origin main
```

---

## Post-Push Verification

### Step 1: Verify on Git Platform

1. Open your browser
2. Go to your repository URL:
   - GitHub: `https://github.com/your-username/infraeks`
   - GitLab: `https://gitlab.com/your-username/infraeks`
   - Bitbucket: `https://bitbucket.org/your-username/infraeks`
3. Verify all files are present

### Step 2: Clone in Another Directory (Test)

```bash
# Navigate to a different location
cd /tmp  # or any test directory

# Clone your repository
git clone https://github.com/your-username/infraeks.git test-clone

# Verify files
cd test-clone
ls -la

# Check terraform files
ls terraform/
ls k8s-manifests/

# Cleanup test clone
cd ..
rm -rf test-clone
```

---

## Setting Up Git Credentials Helper (Optional)

### For Windows:

```bash
# Use Git Credential Manager
git config --global credential.helper manager

# Or use Windows Credential Manager
git config --global credential.helper wincred
```

### For Linux/Mac:

```bash
# Cache credentials for 1 hour
git config --global credential.helper 'cache --timeout=3600'

# Or use macOS Keychain
git config --global credential.helper osxkeychain
```

---

## Future Git Workflow

### Making Changes and Pushing:

```bash
# 1. Check current status
git status

# 2. Stage specific files
git add terraform/main.tf
git add k8s-manifests/order-service/deployment.yaml

# Or stage all changes
git add .

# 3. Commit with descriptive message
git commit -m "feat: Add support for payment service

- Added payment-service module
- Updated ingress with /api/payments route
- Added Jenkins pipeline for payment service"

# 4. Push to remote
git push

# Or push to specific branch
git push origin main
```

### Branching Strategy:

```bash
# Create feature branch
git checkout -b feature/add-payment-service

# Make changes, commit
git add .
git commit -m "Add payment service"

# Push feature branch
git push -u origin feature/add-payment-service

# Create Pull Request on GitHub/GitLab
# After merge, switch back to main
git checkout main
git pull origin main
```

---

## Git Best Practices

### ✅ DO:
- ✅ Write clear, descriptive commit messages
- ✅ Commit frequently with small, logical changes
- ✅ Use `.gitignore` to exclude sensitive files
- ✅ Review changes before committing (`git diff`)
- ✅ Pull before pushing to avoid conflicts
- ✅ Use branches for new features

### ❌ DON'T:
- ❌ Commit secrets, passwords, API keys
- ❌ Commit large binary files
- ❌ Force push to shared branches
- ❌ Commit directly to `main`/`master` (use PRs)
- ❌ Commit `.terraform/` or `.tfstate` files
- ❌ Use vague commit messages like "fix" or "update"

---

## Summary

**Quick Steps:**

```bash
# 1. Initialize
git init

# 2. Add files
git add .

# 3. Commit
git commit -m "Initial commit: Multi-microservices EKS infrastructure"

# 4. Set branch
git branch -M main

# 5. Add remote (REPLACE URL)
git remote add origin https://github.com/your-username/infraeks.git

# 6. Push
git push -u origin main
```

**You're all set!** 🎉

Your infrastructure code is now safely stored in your Git repository and ready for collaboration.
