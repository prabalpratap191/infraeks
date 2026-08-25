# Common Errors - Quick Fix Guide

Quick reference guide for resolving common errors during InfraEKS deployment.

---

## 🔴 Error 0: Resources Already Exist (KMS, CloudWatch)

### Error Message
```
Error: creating KMS Alias (alias/eks/meracommerce-dev): 
AlreadyExistsException: An alias with the name already exists

Error: creating CloudWatch Logs Log Group (/aws/eks/meracommerce-dev/cluster): 
ResourceAlreadyExistsException: The specified log group already exists
```

### Quick Fix

**Option 1: Run cleanup script (FASTEST)**
```powershell
# PowerShell
cd scripts
.\cleanup-aws-resources.ps1
```

```bash
# Bash
cd scripts
chmod +x cleanup-aws-resources.sh
./cleanup-aws-resources.sh
```

**Option 2: Manual cleanup**
```bash
# Delete KMS alias
aws kms delete-alias --alias-name alias/eks/meracommerce-dev --region us-east-1

# Delete CloudWatch log group
aws logs delete-log-group --log-group-name /aws/eks/meracommerce-dev/cluster --region us-east-1
```

📖 **Full Guide**: [RESOURCE_ALREADY_EXISTS_FIX.md](RESOURCE_ALREADY_EXISTS_FIX.md)

---

## 🔴 Error 1: IAM Role Name Length Exceeded

### Error Message
```
Error: expected length of name_prefix to be in the range (1 - 38), 
got meracommerce-dev-node-group-eks-node-group-
```

### Quick Fix
✅ **Solution**: Already fixed in `terraform/modules/eks/main.tf`

```hcl
eks_managed_node_groups = {
  default = {
    name            = "${var.cluster_name}-ng"
    iam_role_name   = "${var.cluster_name}-node-role"
    iam_role_use_name_prefix = false
  }
}
```

### Deploy Fix
```bash
cd terraform
rm -rf .terraform .terraform.lock.hcl
terraform init
terraform apply -var-file=meracommerce-dev.tfvars -auto-approve
```

📖 **Full Guide**: [IAM_ROLE_NAME_LENGTH_FIX.md](IAM_ROLE_NAME_LENGTH_FIX.md)

---

## 🔴 Error 2: Node Group Not Joining Cluster

### Symptoms
```bash
kubectl get nodes
# No nodes listed or nodes show "NotReady"
```

### Quick Fix

1. **Check node status**:
```bash
aws eks describe-nodegroup \
  --cluster-name meracommerce-dev \
  --nodegroup-name meracommerce-dev-ng \
  --region us-east-1
```

2. **Check IAM role**:
```bash
# Verify IAM role is attached
aws iam get-role --role-name meracommerce-dev-node-role

# Check if CNI policy is attached
aws iam list-attached-role-policies --role-name meracommerce-dev-node-role
```

3. **Re-create node group**:
```bash
# In terraform/modules/eks/main.tf, toggle desired_size
cd terraform
terraform apply -var node_desired=0 -var-file=meracommerce-dev.tfvars
terraform apply -var node_desired=2 -var-file=meracommerce-dev.tfvars
```

📖 **Full Guide**: [EKS_NODE_GROUP_TROUBLESHOOTING.md](EKS_NODE_GROUP_TROUBLESHOOTING.md)

---

## 🔴 Error 3: Terraform State Lock

### Error Message
```
Error: Error acquiring the state lock
Lock Info:
  ID: xxxxx-xxxx-xxxx-xxxx-xxxxxxxxx
```

### Quick Fix

```bash
# Force unlock (use the Lock ID from error message)
cd terraform
terraform force-unlock <LOCK_ID>

# If that fails, delete .terraform directory and re-init
rm -rf .terraform .terraform.lock.hcl
terraform init
```

---

## 🔴 Error 4: Subnet Not Available in us-east-1e

### Error Message
```
Error: creating EKS Node Group: UnsupportedAvailabilityZoneException: 
Cannot create cluster 'meracommerce-dev' because us-east-1e is not supported
```

### Quick Fix
✅ **Solution**: Already fixed in `terraform/modules/eks/main.tf`

```hcl
data "aws_subnets" "filtered" {
  filter {
    name   = "availability-zone"
    values = ["us-east-1a", "us-east-1b", "us-east-1c"]  # Excludes us-east-1e
  }
}
```

