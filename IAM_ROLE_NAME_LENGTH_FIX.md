# IAM Role Name Length Issue - Fix Guide

## Problem Description

### Error Message
```
Error: expected length of name_prefix to be in the range (1 - 38), got meracommerce-dev-node-group-eks-node-group-

with module.eks.module.eks.module.eks_managed_node_group["default"].aws_iam_role.this[0],
on .terraform/modules/eks.eks/modules/eks-managed-node-group/main.tf line 525, in resource "aws_iam_role" "this":
525:   name_prefix = var.iam_role_use_name_prefix ? "${local.iam_role_name}-" : null
```

### Root Cause

AWS IAM role names have specific length constraints:
- **Maximum total length**: 64 characters
- **When using `name_prefix`**: Maximum 38 characters (to leave room for random suffix)

The issue occurs when:
1. Cluster name is long (e.g., `meracommerce-dev`)
2. EKS module adds suffixes (e.g., `-node-group-eks-node-group-`)
3. Combined length exceeds 38 characters

**Calculation:**
```
meracommerce-dev-node-group-eks-node-group- = 45 characters
```
This exceeds the 38-character limit! ❌

---

## Solution

### Fix Applied

In `terraform/modules/eks/main.tf`, we made the following changes:

#### Before (Problematic):
```hcl
eks_managed_node_groups = {
  default = {
    name            = "${var.cluster_name}-node-group"
    use_name_prefix = false
    # ... other config
  }
}
```

#### After (Fixed):
```hcl
eks_managed_node_groups = {
  default = {
    name            = "${var.cluster_name}-ng"  # Shortened from -node-group to -ng
    use_name_prefix = false
    
    # Explicitly control IAM role naming
    iam_role_name          = "${var.cluster_name}-node-role"
    iam_role_use_name_prefix = false
    # ... other config
  }
}
```

### Why This Works

1. **Shorter node group name**: `meracommerce-dev-ng` (18 chars) instead of `meracommerce-dev-node-group` (28 chars)
2. **Explicit IAM role name**: `meracommerce-dev-node-role` (26 chars)
3. **Disabled name_prefix**: Set `iam_role_use_name_prefix = false` to use exact name

**New IAM role name:**
```
meracommerce-dev-node-role = 26 characters ✅
```
This is well within the 64-character limit!

---

## Deployment Steps

### 1. Clean Previous State (if needed)

```bash
cd terraform

# If you have a partially created infrastructure, destroy it
terraform destroy -var-file=meracommerce-dev.tfvars -auto-approve

# Clean Terraform state and cache
rm -rf .terraform .terraform.lock.hcl
```

### 2. Re-initialize Terraform

```bash
terraform init
```

### 3. Validate Configuration

```bash
terraform validate

# Expected output:
Success! The configuration is valid.
```

### 4. Plan Deployment

```bash
terraform plan \
  -var cluster_name=meracommerce-dev \
  -var namespace=customer-ns \
  -var service_account=customer-sa \
  -var-file=meracommerce-dev.tfvars
```

### 5. Apply Configuration

```bash
terraform apply \
  -var cluster_name=meracommerce-dev \
  -var namespace=customer-ns \
  -var service_account=customer-sa \
  -var-file=meracommerce-dev.tfvars \
  -auto-approve
```

---

## Verification

### Check IAM Role Creation

```bash
# List IAM roles with the cluster name
aws iam list-roles --query 'Roles[?contains(RoleName, `meracommerce-dev`)].RoleName' --output table

# Expected output:
+-----------------------------------+
|           ListRoles               |
+-----------------------------------+
|  meracommerce-dev-node-role      |
|  meracommerce-dev-cluster-role   |
+-----------------------------------+
```

### Check EKS Node Group

```bash
aws eks describe-nodegroup \
  --cluster-name meracommerce-dev \
  --nodegroup-name meracommerce-dev-ng \
  --region us-east-1
```

### Verify from Kubernetes

```bash
# Update kubeconfig
aws eks update-kubeconfig --name meracommerce-dev --region us-east-1

# Check nodes
kubectl get nodes

# Expected output:
NAME                         STATUS   ROLES    AGE   VERSION
ip-xxx-xxx-xxx-xxx.ec2...    Ready    <none>   5m    v1.31.x
ip-xxx-xxx-xxx-xxx.ec2...    Ready    <none>   5m    v1.31.x
```

---

## Alternative Solutions

### Option 1: Use Shorter Cluster Name

If you're starting fresh, consider a shorter cluster name:

```hcl
# Instead of:
cluster_name = "meracommerce-dev"

# Use:
cluster_name = "mera-dev"  # 8 characters
# or
cluster_name = "mc-dev"    # 6 characters
```

### Option 2: Use Name Prefix with Shorter Base

If you want to use name prefixes for uniqueness:

```hcl
eks_managed_node_groups = {
  default = {
    name            = "mc-dev-ng"
    use_name_prefix = true  # This will add random suffix
    
    iam_role_name          = "mc-dev-node"
    iam_role_use_name_prefix = true
    # ... other config
  }
}
```

