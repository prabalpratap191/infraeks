# Terraform EKS Connectivity Fix Guide

## Problem Summary

You're encountering timeout errors when Terraform tries to create Kubernetes resources (namespaces, service accounts) in your EKS cluster:

```
Error: Post "https://61473F4207F882065472584FBAE2DA39.gr7.us-east-1.eks.amazonaws.com/api/v1/namespaces": dial tcp 172.31.10.79:443: i/o timeout
Error: Post "https://61473F4207F882065472584FBAE2DA39.gr7.us-east-1.eks.amazonaws.com/api/v1/namespaces/kube-system/serviceaccounts": context deadline exceeded
```

**Root Cause**: Terraform is running on an EC2 instance (ip-172-31-27-96) that cannot reach the EKS cluster API endpoint due to:
1. Missing security group rules
2. Insufficient timeout configurations
3. Network connectivity issues between EC2 and EKS private endpoint

---

## What We Fixed

### 1. **Enhanced Kubernetes Provider Configuration** (`provider.tf`)

**Changes Made:**
- Added `exec` authentication using AWS CLI for better retry logic
- This provides dynamic token refresh and better error handling

**Benefits:**
- Automatic token refresh
- Better retry mechanism
- More reliable authentication from EC2 instances

### 2. **Added EKS Security Group Rules** (`modules/eks/main.tf`)

**Changes Made:**
- Added ingress rule to allow VPC CIDR access to cluster API (port 443)
- This allows any EC2 instance in the VPC to communicate with the EKS cluster

**New Rule:**
```hcl
ingress_vpc_https = {
  description = "VPC HTTPS access to cluster API"
  protocol    = "tcp"
  from_port   = 443
  to_port     = 443
  type        = "ingress"
  cidr_blocks = [data.aws_vpc.default.cidr_block]
}
```

### 3. **Added Timeout Configurations** 

**Microservices Module** (`modules/microservices/main.tf`):
- Added 5-minute timeouts to `kubernetes_namespace` resource
- Added 5-minute timeouts to `kubernetes_service_account` resource

**AWS Load Balancer Controller** (`modules/aws-load-balancer-controller/main.tf`):
- Added 5-minute timeouts to `kubernetes_service_account` resource
- Added 10-minute timeout to `helm_release` resource
- Added `wait = true` and `wait_for_jobs = true` for helm installation

---

## How to Apply the Fix

### Option 1: Automated Fix (Recommended)

Run the automated fix script from your EC2 instance:

```bash
cd terraform
chmod +x fix-terraform-eks-connectivity.sh
./fix-terraform-eks-connectivity.sh
```

This script will:
1. ✅ Check prerequisites (AWS CLI, kubectl)
2. ✅ Update kubeconfig
3. ✅ Test cluster connectivity
4. ✅ Import existing Kubernetes resources to Terraform state
5. ✅ Re-initialize Terraform

### Option 2: Manual Fix Steps

#### Step 1: Update Kubeconfig on EC2 Instance

```bash
aws eks update-kubeconfig --name meracommerce-dev-cluster --region us-east-1
```

#### Step 2: Verify Cluster Connectivity

```bash
# Test basic connectivity
kubectl cluster-info

# Test if you can list nodes
kubectl get nodes

# Test if you can access kube-system namespace
kubectl get pods -n kube-system
```

If these commands fail, you have a connectivity issue. See "Troubleshooting" section below.

#### Step 3: Import Existing Kubernetes Resources (if any exist)

If resources were partially created before the timeout, import them:

```bash
cd terraform

# Import namespaces if they exist
terraform import module.order_service.kubernetes_namespace.microservice order-service-ns
terraform import module.catalog_service.kubernetes_namespace.microservice catalog-service-ns
terraform import module.customer_service.kubernetes_namespace.microservice customer-service-ns

# Import service account if it exists
terraform import module.aws_load_balancer_controller.kubernetes_service_account.aws_load_balancer_controller kube-system/aws-load-balancer-controller
```

#### Step 4: Apply Security Group Fix

