# Emergency Fix - Connectivity Still Failing

## Current Situation

You're still getting:
```
E0828 08:34:44.745854   10051 memcache.go:265] "Unhandled Error" err="couldn't get current server API group list: Get "https://...eks.amazonaws.com/api?timeout=32s": dial tcp 172.31.93.245:443: i/o timeout"
```

This means the **security group rule from Terraform hasn't been applied yet** or there's another blocking issue.

## Quick Fix (Run This Now)

### Option 1: Automated Emergency Fix

```bash
cd terraform
chmod +x quick-fix-now.sh
./quick-fix-now.sh
```

This will:
1. ✅ Add security group rules manually via AWS CLI
2. ✅ Attach cluster security group to your EC2 instance  
3. ✅ Test connectivity
4. ✅ Apply Terraform in targeted stages
5. ✅ Save debug info for troubleshooting

### Option 2: Manual Emergency Fix

#### Step 1: Add Security Group Rule Manually

```bash
cd terraform
chmod +x emergency-fix-security-group.sh
./emergency-fix-security-group.sh
```

This script will:
- Get your cluster security group
- Add VPC CIDR ingress rule for port 443
- Attach cluster SG to your EC2 instance
- Test connectivity
- Save debug info

#### Step 2: If connectivity works, apply Terraform

```bash
# Test first
kubectl cluster-info

# If that works, apply Terraform
chmod +x apply-terraform-with-target.sh
./apply-terraform-with-target.sh
```

## Alternative: Enable Public Endpoint Access

If the issue persists, the cluster might be using only private endpoint:

```bash
# Check current configuration
aws eks describe-cluster \
  --name meracommerce-dev-cluster \
  --region us-east-1 \
  --query 'cluster.resourcesVpcConfig.{PublicAccess:endpointPublicAccess,PrivateAccess:endpointPrivateAccess}'

# Enable public access if needed
aws eks update-cluster-config \
  --name meracommerce-dev-cluster \
  --region us-east-1 \
  --resources-vpc-config endpointPublicAccess=true,endpointPrivateAccess=true

# Wait for update to complete (takes 2-3 minutes)
aws eks wait cluster-active --name meracommerce-dev-cluster --region us-east-1

# Test again
kubectl cluster-info
```

## What Each Script Does

### `quick-fix-now.sh` (RECOMMENDED)
Runs everything automatically:
1. Emergency security group fix
2. Connectivity test  
3. Targeted Terraform apply
4. Full verification

### `emergency-fix-security-group.sh`
Diagnoses and fixes security group issues:
- Finds cluster security group
- Adds VPC ingress rule
- Attaches SG to EC2 instance
- Tests connectivity
- Saves debug info to `sg-debug-info.txt`

### `apply-terraform-with-target.sh`
Applies Terraform in stages:
1. Updates EKS module first (security groups)
2. Waits for propagation
3. Tests connectivity
4. Applies remaining resources

## Debug Information

After running `emergency-fix-security-group.sh`, check:

```bash
cat sg-debug-info.txt
```

This contains:
- Cluster details
- Security group configurations
- EC2 instance information
- Connectivity test results

## Common Issues & Solutions

### Issue 1: Cluster endpoint is private only

**Check:**
```bash
aws eks describe-cluster --name meracommerce-dev-cluster --region us-east-1 \
  --query 'cluster.resourcesVpcConfig.endpointPublicAccess'
```

**Fix:**
```bash
aws eks update-cluster-config --name meracommerce-dev-cluster --region us-east-1 \
  --resources-vpc-config endpointPublicAccess=true
```

### Issue 2: EC2 not in cluster security group

**Fix:** `emergency-fix-security-group.sh` will do this automatically

**Manual fix:**
```bash
INSTANCE_ID=$(ec2-metadata --instance-id | cut -d ' ' -f 2)
CLUSTER_SG=$(aws eks describe-cluster --name meracommerce-dev-cluster --region us-east-1 --query 'cluster.resourcesVpcConfig.clusterSecurityGroupId' --output text)
CURRENT_SGS=$(aws ec2 describe-instances --instance-ids $INSTANCE_ID --region us-east-1 --query 'Reservations[0].Instances[0].SecurityGroups[*].GroupId' --output text)

aws ec2 modify-instance-attribute --instance-id $INSTANCE_ID --groups $CURRENT_SGS $CLUSTER_SG --region us-east-1
```

### Issue 3: VPC DNS not enabled

**Check:**
```bash
VPC_ID=$(aws eks describe-cluster --name meracommerce-dev-cluster --region us-east-1 --query 'cluster.resourcesVpcConfig.vpcId' --output text)

aws ec2 describe-vpc-attribute --vpc-id $VPC_ID --attribute enableDnsHostnames --region us-east-1
aws ec2 describe-vpc-attribute --vpc-id $VPC_ID --attribute enableDnsSupport --region us-east-1
```

**Fix:**
```bash
aws ec2 modify-vpc-attribute --vpc-id $VPC_ID --enable-dns-hostnames
aws ec2 modify-vpc-attribute --vpc-id $VPC_ID --enable-dns-support
```

## Expected Timeline

| Action | Time |
|--------|------|
| Run `quick-fix-now.sh` | 2-3 min |
| Security group propagation | 10-30 sec |
| Terraform apply (targeted) | 5-10 min |
| Terraform apply (full) | 15-20 min |
| **Total** | **~25-35 min** |

## Success Indicators

You'll know it's fixed when:

```bash
$ kubectl cluster-info
Kubernetes control plane is running at https://...eks.amazonaws.com
CoreDNS is running at https://...eks.amazonaws.com/api/v1/namespaces/kube-system/services/kube-dns:dns/proxy

$ kubectl get nodes
NAME                         STATUS   ROLES    AGE
ip-172-31-x-x.ec2.internal   Ready    <none>   5m
```

## Still Not Working?

If `quick-fix-now.sh` fails:

1. **Check debug info:**
   ```bash
   cat sg-debug-info.txt
   ```

2. **Enable public endpoint:**
   ```bash
   aws eks update-cluster-config --name meracommerce-dev-cluster --region us-east-1 \
     --resources-vpc-config endpointPublicAccess=true
   ```

3. **Check network ACLs:**
   ```bash
   aws ec2 describe-network-acls --region us-east-1 \
     --filters "Name=vpc-id,Values=$(aws eks describe-cluster --name meracommerce-dev-cluster --region us-east-1 --query 'cluster.resourcesVpcConfig.vpcId' --output text)"
   ```

4. **Contact AWS Support** with the `sg-debug-info.txt` file

---

**Run this now:**
```bash
cd terraform
chmod +x quick-fix-now.sh
./quick-fix-now.sh
```
