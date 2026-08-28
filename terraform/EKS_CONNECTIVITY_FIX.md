# EKS Cluster Connectivity Issues - Troubleshooting Guide

## Problem Summary

Terraform successfully created the EKS cluster and node groups, but failed when trying to create Kubernetes resources (namespaces, service accounts) with timeout errors:

```
Error: Post "https://61473F4207F882065472584FBAE2DA39.gr7.us-east-1.eks.amazonaws.com/api/v1/namespaces": 
dial tcp 172.31.10.79:443: i/o timeout
```

## Root Cause

The EC2 instance (ip-172-31-27-96) where Terraform is running **cannot establish HTTPS connections to the EKS API server endpoint** due to one or more of these issues:

1. **Security Group restrictions** - EC2 instance's security group blocks outbound HTTPS (port 443)
2. **Network ACLs** - VPC network ACLs may be blocking traffic
3. **Route table issues** - Missing routes to internet gateway for public endpoint access

## Solution Steps

### Step 1: Fix EC2 Instance Security Group

The EC2 instance needs to allow outbound HTTPS traffic to reach the EKS API endpoint.

#### Find your EC2 instance's security group:

```bash
# Get the instance ID
INSTANCE_ID=$(ec2-metadata --instance-id | cut -d " " -f 2)

# Get the security group ID
SG_ID=$(aws ec2 describe-instances --instance-ids $INSTANCE_ID \
  --query 'Reservations[0].Instances[0].SecurityGroups[0].GroupId' \
  --output text --region us-east-1)

echo "EC2 Instance Security Group: $SG_ID"
```

#### Add outbound HTTPS rule:

```bash
# Add egress rule for HTTPS to anywhere (0.0.0.0/0)
aws ec2 authorize-security-group-egress \
  --group-id $SG_ID \
  --protocol tcp \
  --port 443 \
  --cidr 0.0.0.0/0 \
  --region us-east-1
```

Or update via AWS Console:
1. Go to **EC2 Console** → **Security Groups**
2. Find the security group attached to `ip-172-31-27-96`
3. Go to **Outbound rules** tab
4. Click **Edit outbound rules**
5. Add rule:
   - Type: `HTTPS`
   - Protocol: `TCP`
   - Port: `443`
   - Destination: `0.0.0.0/0`
6. Click **Save rules**

### Step 2: Verify Network Configuration

#### Check current security group rules:

```bash
# Check outbound rules
aws ec2 describe-security-groups \
  --group-ids $SG_ID \
  --query 'SecurityGroups[0].IpPermissionsEgress' \
  --region us-east-1
```

#### Test connectivity to EKS endpoint:

```bash
# Test DNS resolution and connectivity
EKS_ENDPOINT="61473F4207F882065472584FBAE2DA39.gr7.us-east-1.eks.amazonaws.com"

# Test DNS resolution
nslookup $EKS_ENDPOINT

# Test HTTPS connectivity (should connect, even if TLS fails)
curl -v --max-time 10 https://$EKS_ENDPOINT 2>&1 | grep -E "Connected|timeout|refused"

# Alternative: Use telnet
telnet $EKS_ENDPOINT 443
```

### Step 3: Configure kubectl on EC2 Instance

Once network connectivity is fixed:

```bash
# Update kubeconfig for EKS cluster
aws eks update-kubeconfig \
  --region us-east-1 \
  --name meracommerce-dev-cluster

# Verify kubectl can connect
kubectl get nodes
kubectl get namespaces
```

### Step 4: Re-run Terraform Apply

After fixing the connectivity issues:

```bash
cd ~/terraform  # or your terraform directory

# Re-run terraform apply to create the failed resources
terraform apply
```

Terraform will:
- Skip resources that were already created successfully (VPC, EKS cluster, node groups, IAM roles)
- Retry creating the failed resources (namespaces, service accounts, load balancer controller)

## Verification Commands

### Verify EKS Cluster

```bash
# Check cluster status
aws eks describe-cluster \
  --region us-east-1 \
  --name meracommerce-dev-cluster \
  --query 'cluster.status'

# Verify nodes are ready
kubectl get nodes -o wide

# Check node status details
kubectl describe nodes
```

### Verify Kubernetes Resources