```bash
# Destroy and recreate the cluster with new security group rules
cd terraform
terraform init -upgrade
terraform plan -var-file=environments/dev.tfvars -target=module.eks
terraform apply -var-file=environments/dev.tfvars -target=module.eks
```

#### Step 5: Apply Full Configuration

```bash
terraform plan -var-file=environments/dev.tfvars
terraform apply -var-file=environments/dev.tfvars
```

---

## Troubleshooting

### Issue 1: "kubectl: command not found"

**Solution**: Install kubectl on EC2 instance

```bash
# Amazon Linux 2/2023
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
chmod +x kubectl
sudo mv kubectl /usr/local/bin/
```

### Issue 2: "Unable to connect to the server: dial tcp: i/o timeout"

**Possible Causes:**
1. EC2 instance security group doesn't allow outbound HTTPS (443)
2. Cluster security group doesn't allow inbound from VPC
3. DNS resolution issues

**Solutions:**

**A. Check EC2 Security Group**
```bash
# Get instance ID
INSTANCE_ID=$(ec2-metadata --instance-id | cut -d ' ' -f 2)

# Get security groups
aws ec2 describe-instances --instance-ids $INSTANCE_ID \
  --query 'Reservations[0].Instances[0].SecurityGroups' \
  --region us-east-1

# Check if outbound 443 is allowed
# Should have egress rule: 0.0.0.0/0 on port 443 or all traffic
```

**B. Check Cluster Security Group**
```bash
# Get cluster security group
CLUSTER_SG=$(aws eks describe-cluster --name meracommerce-dev-cluster \
  --region us-east-1 \
  --query 'cluster.resourcesVpcConfig.clusterSecurityGroupId' \
  --output text)

echo "Cluster Security Group: $CLUSTER_SG"

# Check ingress rules
aws ec2 describe-security-groups --group-ids $CLUSTER_SG --region us-east-1
```

**C. Test Cluster Endpoint Reachability**
```bash
# Get cluster endpoint
CLUSTER_ENDPOINT=$(aws eks describe-cluster --name meracommerce-dev-cluster \
  --region us-east-1 \
  --query 'cluster.endpoint' \
  --output text)

echo "Testing connectivity to: $CLUSTER_ENDPOINT"

# Test with curl (should get SSL error, but that's OK - means it's reachable)
curl -k $CLUSTER_ENDPOINT

# Test with telnet
telnet $(echo $CLUSTER_ENDPOINT | cut -d'/' -f3) 443
```

**D. Manually Add Security Group Rule** (if terraform apply fails)
```bash
# Get VPC CIDR
VPC_CIDR=$(aws ec2 describe-vpcs --filters "Name=isDefault,Values=true" \
  --region us-east-1 \
  --query 'Vpcs[0].CidrBlock' \
  --output text)

# Add ingress rule to cluster security group
aws ec2 authorize-security-group-ingress \
  --group-id $CLUSTER_SG \
  --protocol tcp \
  --port 443 \
  --cidr $VPC_CIDR \
  --region us-east-1
```

### Issue 3: "error: You must be logged in to the server (Unauthorized)"

**Cause**: IAM permissions issue

**Solution**: Ensure the IAM user/role running Terraform has proper EKS permissions

```bash
# Check current IAM identity
aws sts get-caller-identity

# Ensure this identity has these permissions:
# - eks:DescribeCluster
# - eks:ListClusters
# - eks:AccessKubernetesApi
```

### Issue 4: Cluster was created but Kubernetes resources keep timing out

**Quick Fix**: Increase timeout values further

Edit the timeout values in:
- `modules/microservices/main.tf` - increase from 5m to 10m
- `modules/aws-load-balancer-controller/main.tf` - increase from 5m to 10m

```hcl
timeouts {
  create = "10m"  # Increased from 5m
  delete = "10m"
}
```

### Issue 5: Resources already exist errors

**Error Message**: "already exists"

**Solution**: Import existing resources into Terraform state

