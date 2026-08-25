# EKS Node Group Launch Failure - Troubleshooting Guide

## Issue Summary

**Error**: `NodeCreationFailure: Instances failed to join the kubernetes cluster`  
**Root Cause**: `Client.InternalError: Client error on launch`

## Implemented Fixes

### 1. ✅ Fixed Cluster Version Configuration
- **Issue**: Cluster version was hardcoded to "1.31" instead of using the `var.cluster_version` variable
- **Fix**: Updated `terraform/modules/eks/main.tf` line 26 to use `var.cluster_version`
- **Impact**: Allows flexible version management through tfvars files

### 2. ✅ Fixed IMDSv2 Configuration
- **Issue**: `http_tokens = "required"` causes bootstrap failures with Amazon Linux 2023
- **Fix**: Changed to `http_tokens = "optional"` in metadata_options
- **Location**: `terraform/modules/eks/main.tf` around line 116
- **Why**: AL2023 node bootstrap process has compatibility issues with strict IMDSv2 enforcement

### 3. ✅ Removed Custom Pre-Bootstrap User Data
- **Issue**: Custom `pre_bootstrap_user_data` can interfere with default AL2023 bootstrap
- **Fix**: Removed the custom script, keeping only `enable_bootstrap_user_data = true`
- **Impact**: Allows EKS-managed bootstrap process to run without interference

### 4. ✅ Fixed Module Variables Default
- **Issue**: Default cluster version was set to non-existent "1.33"
- **Fix**: Updated to stable version "1.31" in `terraform/modules/eks/variables.tf`

## Additional Troubleshooting Steps

If the issue persists after applying these fixes, check the following:

### A. Verify Subnet Capacity

```bash
# Check available IP addresses in subnets
aws ec2 describe-subnets \
  --filters "Name=vpc-id,Values=<vpc-id>" \
  --query 'Subnets[?AvailabilityZone==`us-east-1a` || AvailabilityZone==`us-east-1b` || AvailabilityZone==`us-east-1c`].{AZ:AvailabilityZone,SubnetId:SubnetId,AvailableIPs:AvailableIpAddressCount}' \
  --output table
```

**Action**: Ensure each subnet has at least 10+ available IP addresses

### B. Check Security Group Rules

```bash
# Verify cluster security group allows node communication
aws eks describe-cluster \
  --name meracommerce-dev \
  --query 'cluster.resourcesVpcConfig.{ClusterSecurityGroup:clusterSecurityGroupId,SecurityGroups:securityGroupIds}'
```

**Action**: Ensure security groups allow:
- Nodes → Control Plane: Port 443 (HTTPS)
- Control Plane → Nodes: Ports 1025-65535
- Nodes → Nodes: All traffic

### C. Verify IAM Roles and Policies

```bash
# Check if node IAM role has required policies
aws iam list-attached-role-policies \
  --role-name meracommerce-dev-node-role
```

**Required Policies**:
- `AmazonEKSWorkerNodePolicy`
- `AmazonEKS_CNI_Policy`
- `AmazonEC2ContainerRegistryReadOnly`
- `AmazonSSMManagedInstanceCore`

### D. Check Instance Type Availability

```bash
# Verify t3.medium is available in all target AZs
aws ec2 describe-instance-type-offerings \
  --location-type availability-zone \
  --filters Name=instance-type,Values=t3.medium \
  --region us-east-1 \
  --query 'InstanceTypeOfferings[?Location==`us-east-1a` || Location==`us-east-1b` || Location==`us-east-1c`]'
```

**Action**: If t3.medium is not available, consider:
- `t3a.medium` (AMD-based, usually cheaper)
- `t3.small` (for development)
- `t2.medium` (older generation)

### E. Review CloudWatch Logs

```bash
# Get node bootstrap logs
aws logs tail /aws/eks/meracommerce-dev/cluster \
  --follow \
  --format short \
  --since 30m
```

## Deployment Instructions

### Step 1: Clean Up Failed Resources

```bash
# Run the cleanup script
cd scripts
chmod +x cleanup-aws-resources.sh
./cleanup-aws-resources.sh
```

### Step 2: Re-initialize Terraform

```bash
cd terraform
rm -rf .terraform .terraform.lock.hcl terraform.tfstate.backup
terraform init
```

### Step 3: Validate Configuration

```bash
terraform fmt -recursive
terraform validate
```

### Step 4: Plan with New Configuration

```bash
terraform plan \
  -var cluster_name=meracommerce-dev \
  -var namespace=customer-ns \
  -var service_account=customer-sa \
  -var-file=meracommerce-dev.tfvars
```

### Step 5: Apply Changes

```bash
terraform apply -auto-approve \
  -var cluster_name=meracommerce-dev \
  -var namespace=customer-ns \
  -var service_account=customer-sa \
  -var-file=meracommerce-dev.tfvars
```

## Alternative: Switch to Launch Templates (Advanced)

If issues persist, consider using a custom launch template with more control:

```hcl
# Add to eks_managed_node_groups.default in main.tf
use_custom_launch_template = false  # Keep using EKS-managed

# OR for full control:
launch_template_name = "${var.cluster_name}-node-template"
create_launch_template = true
launch_template_use_name_prefix = true
```

## Monitoring Node Join Process

```bash
# Watch nodes joining the cluster
kubectl get nodes -w

# Check node group status
aws eks describe-nodegroup \
  --cluster-name meracommerce-dev \
  --nodegroup-name meracommerce-dev-ng \
  --query 'nodegroup.{Status:status,Health:health}'

# View Auto Scaling Group events
aws autoscaling describe-scaling-activities \
  --auto-scaling-group-name <asg-name> \
  --max-records 10
```

## Prevention Best Practices

1. **Always use variables** for version configuration instead of hardcoding
2. **Test IMDSv2 compatibility** with your AMI before enforcing "required"
3. **Keep bootstrap scripts minimal** - let EKS handle the standard bootstrap
4. **Monitor subnet capacity** - ensure at least 20% free IPs
5. **Use VPC with sufficient CIDR** - /16 recommended for production
6. **Enable CloudWatch Container Insights** for better observability
7. **Set up alerts** for node group health issues

## Quick Reference: Key Files Modified

- ✅ `terraform/modules/eks/main.tf` - Fixed cluster version, IMDSv2, and bootstrap
- ✅ `terraform/modules/eks/variables.tf` - Corrected default cluster version

## Support Resources

- [EKS Best Practices Guide](https://aws.github.io/aws-eks-best-practices/)
- [AL2023 EKS Optimization](https://docs.aws.amazon.com/eks/latest/userguide/eks-optimized-ami.html)
- [Troubleshooting Node Join Issues](https://docs.aws.amazon.com/eks/latest/userguide/troubleshooting.html)

---

**Last Updated**: 2026-08-25  
**Status**: Ready for deployment with fixes applied