No action needed - this is already configured correctly.

---

## 🔴 Error 5: ALB Controller Not Creating Load Balancer

### Symptoms
```bash
kubectl get ingress
# ADDRESS field is empty
```

### Quick Fix

1. **Check ALB controller logs**:
```bash
kubectl logs -n kube-system deployment/aws-load-balancer-controller
```

2. **Verify IAM permissions**:
```bash
aws iam get-role --role-name meracommerce-dev-aws-load-balancer-controller
```

3. **Check ingress annotations**:
```bash
kubectl describe ingress microservices-ingress
```

4. **Restart controller**:
```bash
kubectl rollout restart deployment/aws-load-balancer-controller -n kube-system
```

5. **Re-apply ingress**:
```bash
kubectl delete ingress microservices-ingress
kubectl apply -f k8s-manifests/ingress.yaml
```

---

## 🔴 Error 6: Pods ImagePullBackOff

### Error Message
```bash
kubectl get pods -n order-service-ns
# NAME                            READY   STATUS             RESTARTS   AGE
# order-service-xxx               0/2     ImagePullBackOff   0          2m
```

### Quick Fix

1. **Check ECR repository**:
```bash
aws ecr describe-repositories --region us-east-1 | grep order-service
```

2. **Verify image exists**:
```bash
aws ecr list-images --repository-name order-service --region us-east-1
```

3. **Check IAM permissions for ECR**:
```bash
# Node role should have ECR pull permissions
aws iam list-attached-role-policies --role-name meracommerce-dev-node-role
```

4. **Update deployment with correct image**:
```yaml
# In k8s-manifests/order-service/deployment.yaml
image: <ACCOUNT_ID>.dkr.ecr.us-east-1.amazonaws.com/order-service:latest
```

---

## 🔴 Error 7: Service Account Not Assuming IAM Role

### Symptoms
Pods cannot access AWS services (S3, DynamoDB, etc.)

### Quick Fix

1. **Verify service account annotation**:
```bash
kubectl get sa order-sa -n order-service-ns -o yaml | grep eks.amazonaws.com/role-arn
```

2. **Check IAM role trust policy**:
```bash
aws iam get-role --role-name meracommerce-dev-order-service-irsa --query 'Role.AssumeRolePolicyDocument'
```

3. **Verify OIDC provider**:
```bash
aws eks describe-cluster --name meracommerce-dev --region us-east-1 --query 'cluster.identity.oidc.issuer'
```

4. **Re-apply Terraform IRSA module**:
```bash
cd terraform
terraform apply -target=module.order_service -var-file=meracommerce-dev.tfvars
```

---

## 🔴 Error 8: Network Policy Blocking Traffic

### Symptoms
Services cannot communicate with each other

### Quick Fix

1. **Test connectivity**:
```bash
kubectl exec -n order-service-ns deployment/order-service -- \
  curl -v http://catalog-service.catalog-service-ns.svc.cluster.local:8080/actuator/health
```

2. **Temporarily disable network policy**:
```bash
kubectl delete networkpolicy order-service-netpol -n order-service-ns
```

3. **Test again** - if it works, the network policy is the issue

4. **Review and fix network policy**:
```bash
kubectl get networkpolicy -n order-service-ns -o yaml
```

5. **Re-apply corrected policy**:
```bash
cd terraform
terraform apply -target=module.order_service -var-file=meracommerce-dev.tfvars
```

---

## 🔴 Error 9: Jenkins AWS Credentials Not Working

### Error Message
```
AWS CLI not available or credentials invalid
```

### Quick Fix

1. **Verify Jenkins credentials**:
   - Go to Jenkins > Manage Jenkins > Credentials
   - Check that `jenkins-user` exists with correct AWS Access Key ID and Secret

2. **Test credentials in Jenkins**:
```bash
# In Jenkins pipeline, add test stage:
stage('Test AWS') {
  steps {
    withCredentials([[$class: 'AmazonWebServicesCredentialsBinding',
      credentialsId: 'jenkins-user']]) {
      sh 'aws sts get-caller-identity'
    }
  }
}
```

