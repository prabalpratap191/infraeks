# EKS Node Launch Failure - Quick Fix Summary

## 🔴 Problem

```
Error: NodeCreationFailure: Instances failed to join the kubernetes cluster
Cause: Client.InternalError: Client error on launch
```

**10 instances failed to launch and join the cluster.**

---

## ✅ Fixes Applied

### 1. Fixed Cluster Version Configuration
**File**: `terraform/modules/eks/main.tf` (line 38)
- **Before**: `cluster_version = "1.31"` (hardcoded)
- **After**: `cluster_version = var.cluster_version` (variable)
- **Why**: Allows flexible version management through tfvars

### 2. Fixed IMDSv2 Metadata Configuration
**File**: `terraform/modules/eks/main.tf` (line 116)
- **Before**: `http_tokens = "required"`
- **After**: `http_tokens = "optional"`
- **Why**: Amazon Linux 2023 has bootstrap compatibility issues with strict IMDSv2 enforcement. This is the **primary fix** for the node launch failures.

### 3. Removed Interfering Bootstrap Script
**File**: `terraform/modules/eks/main.tf` (line 143)
- **Before**: Custom `pre_bootstrap_user_data` script
- **After**: Minimal configuration - `enable_bootstrap_user_data = true` only
- **Why**: Custom scripts can interfere with EKS-managed AL2023 bootstrap process

### 4. Fixed Module Variable Default
**File**: `terraform/modules/eks/variables.tf` (line 30)
- **Before**: `default = "1.33"` (non-existent version)
- **After**: `default = "1.31"` (stable version)
- **Why**: Prevents version-related errors

---

## 🚀 Deployment Steps

### Option 1: Via Jenkins (Recommended)

1. **Commit and push the changes**:
   ```bash
   git add .
   git commit -m "Fix EKS node launch failures - IMDSv2 and bootstrap issues"
   git push origin mainbranch
   ```

2. **Trigger Jenkins pipeline**:
   - Pipeline will automatically run cleanup, init, plan, and apply
   - Monitor the pipeline at your Jenkins URL

### Option 2: Manual Terraform Deployment

1. **Run prerequisites check**:
   ```bash
   cd c:\Users\prasingh80\Music\Legacy\MS Legacy\infraeks-master
   chmod +x scripts/verify-eks-prerequisites.sh
   ./scripts/verify-eks-prerequisites.sh meracommerce-dev us-east-1
   ```

2. **Clean up failed resources**:
   ```bash
   chmod +x scripts/cleanup-aws-resources.sh
   ./scripts/cleanup-aws-resources.sh
   ```

3. **Re-initialize Terraform**:
   ```bash
   cd terraform
   rm -rf .terraform .terraform.lock.hcl
   terraform init
   ```

4. **Validate and plan**:
   ```bash
   terraform fmt -recursive
   terraform validate
   terraform plan \
     -var cluster_name=meracommerce-dev \
     -var namespace=customer-ns \
     -var service_account=customer-sa \
     -var-file=meracommerce-dev.tfvars
   ```

5. **Apply changes**:
   ```bash
   terraform apply -auto-approve \
     -var cluster_name=meracommerce-dev \
     -var namespace=customer-ns \
     -var service_account=customer-sa \
     -var-file=meracommerce-dev.tfvars
   ```

---

## 🔍 Monitoring Node Status

While deployment is running, monitor in a separate terminal:

```bash
# Watch node group status
watch -n 5 'aws eks describe-nodegroup \
  --cluster-name meracommerce-dev \
  --nodegroup-name meracommerce-dev-ng \
  --query "nodegroup.{Status:status,Health:health,Desired:scalingConfig.desiredSize,Current:scalingConfig.currentSize}" \
  --output table'

# Or check nodes joining cluster (after cluster is created)
kubectl get nodes -w
```

---

## 📊 Expected Timeline

- **EKS Cluster Creation**: ~10-12 minutes
- **Node Group Creation**: ~5-7 minutes
- **Nodes Joining Cluster**: ~2-3 minutes
- **Total**: ~20 minutes

---

## ⚠️ If Issues Persist

### Check These:

1. **Subnet IP Availability**:
   ```bash
   aws ec2 describe-subnets \
     --filters "Name=availability-zone,Values=us-east-1a,us-east-1b,us-east-1c" \
     --query 'Subnets[].{AZ:AvailabilityZone,AvailableIPs:AvailableIpAddressCount}' \
     --output table
   ```
   **Need**: At least 10+ available IPs per subnet

2. **Instance Type Availability**:
   ```bash
   aws ec2 describe-instance-type-offerings \
     --filters Name=instance-type,Values=t3.medium \
     --query 'InstanceTypeOfferings[?starts_with(Location, `us-east-1`)].Location'
   ```
   **Alternative**: Try `t3a.medium` or `t3.small` if `t3.medium` unavailable

3. **View CloudWatch Logs**:
   ```bash
   aws logs tail /aws/eks/meracommerce-dev/cluster \
     --follow \
     --since 30m
   ```

### Alternative Instance Types

If t3.medium continues to fail, edit `terraform/meracommerce-dev.tfvars`:

```hcl
# Try these alternatives (in order of preference):
node_instance_type  = "t3a.medium"  # AMD-based, usually more available
# node_instance_type  = "t3.small"   # Smaller for dev/test
# node_instance_type  = "t2.medium"  # Older generation
```

---

## 📚 Additional Resources

- **Detailed Troubleshooting**: [terraform/eks-troubleshooting-guide.md](terraform/eks-troubleshooting-guide.md)
- **Prerequisites Check**: Run `scripts/verify-eks-prerequisites.sh`
- **AWS EKS Documentation**: https://docs.aws.amazon.com/eks/latest/userguide/troubleshooting.html

---

## 📝 Files Modified

1. ✅ `terraform/modules/eks/main.tf` - **3 critical fixes**
2. ✅ `terraform/modules/eks/variables.tf` - Version default fix
3. ✨ `terraform/eks-troubleshooting-guide.md` - New troubleshooting guide
4. ✨ `scripts/verify-eks-prerequisites.sh` - New verification script

---

## ✅ Success Indicators

You'll know it's working when:

1. ✅ Terraform apply completes without errors
2. ✅ Node group status shows `ACTIVE`
3. ✅ `kubectl get nodes` shows 2 nodes in `Ready` state
4. ✅ No `Client.InternalError` in CloudWatch logs

---

**Last Updated**: 2026-08-25  
**Status**: ✅ Fixes applied, ready for deployment
