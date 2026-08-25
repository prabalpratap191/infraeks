# EKS Deployment Pre-Flight Checklist

## ✅ Before Running Terraform Apply

### 1. Configuration Validation
- [ ] Kubernetes version is set to `1.31` (not 1.33)
- [ ] Subnets are in allowed AZs: `us-east-1a`, `us-east-1b`, `us-east-1c`
- [ ] IAM policies for nodes include CNI and SSM permissions
- [ ] Security group rules configured for node-cluster communication
- [ ] AMI type specified: `AL2023_x86_64_STANDARD`

### 2. AWS Prerequisites
- [ ] AWS credentials configured in Jenkins (credential ID: `jenkins-user`)
- [ ] Jenkins user has required IAM permissions:
  - `eks:*`
  - `ec2:*`
  - `iam:CreateRole`, `iam:AttachRolePolicy`, `iam:PassRole`
  - `autoscaling:*`
- [ ] VPC has sufficient IP addresses in selected subnets
- [ ] Default VPC exists in `us-east-1`

### 3. Terraform State
- [ ] Backend configured properly
- [ ] Previous failed resources destroyed:
  ```bash
  terraform destroy -target=module.eks.module.eks.module.eks_managed_node_group["default"]
  ```
- [ ] Terraform workspace cleaned:
  ```bash
  cd terraform
  rm -rf .terraform .terraform.lock.hcl
  terraform init
  ```

## 🚀 Deployment Steps

### Step 1: Clean Previous State
```bash
cd terraform
rm -rf .terraform .terraform.lock.hcl
```

### Step 2: Initialize Terraform
```bash
terraform init
```

### Step 3: Validate Configuration
```bash
terraform validate
terraform fmt -recursive
```

### Step 4: Plan Deployment
```bash
terraform plan \
  -var cluster_name=meracommerce-dev \
  -var namespace=customer-ns \
  -var service_account=customer-sa \
  -var-file=meracommerce-dev.tfvars
```

### Step 5: Apply Configuration
```bash
terraform apply \
  -var cluster_name=meracommerce-dev \
  -var namespace=customer-ns \
  -var service_account=customer-sa \
  -var-file=meracommerce-dev.tfvars \
  -auto-approve
```

## 🔍 Post-Deployment Verification

### 1. Check Node Group Status
```bash
aws eks describe-nodegroup \
  --cluster-name meracommerce-dev \
  --nodegroup-name meracommerce-dev-node-group \
  --region us-east-1
```

**Expected Status:** `ACTIVE`

### 2. Update kubeconfig
```bash
aws eks update-kubeconfig --name meracommerce-dev --region us-east-1
```

### 3. Verify Nodes
```bash
kubectl get nodes -o wide
```

**Expected Output:**
```
NAME                         STATUS   ROLES    AGE   VERSION
ip-xxx-xxx-xxx-xxx.ec2...   Ready    <none>   2m    v1.31.x
ip-xxx-xxx-xxx-xxx.ec2...   Ready    <none>   2m    v1.31.x
```

### 4. Check System Pods
```bash
kubectl get pods -n kube-system
```

**Expected Pods (all Running):**
- `aws-node-*` (VPC CNI)
- `coredns-*`
- `kube-proxy-*`

### 5. Verify Node Health
```bash
kubectl describe nodes | grep -A 5 "Conditions:"
```

**Expected Conditions:**
- `Ready: True`
- `MemoryPressure: False`
- `DiskPressure: False`

## 🚨 Troubleshooting Quick Reference

### If Nodes Fail to Join:
1. Check node IAM role permissions
2. Verify security group rules
3. Check VPC CNI pod logs: `kubectl logs -n kube-system -l k8s-app=aws-node`
4. Review EC2 instance console output

### If Node Status is "NotReady":
1. Check kubelet logs: `journalctl -u kubelet`
2. Verify CNI plugin running
3. Check for IP address exhaustion

### If Terraform Apply Hangs:
1. Check CloudWatch logs for control plane
2. Verify subnet capacity
3. Increase timeout in node group configuration

## 📊 Key Metrics to Monitor

- **Node Group Status**: Should be `ACTIVE` within 10-15 minutes
- **Instance Count**: Should match `desired_size` (2)
- **Node Status**: All nodes should be `Ready` within 5 minutes
- **Pod Count**: System pods should be running across all nodes

## 🔧 Emergency Rollback

If deployment fails:

```bash
# Destroy node group only
terraform destroy -target=module.eks.module.eks.module.eks_managed_node_group["default"] \
  -var cluster_name=meracommerce-dev \
  -var namespace=customer-ns \
  -var service_account=customer-sa \
  -var-file=meracommerce-dev.tfvars \
  -auto-approve

# Or destroy entire cluster
terraform destroy \
  -var cluster_name=meracommerce-dev \
  -var namespace=customer-ns \
  -var service_account=customer-sa \
  -var-file=meracommerce-dev.tfvars \
  -auto-approve
```

## 📝 Jenkins Pipeline Parameters

Ensure these are set correctly:
- **CLUSTER_NAME**: `meracommerce-dev`
- **NAMESPACE**: `customer-ns`
- **SERVICE_ACCOUNT**: `customer-sa`
- **AWS_REGION**: `us-east-1`

---
**Ready to Deploy?** Review all checkboxes above before proceeding!
