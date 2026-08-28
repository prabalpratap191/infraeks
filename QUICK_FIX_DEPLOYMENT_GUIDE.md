# Quick Fix Deployment Guide - EKS Connectivity Issues

## 🎯 Problem Overview

You encountered these errors during `terraform apply`:

```
Error: Post "https://...eks.amazonaws.com/api/v1/namespaces": dial tcp 172.31.10.79:443: i/o timeout
Error: Post "https://...eks.amazonaws.com/api/v1/namespaces/kube-system/serviceaccounts": context deadline exceeded
```

**Root Cause**: EC2 instance running Terraform cannot reach EKS cluster API endpoint.

---

## ✅ What Was Fixed

We've made comprehensive fixes to your infrastructure:

### 1. Enhanced Terraform Providers
**File**: `terraform/provider.tf`
- ✅ Added AWS CLI exec authentication
- ✅ Better retry and token refresh logic
- ✅ Improved connection handling from EC2

### 2. Security Group Rules
**File**: `terraform/modules/eks/main.tf`
- ✅ Added VPC CIDR ingress rule for port 443
- ✅ Allows EC2 instances to reach cluster API

### 3. Extended Timeouts
**Files**: 
- `terraform/modules/microservices/main.tf`
- `terraform/modules/aws-load-balancer-controller/main.tf`
- ✅ Increased timeouts from 30s to 5-10 minutes
- ✅ Added wait flags for helm deployments

### 4. Automation Scripts
- ✅ `terraform/fix-terraform-eks-connectivity.sh` - Quick fix script
- ✅ `scripts/jenkins-terraform-wrapper.sh` - Jenkins integration script
- ✅ `Jenkinsfile.eks-connectivity-fixed` - Improved Jenkins pipeline

---

## 🚀 Quick Start - Choose Your Method

### Method 1: Automated Fix (Recommended)

**From EC2 Instance (Jenkins server):**

```bash
# Navigate to terraform directory
cd infraeks-master/terraform

# Make script executable
chmod +x fix-terraform-eks-connectivity.sh

# Run the fix
./fix-terraform-eks-connectivity.sh

# Then apply Terraform
terraform plan -var-file=environments/dev.tfvars
terraform apply -var-file=environments/dev.tfvars
```

### Method 2: Using Jenkins Pipeline

**Option A: Use New Improved Jenkinsfile**

1. Replace your current `Jenkinsfile` with `Jenkinsfile.eks-connectivity-fixed`:
   ```bash
   cd infraeks-master
   cp Jenkinsfile Jenkinsfile.backup
   cp Jenkinsfile.eks-connectivity-fixed Jenkinsfile
   git add Jenkinsfile
   git commit -m "Updated Jenkinsfile with EKS connectivity fixes"
   git push
   ```

2. In Jenkins:
   - Create/Update pipeline job
   - Point to your repository
   - Select branch: `mainbranch`
   - Run the pipeline with:
     - `TERRAFORM_ACTION`: `apply`
     - `USE_WRAPPER_SCRIPT`: `true` (checked)

**Option B: Use Wrapper Script in Existing Pipeline**

Add this stage to your existing Jenkinsfile:

```groovy
stage('Deploy Infrastructure') {
    steps {
        withCredentials([[
            $class: 'AmazonWebServicesCredentialsBinding',
            credentialsId: 'jenkins-user',
            accessKeyVariable: 'AWS_ACCESS_KEY_ID',
            secretKeyVariable: 'AWS_SECRET_ACCESS_KEY'
        ]]) {
            sh '''
                chmod +x scripts/jenkins-terraform-wrapper.sh
                ./scripts/jenkins-terraform-wrapper.sh
            '''
        }
    }
}
```

### Method 3: Manual Fix

**Step-by-step on EC2 instance:**

```bash
# 1. Update kubeconfig
aws eks update-kubeconfig --name meracommerce-dev-cluster --region us-east-1

# 2. Test connectivity
kubectl cluster-info

# 3. If connectivity fails, manually add security group rule
CLUSTER_SG=$(aws eks describe-cluster --name meracommerce-dev-cluster \
  --region us-east-1 \
  --query 'cluster.resourcesVpcConfig.clusterSecurityGroupId' \
  --output text)

VPC_CIDR=$(aws ec2 describe-vpcs --filters "Name=isDefault,Values=true" \
  --region us-east-1 \
  --query 'Vpcs[0].CidrBlock' \
  --output text)

aws ec2 authorize-security-group-ingress \
  --group-id $CLUSTER_SG \
  --protocol tcp \
  --port 443 \
  --cidr $VPC_CIDR \
  --region us-east-1

# 4. Re-apply Terraform
cd infraeks-master/terraform
terraform init -upgrade
terraform apply -var-file=environments/dev.tfvars
```

---

## 🔍 Verification Steps

After deployment, verify everything works:

```bash
# 1. Check cluster is running
aws eks describe-cluster --name meracommerce-dev-cluster --region us-east-1

# 2. Check nodes
kubectl get nodes

# 3. Check namespaces
kubectl get namespaces | grep -E 'order|catalog|customer'

# Expected output:
# order-service-ns
# catalog-service-ns
# customer-service-ns

# 4. Check service accounts
kubectl get serviceaccounts -A | grep -E 'order-sa|catalog-sa|customer-sa'

# 5. Check IRSA annotations
kubectl describe sa order-sa -n order-service-ns | grep role-arn

# 6. Check Load Balancer Controller
kubectl get pods -n kube-system | grep aws-load-balancer-controller

# 7. Verify all is healthy
kubectl get pods -A
```