```bash
# List all namespaces
kubectl get namespaces

# Import each namespace
terraform import module.order_service.kubernetes_namespace.microservice order-service-ns

# List service accounts
kubectl get serviceaccounts -n kube-system

# Import service account
terraform import module.aws_load_balancer_controller.kubernetes_service_account.aws_load_balancer_controller kube-system/aws-load-balancer-controller
```

---

## Verification Steps

After applying the fix, verify everything is working:

### 1. Verify Cluster is Running
```bash
aws eks describe-cluster --name meracommerce-dev-cluster --region us-east-1
kubectl get nodes
```

### 2. Verify Namespaces Created
```bash
kubectl get namespaces
# Should see: order-service-ns, catalog-service-ns, customer-service-ns
```

### 3. Verify Service Accounts
```bash
kubectl get serviceaccounts -n order-service-ns
kubectl get serviceaccounts -n catalog-service-ns
kubectl get serviceaccounts -n customer-service-ns
kubectl get serviceaccounts -n kube-system | grep aws-load-balancer-controller
```

### 4. Verify IRSA Annotations
```bash
kubectl describe serviceaccount order-sa -n order-service-ns
# Should have annotation: eks.amazonaws.com/role-arn
```

### 5. Verify Load Balancer Controller
```bash
kubectl get pods -n kube-system | grep aws-load-balancer-controller
# Should show running pods
```

---

## Jenkins Pipeline Integration

If you're running this through Jenkins, ensure:

1. **Jenkins EC2 instance has proper IAM role**:
   ```json
   {
     "Version": "2012-10-17",
     "Statement": [
       {
         "Effect": "Allow",
         "Action": [
           "eks:*",
           "ec2:Describe*",
           "iam:GetRole",
           "iam:ListRoles"
         ],
         "Resource": "*"
       }
     ]
   }
   ```

2. **Jenkins security group allows outbound HTTPS (443)**

3. **Update Jenkinsfile** to include kubeconfig setup:
   ```groovy
   stage('Setup Kubeconfig') {
       steps {
           sh '''
               aws eks update-kubeconfig --name meracommerce-dev-cluster --region us-east-1
               kubectl cluster-info
           '''
       }
   }
   ```

---

## Prevention for Future Deployments

1. **Always run from a properly configured environment**:
   - EC2 instance in same VPC as EKS cluster
   - Proper security group rules
   - IAM role with EKS permissions

2. **Use longer timeouts for production**:
   - Kubernetes resources: 10-15 minutes
   - Helm releases: 15-20 minutes

3. **Test connectivity before running Terraform**:
   ```bash
   aws eks update-kubeconfig --name <cluster-name> --region <region>
   kubectl cluster-info
   ```

4. **Use Terraform workspaces for different environments**:
   ```bash
   terraform workspace new dev
   terraform workspace select dev
   ```

---

## Summary of Changes

| File | Change | Purpose |
|------|--------|----------|
| `provider.tf` | Added exec auth for Kubernetes/Helm providers | Better authentication and retry logic |
| `modules/eks/main.tf` | Added VPC HTTPS ingress rule | Allow EC2 instances to reach cluster API |
| `modules/microservices/main.tf` | Added 5m timeouts to resources | Prevent premature timeout errors |
| `modules/aws-load-balancer-controller/main.tf` | Added 5-10m timeouts | Prevent helm installation timeouts |
| `fix-terraform-eks-connectivity.sh` | New automated fix script | Streamline fix application |

---

## Need More Help?

If you're still experiencing issues after following this guide:

1. **Check Terraform logs**: `TF_LOG=DEBUG terraform apply`
2. **Check kubectl logs**: `kubectl logs -n kube-system <pod-name>`
3. **Verify AWS credentials**: `aws sts get-caller-identity`
4. **Check VPC DNS**: Ensure VPC has DNS resolution and DNS hostnames enabled

---

**Generated**: 2026-08-28  
**Terraform Version**: >= 1.0.0  
**EKS Cluster**: meracommerce-dev-cluster  
**Region**: us-east-1