3. **Update IAM policy** for jenkins-user:
```bash
aws iam attach-user-policy \
  --user-name jenkins \
  --policy-arn arn:aws:iam::aws:policy/AdministratorAccess
```

---

## 🔴 Error 10: Terraform Provider Version Mismatch

### Error Message
```
Error: Failed to query available provider packages
Provider version constraints not met
```

### Quick Fix

```bash
cd terraform

# Clean all provider caches
rm -rf .terraform .terraform.lock.hcl

# Re-initialize
terraform init -upgrade

# Verify versions
terraform version
terraform providers
```

---

## 🛠️ General Troubleshooting Commands

### Cluster Health Check
```bash
# Check cluster status
aws eks describe-cluster --name meracommerce-dev --region us-east-1

# Check node group
aws eks describe-nodegroup \
  --cluster-name meracommerce-dev \
  --nodegroup-name meracommerce-dev-ng \
  --region us-east-1

# Check nodes
kubectl get nodes -o wide

# Check all pods
kubectl get pods --all-namespaces

# Check system pods
kubectl get pods -n kube-system
```

### Application Health Check
```bash
# Check all microservice namespaces
kubectl get all -n order-service-ns
kubectl get all -n catalog-service-ns
kubectl get all -n customer-service-ns

# Check pod logs
kubectl logs -f deployment/order-service -n order-service-ns

# Check pod events
kubectl describe pod <pod-name> -n <namespace>
```

### Network Diagnostics
```bash
# Check services
kubectl get svc --all-namespaces

# Check endpoints
kubectl get endpoints -n order-service-ns

# Check ingress
kubectl get ingress
kubectl describe ingress microservices-ingress

# Check network policies
kubectl get networkpolicy --all-namespaces
```

### AWS Resource Check
```bash
# Check IAM roles
aws iam list-roles --query 'Roles[?contains(RoleName, `meracommerce`)].RoleName'

# Check ECR repositories
aws ecr describe-repositories --region us-east-1

# Check Load Balancers
aws elbv2 describe-load-balancers --region us-east-1

# Check Target Groups
aws elbv2 describe-target-groups --region us-east-1
```

---

## 🎓 Best Practices to Avoid Errors

### 1. Always Validate Before Apply
```bash
terraform validate
terraform plan -var-file=meracommerce-dev.tfvars | less
```

### 2. Use Terraform State Locking
```hcl
# In terraform/backend/backend.tf
terraform {
  backend "s3" {
    bucket         = "my-terraform-state"
    key            = "eks/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "terraform-state-lock"
    encrypt        = true
  }
}
```

### 3. Version Pin Dependencies
```hcl
# In terraform/main.tf
required_providers {
  aws = {
    source  = "hashicorp/aws"
    version = "~> 5.0"  # Pin to major version
  }
}
```

### 4. Keep Names Short
```hcl
# Good: mc-dev-ng (9 chars)
# Bad: meracommerce-development-node-group (37 chars)
```

### 5. Regular State Backups
```bash
# Backup Terraform state
cp terraform.tfstate terraform.tfstate.backup-$(date +%Y%m%d)

# Or use remote backend with versioning
```

### 6. Test in Stages
```bash
# Don't apply everything at once
terraform apply -target=module.eks
terraform apply -target=module.order_service
terraform apply  # Full apply
```

---

## 📞 Getting Help

If you encounter an error not listed here:

1. **Check detailed guides**:
   - [IMPLEMENTATION_GUIDE.md](IMPLEMENTATION_GUIDE.md)
   - [EKS_NODE_GROUP_TROUBLESHOOTING.md](EKS_NODE_GROUP_TROUBLESHOOTING.md)
   - [IAM_ROLE_NAME_LENGTH_FIX.md](IAM_ROLE_NAME_LENGTH_FIX.md)

2. **Search logs**:
   ```bash
   kubectl logs -n kube-system deployment/aws-load-balancer-controller
   kubectl logs -n order-service-ns deployment/order-service
   ```

3. **Enable debug mode**:
   ```bash
   export TF_LOG=DEBUG
   terraform apply -var-file=meracommerce-dev.tfvars
   ```

4. **Create GitHub issue** with:
   - Error message
   - Terraform version
   - Steps to reproduce
   - Relevant logs

---

**Last Updated**: 2026-08-25  
**Status**: Active Reference Guide 📖
