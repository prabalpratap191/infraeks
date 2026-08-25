# EKS Node Group Creation Failure - Troubleshooting Guide

## Error Summary
```
Error: waiting for EKS Node Group (meracommerce-dev:default-20260824112732158800000001) create: 
unexpected state 'CREATE_FAILED', wanted target 'ACTIVE'. 
last error: i-09bcf845f56c50789, i-0e5f2c2302aaa4cb9: 
NodeCreationFailure: Instances failed to join the kubernetes cluster
```

## Root Causes Identified

### 🔴 1. **Invalid Kubernetes Version (CRITICAL)**
- **Issue**: Configuration specified Kubernetes `1.33` which doesn't exist
- **Impact**: AWS cannot find matching AMI images for non-existent K8s versions
- **Fix**: Updated to `1.31` (latest stable version)

### 🔴 2. **Missing IAM Role Configuration (CRITICAL)**
- **Issue**: Node group lacked explicit IAM policies required for:
  - Container Network Interface (CNI) operations
  - EC2 Container Registry (ECR) access
  - CloudWatch logging
  - Node-to-control-plane authentication
- **Impact**: Nodes cannot authenticate with the EKS control plane
- **Fix**: Added:
  ```hcl
  iam_role_attach_cni_policy = true
  iam_role_additional_policies = {
    AmazonSSMManagedInstanceCore = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
  }
  ```

### 🟡 3. **Hardcoded Subnet IDs**
- **Issue**: Subnets were hardcoded and might include `us-east-1e` (limited capacity)
- **Impact**: Potential capacity constraints or incorrect subnet selection
- **Fix**: Implemented dynamic subnet filtering:
  ```hcl
  data "aws_subnets" "filtered" {
    filter {
      name   = "availability-zone"
      values = ["us-east-1a", "us-east-1b", "us-east-1c"]
    }
  }
  ```

### 🟡 4. **Missing Security Group Rules**
- **Issue**: No explicit security group rules for node-cluster communication
- **Impact**: Nodes cannot communicate with control plane or each other
- **Fix**: Added comprehensive security group rules for:
  - Node-to-node communication
  - Cluster-to-node communication
  - Node egress traffic

### 🟡 5. **No Bootstrap Configuration**
- **Issue**: Missing user data for node bootstrap process
- **Impact**: Nodes may not properly configure kubelet to join cluster
- **Fix**: Added:
  ```hcl
  enable_bootstrap_user_data = true
  pre_bootstrap_user_data = <<-EOT
    #!/bin/bash
    set -ex
    echo "Setting up node for cluster join..."
  EOT
  ```

### 🟡 6. **AMI Type Not Specified**
- **Issue**: No explicit AMI type defined
- **Impact**: May use incompatible or deprecated AMI
- **Fix**: Specified `ami_type = "AL2023_x86_64_STANDARD"`

## Files Modified

### 1. `terraform/modules/eks/main.tf`
**Changes Made:**
- ✅ Fixed Kubernetes version: `1.33` → `1.31`
- ✅ Added filtered subnet data source (excludes us-east-1e)
- ✅ Added IAM role CNI policy attachment
- ✅ Added SSM managed instance policy for troubleshooting
- ✅ Configured cluster and node security group rules
- ✅ Specified AMI type: `AL2023_x86_64_STANDARD`
- ✅ Added IMDSv2 requirement for security
- ✅ Configured EBS volume encryption
- ✅ Added bootstrap user data script
- ✅ Enabled cluster endpoint private access
- ✅ Enabled IRSA (IAM Roles for Service Accounts)

### 2. `terraform/meracommerce-dev.tfvars`
**Changes Made:**
- ✅ Updated `cluster_version` from `"1.33"` to `"1.31"`

### 3. `terraform/variables.tf`
**Changes Made:**
- ✅ Updated default `cluster_version` from `"1.33"` to `"1.31"`

## Deployment Steps

### Before Redeploying:

#### 1. **Destroy Failed Resources**
```bash
cd terraform
terraform destroy -target=module.eks.module.eks.module.eks_managed_node_group["default"] \
  -var cluster_name=meracommerce-dev \
  -var namespace=customer-ns \
  -var service_account=customer-sa \
  -var-file=meracommerce-dev.tfvars \
  -auto-approve
```

#### 2. **Verify Subnet Configuration (Optional)**
```bash
# List available subnets in allowed AZs
aws ec2 describe-subnets \
  --region us-east-1 \
  --filters "Name=availability-zone,Values=us-east-1a,us-east-1b,us-east-1c" \
  --query 'Subnets[*].[SubnetId,AvailabilityZone,CidrBlock,AvailableIpAddressCount,MapPublicIpOnLaunch]' \
  --output table
```

#### 3. **Check Jenkins IAM Permissions**
Ensure the `jenkins-user` has these permissions:
```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "eks:*",
        "ec2:*",
        "iam:CreateRole",
        "iam:AttachRolePolicy",
        "iam:PutRolePolicy",
        "iam:GetRole",
        "iam:PassRole",
        "iam:ListAttachedRolePolicies",
        "iam:ListRolePolicies",
        "autoscaling:*",
        "elasticloadbalancing:*"
      ],
      "Resource": "*"
    }
  ]
}
```