---

## 📋 Files Changed Summary

| File | Status | Changes |
|------|--------|----------|
| `terraform/provider.tf` | ✏️ Modified | Added exec auth for Kubernetes/Helm providers |
| `terraform/modules/eks/main.tf` | ✏️ Modified | Added VPC HTTPS ingress security group rule |
| `terraform/modules/microservices/main.tf` | ✏️ Modified | Added 5-minute timeouts to resources |
| `terraform/modules/aws-load-balancer-controller/main.tf` | ✏️ Modified | Added 5-10 minute timeouts |
| `terraform/fix-terraform-eks-connectivity.sh` | ✅ New | Automated fix script |
| `terraform/TERRAFORM_EKS_CONNECTIVITY_FIX.md` | ✅ New | Comprehensive troubleshooting guide |
| `scripts/jenkins-terraform-wrapper.sh` | ✅ New | Jenkins deployment wrapper |
| `Jenkinsfile.eks-connectivity-fixed` | ✅ New | Improved Jenkins pipeline |
| `QUICK_FIX_DEPLOYMENT_GUIDE.md` | ✅ New | This file |

---

## 🛠️ Troubleshooting Common Issues

### Issue: "kubectl: command not found"

```bash
# Install kubectl on Amazon Linux 2/2023
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
chmod +x kubectl
sudo mv kubectl /usr/local/bin/
kubectl version --client
```

### Issue: Still getting timeout errors

**Check EC2 security group allows outbound HTTPS:**
```bash
INSTANCE_ID=$(ec2-metadata --instance-id | cut -d ' ' -f 2)
aws ec2 describe-instances --instance-ids $INSTANCE_ID \
  --query 'Reservations[0].Instances[0].SecurityGroups' \
  --region us-east-1
```

**Verify cluster endpoint is reachable:**
```bash
CLUSTER_ENDPOINT=$(aws eks describe-cluster --name meracommerce-dev-cluster \
  --region us-east-1 \
  --query 'cluster.endpoint' \
  --output text)

echo "Testing: $CLUSTER_ENDPOINT"
curl -k $CLUSTER_ENDPOINT
# Should get SSL certificate error (this is good - means it's reachable)
```

### Issue: Resources already exist

**Import existing resources:**
```bash
cd terraform

# Import namespaces
terraform import module.order_service.kubernetes_namespace.microservice order-service-ns
terraform import module.catalog_service.kubernetes_namespace.microservice catalog-service-ns
terraform import module.customer_service.kubernetes_namespace.microservice customer-service-ns

# Import service account
terraform import module.aws_load_balancer_controller.kubernetes_service_account.aws_load_balancer_controller kube-system/aws-load-balancer-controller
```

### Issue: IAM permissions error

**Verify Jenkins user has proper permissions:**
```bash
aws sts get-caller-identity

# Check if user can access EKS
aws eks list-clusters --region us-east-1
```

If access is denied, attach this policy to Jenkins IAM user/role:

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
        "iam:ListRoles",
        "iam:CreateRole",
        "iam:AttachRolePolicy",
        "iam:PutRolePolicy"
      ],
      "Resource": "*"
    }
  ]
}
```

---

## 📞 Need More Help?

For detailed troubleshooting, refer to:
- 📖 **Comprehensive Guide**: `terraform/TERRAFORM_EKS_CONNECTIVITY_FIX.md`
- 🔧 **Architecture Docs**: `architecture-diagram.md`
- 📝 **Implementation Guide**: `IMPLEMENTATION_GUIDE.md`

---

## ✨ Next Steps After Successful Deployment

1. **Deploy Microservices**
   ```bash
   # Use the microservice-specific Jenkinsfiles
   jenkins-pipelines/Jenkinsfile-order-service
   jenkins-pipelines/Jenkinsfile-catalog-service
   ```

2. **Configure Ingress**
   ```bash
   kubectl apply -f k8s-manifests/ingress.yaml
   ```

3. **Monitor Deployment**
   ```bash
   kubectl get pods -A --watch
   ```

4. **Set Up Monitoring**
   - Install Prometheus
   - Install Grafana
   - Configure CloudWatch Container Insights

5. **Configure Auto-scaling**
   - Horizontal Pod Autoscaler (HPA)
   - Cluster Autoscaler

---

## 📊 Deployment Summary

✅ **What's Deployed:**
- EKS Cluster: `meracommerce-dev-cluster`
- Node Group: t3.medium instances (2-4 nodes)
- Namespaces: order-service-ns, catalog-service-ns, customer-service-ns
- Service Accounts with IRSA
- AWS Load Balancer Controller
- Network Policies
- Resource Quotas and Limits

✅ **Security Features:**
- RBAC enabled
- Network policies for inter-service communication
- IRSA for secure AWS resource access
- Encrypted EBS volumes
- Private VPC networking

---

**Last Updated**: 2026-08-28  
**Version**: 1.0  
**Cluster**: meracommerce-dev-cluster  
**Region**: us-east-1