### Option 3: Use Tags Instead of Long Names

Leverage AWS tags for identification instead of long names:

```hcl
eks_managed_node_groups = {
  default = {
    name            = "mc-dev-ng"
    use_name_prefix = false
    
    iam_role_name          = "mc-dev-node"
    iam_role_use_name_prefix = false
    
    tags = {
      FullName    = "meracommerce-dev-node-group"
      Environment = "dev"
      Project     = "meracommerce"
      ManagedBy   = "Terraform"
    }
  }
}
```

---

## Jenkins Pipeline Update

No changes needed to the Jenkinsfile! The pipeline will work with the updated Terraform configuration.

However, if you want to verify the changes before running the full pipeline:

```bash
# SSH into Jenkins server or use Jenkins console
# Navigate to workspace
cd /var/lib/jenkins/workspace/infraeks-deployment

# Pull latest changes
git pull origin master

# Test locally
cd terraform
terraform init
terraform plan -var-file=meracommerce-dev.tfvars
```

---

## AWS Naming Constraints Reference

### IAM Role Names

| Constraint | Value |
|------------|-------|
| **Minimum length** | 1 character |
| **Maximum length** | 64 characters |
| **With name_prefix** | 38 characters (max prefix) |
| **Allowed characters** | a-z, A-Z, 0-9, =,.@-_ |
| **Pattern** | `[\w+=,.@-]+` |

### EKS Resource Names

| Resource | Max Length |
|----------|------------|
| **Cluster name** | 100 characters |
| **Node group name** | 63 characters |
| **Namespace** | 63 characters |
| **Service account** | 253 characters |

---

## Troubleshooting

### Issue: State Lock Error

```bash
# If you get a state lock error, force unlock
terraform force-unlock <LOCK_ID>
```

### Issue: Node Group Already Exists

```bash
# Delete existing node group
aws eks delete-nodegroup \
  --cluster-name meracommerce-dev \
  --nodegroup-name meracommerce-dev-node-group \
  --region us-east-1

# Wait for deletion (takes 3-5 minutes)
aws eks describe-nodegroup \
  --cluster-name meracommerce-dev \
  --nodegroup-name meracommerce-dev-node-group \
  --region us-east-1

# Then re-run terraform apply
```

### Issue: IAM Role Already Exists

```bash
# List attached policies
aws iam list-attached-role-policies \
  --role-name meracommerce-dev-node-group-eks-node-group-XXXXX

# Detach all policies
aws iam detach-role-policy \
  --role-name <role-name> \
  --policy-arn <policy-arn>

# Delete the role
aws iam delete-role --role-name <role-name>

# Then re-run terraform apply
```

---

## Best Practices

### 1. Keep Names Short and Meaningful

✅ **Good:**
```
mc-dev-ng          (9 chars)
mc-dev-node-role   (16 chars)
```

❌ **Bad:**
```
meracommerce-development-environment-node-group  (48 chars)
```

### 2. Use Tags for Detailed Information

```hcl
tags = {
  Name        = "mc-dev-ng"
  FullName    = "MeraCommerce Development Node Group"
  Environment = "development"
  Project     = "meracommerce"
  CostCenter  = "engineering"
  ManagedBy   = "Terraform"
}
```

### 3. Document Naming Conventions

Create a `NAMING_CONVENTIONS.md` file:

```markdown
# Naming Conventions

## Cluster Names
- Pattern: `{project}-{env}`
- Example: `mc-dev`, `mc-prod`
- Max: 15 characters

## Node Groups
- Pattern: `{cluster-name}-ng`
- Example: `mc-dev-ng`

## IAM Roles
- Pattern: `{cluster-name}-{resource}-role`
- Example: `mc-dev-node-role`
- Max: 30 characters
```

### 4. Validate Before Applying

```bash
# Always run validate before apply
terraform validate

# Use plan to preview changes
terraform plan -var-file=meracommerce-dev.tfvars | grep -E "(create|destroy|update)"

# Check resource names in plan output
terraform plan -var-file=meracommerce-dev.tfvars | grep -i "name"
```

---

## Summary

✅ **Problem**: IAM role name_prefix exceeded 38 characters
✅ **Root Cause**: Long cluster name + module suffixes
✅ **Solution**: Shortened node group name and explicitly set IAM role name
✅ **Result**: IAM role name is now 26 characters (well within limit)

### Changes Made

1. Node group name: `meracommerce-dev-node-group` → `meracommerce-dev-ng`
2. Added explicit IAM role name: `meracommerce-dev-node-role`
3. Disabled name_prefix for IAM role: `iam_role_use_name_prefix = false`

### Next Steps

1. ✅ Clean previous Terraform state
2. ✅ Re-initialize Terraform
3. ✅ Apply updated configuration
4. ✅ Verify node group and IAM roles
5. ✅ Deploy microservices

---

**Last Updated**: 2026-08-25  
**Author**: DevOps Team  
**Status**: Resolved ✅