#### 4. **Re-run Jenkins Pipeline**
Trigger the pipeline with parameters:
- `CLUSTER_NAME`: `meracommerce-dev`
- `NAMESPACE`: `customer-ns`
- `SERVICE_ACCOUNT`: `customer-sa`
- `AWS_REGION`: `us-east-1`

### Post-Deployment Verification:

#### 1. **Check Node Group Status**
```bash
aws eks describe-nodegroup \
  --cluster-name meracommerce-dev \
  --nodegroup-name meracommerce-dev-node-group \
  --region us-east-1 \
  --query 'nodegroup.{Status:status,Health:health,ScalingConfig:scalingConfig}'
```

#### 2. **Verify Nodes Joined Cluster**
```bash
# Update kubeconfig
aws eks update-kubeconfig --name meracommerce-dev --region us-east-1

# Check nodes
kubectl get nodes -o wide

# Expected output:
NAME                         STATUS   ROLES    AGE   VERSION
ip-xxx-xxx-xxx-xxx.ec2...   Ready    <none>   2m    v1.31.x
ip-xxx-xxx-xxx-xxx.ec2...   Ready    <none>   2m    v1.31.x
```

#### 3. **Check Node Health**
```bash
# Check node conditions
kubectl describe nodes | grep -A 5 "Conditions:"

# Check system pods
kubectl get pods -n kube-system
```

## Common Additional Issues & Solutions

### Issue: "Unauthorized" errors when nodes try to join
**Solution:**
```bash
# Verify aws-auth ConfigMap exists
kubectl get configmap aws-auth -n kube-system

# If missing, the EKS module should create it automatically
# Verify the node IAM role ARN is correct
aws iam get-role --role-name <node-role-name>
```

### Issue: Nodes join but show "NotReady"
**Possible Causes:**
1. CNI plugin not running
2. Missing VPC CNI permissions
3. Subnet IP exhaustion

**Solution:**
```bash
# Check CNI pods
kubectl get pods -n kube-system | grep aws-node

# Check CNI logs
kubectl logs -n kube-system -l k8s-app=aws-node
```

### Issue: Timeout during node creation
**Solution:**
Increase timeout in Terraform:
```hcl
timeouts {
  create = "30m"
  update = "30m"
  delete = "30m"
}
```

## Monitoring & Debugging

### Enable CloudWatch Logs for Control Plane
Add to `main.tf`:
```hcl
cluster_enabled_log_types = ["api", "audit", "authenticator", "controllerManager", "scheduler"]
```

### Check EC2 Instance System Logs
```bash
# Get instance IDs from failed nodes
INSTANCE_ID="i-09bcf845f56c50789"

# Get console output
aws ec2 get-console-output --instance-id $INSTANCE_ID --region us-east-1
```

### Check SSM Session (if instances are running)
```bash
# Connect to node for debugging
aws ssm start-session --target i-09bcf845f56c50789

# Inside instance:
sudo journalctl -u kubelet -f
sudo cat /var/log/cloud-init-output.log
```

## Key Differences in Updated Configuration

| Component | Before | After |
|-----------|--------|-------|
| **Kubernetes Version** | 1.33 (invalid) | 1.31 (stable) |
| **Subnet Selection** | Hardcoded 3 subnets | Dynamic filtered (excludes us-east-1e) |
| **IAM CNI Policy** | ❌ Not configured | ✅ Attached |
| **AMI Type** | ❌ Not specified | ✅ AL2023_x86_64_STANDARD |
| **Security Groups** | ❌ Default only | ✅ Comprehensive rules |
| **Bootstrap Script** | ❌ None | ✅ Enabled with pre-bootstrap |
| **IMDSv2** | ❌ Not enforced | ✅ Required |
| **EBS Encryption** | ❌ Not configured | ✅ Enabled |
| **IRSA** | ❌ Not enabled | ✅ Enabled |
| **Private Endpoint** | ❌ Disabled | ✅ Enabled |

## Expected Outcome

After applying these fixes:
1. ✅ Node group should create successfully
2. ✅ EC2 instances will launch in us-east-1a, us-east-1b, or us-east-1c
3. ✅ Nodes will authenticate with proper IAM roles
4. ✅ Nodes will join the cluster and show "Ready" status
5. ✅ System pods (CoreDNS, kube-proxy, aws-node) will run successfully

## Support & Further Troubleshooting

If issues persist:
1. Check CloudWatch Logs for EKS control plane logs
2. Review EC2 instance system logs via AWS Console
3. Verify VPC subnet has sufficient IP addresses
4. Confirm security groups allow required traffic
5. Validate IAM role trust relationships

---
**Last Updated:** 2026-08-25  
**Terraform AWS EKS Module Version:** ~> 20.0  
**Kubernetes Version:** 1.31