```bash
# Check namespaces
kubectl get namespaces

# Expected namespaces after successful terraform apply:
# - default
# - kube-system
# - kube-public
# - kube-node-lease
# - catalog-service
# - customer-service
# - order-service

# Check service accounts
kubectl get serviceaccounts -A

# Check AWS Load Balancer Controller
kubectl get sa -n kube-system aws-load-balancer-controller
```

## Alternative: Manual Resource Creation

If Terraform continues to have issues, you can manually create the Kubernetes resources:

### Create Namespaces Manually

```bash
# Create microservice namespaces
kubectl create namespace catalog-service
kubectl create namespace customer-service
kubectl create namespace order-service

# Verify
kubectl get namespaces
```

### Create Service Accounts Manually

```bash
# AWS Load Balancer Controller Service Account
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: ServiceAccount
metadata:
  name: aws-load-balancer-controller
  namespace: kube-system
  annotations:
    eks.amazonaws.com/role-arn: arn:aws:iam::230476794540:role/meracommerce-dev-cluster-aws-load-balancer-controller
EOF

# Verify
kubectl get sa -n kube-system aws-load-balancer-controller
```

## Common Issues and Solutions

### Issue: "error: the server doesn't have a resource type 'nodes'"

**Cause:** Authentication/authorization issue with kubectl

**Solution:**
```bash
# Re-configure kubectl
aws eks update-kubeconfig --region us-east-1 --name meracommerce-dev-cluster

# Verify AWS credentials
aws sts get-caller-identity

# The output should show the IAM user/role that created the cluster
```

### Issue: "Unable to connect to the server: dial tcp: i/o timeout"

**Cause:** Network connectivity issue

**Solution:** Follow Steps 1-2 above to fix security groups and network configuration

### Issue: "context deadline exceeded"

**Cause:** Request timeout due to slow network or overloaded API server

**Solution:**
```bash
# Increase kubectl timeout
export KUBECTL_TIMEOUT=60s

# Or add --request-timeout flag
kubectl get nodes --request-timeout=60s
```

## Terraform State Management

### Check Terraform State

```bash
# List all resources in state
terraform state list

# Show specific resource state
terraform state show module.customer_service.kubernetes_namespace.microservice
```

### Remove Failed Resources from State (if needed)

Only do this if resources are stuck in a bad state:

```bash
# Remove namespace resources from state
terraform state rm module.customer_service.kubernetes_namespace.microservice
terraform state rm module.catalog_service.kubernetes_namespace.microservice
terraform state rm module.order_service.kubernetes_namespace.microservice
terraform state rm module.aws_load_balancer_controller.kubernetes_service_account.aws_load_balancer_controller

# Then re-run terraform apply
terraform apply
```

## Next Steps After Resolution

1. **Verify all resources are created:**
   ```bash
   kubectl get all -A
   ```

2. **Install AWS Load Balancer Controller** (if using Helm):
   ```bash
   helm repo add eks https://aws.github.io/eks-charts
   helm install aws-load-balancer-controller eks/aws-load-balancer-controller \
     -n kube-system \
     --set clusterName=meracommerce-dev-cluster \
     --set serviceAccount.create=false \
     --set serviceAccount.name=aws-load-balancer-controller
   ```

3. **Deploy your microservices:**
   - Create deployment manifests
   - Apply Kubernetes deployments and services
   - Configure ingress resources

## Prevention for Future Deployments

### Update EC2 Instance Security Group in Advance

Before running Terraform for EKS deployments, ensure the EC2 instance has proper outbound access:

```hcl
# Add to your infrastructure code
resource "aws_security_group_rule" "eks_management_egress" {
  type              = "egress"
  from_port         = 443
  to_port           = 443
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.ec2_instance.id
  description       = "Allow HTTPS to EKS API server"
}
```

## Summary

The core issue is **network connectivity** from your EC2 instance to the EKS API endpoint. Follow the steps in order:

1. ✅ Fix EC2 security group outbound rules
2. ✅ Verify connectivity to EKS endpoint
3. ✅ Configure kubectl
4. ✅ Re-run terraform apply
5. ✅ Verify all resources are created

Once connectivity is restored, Terraform should successfully complete the deployment.
