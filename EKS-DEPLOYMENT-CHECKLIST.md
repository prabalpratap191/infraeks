# EKS Deployment Checklist

## Pre-Deployment Checklist

### ☐ 1. AWS Environment Verification

- [ ] AWS credentials configured and working
  ```bash
  aws sts get-caller-identity
  ```

- [ ] Correct AWS region selected (us-east-1)
  ```bash
  aws configure get region
  ```

- [ ] IAM permissions verified (EKS, EC2, VPC, IAM roles)
  - Required policies: `AmazonEKSClusterPolicy`, `AmazonEKSServicePolicy`, EC2 full access

### ☐ 2. Network Prerequisites

- [ ] Default VPC exists and is available
  ```bash
  aws ec2 describe-vpcs --filters Name=isDefault,Values=true --query 'Vpcs[0].VpcId'
  ```

- [ ] Subnets available in required AZs (us-east-1a, us-east-1b, us-east-1c)
  ```bash
  aws ec2 describe-subnets --filters "Name=availability-zone,Values=us-east-1a,us-east-1b,us-east-1c" \
    --query 'Subnets[].{AZ:AvailabilityZone,SubnetId:SubnetId,AvailableIPs:AvailableIpAddressCount}'
  ```

- [ ] Each subnet has at least 10+ available IP addresses

- [ ] Security groups allow required traffic (managed by Terraform, but verify if issues occur)

### ☐ 3. Capacity and Quotas

- [ ] Instance type (t3.medium) available in all target AZs
  ```bash
  ./scripts/verify-eks-prerequisites.sh
  ```

- [ ] AWS Service Quotas sufficient:
  - [ ] EC2 On-Demand instances: At least 5
  - [ ] EKS clusters: At least 1
  - [ ] VPC Elastic IPs: At least 2

### ☐ 4. Code and Configuration

- [ ] Latest code pulled from repository
  ```bash
  git pull origin mainbranch
  ```

- [ ] All fixes applied:
  - [ ] `terraform/modules/eks/main.tf` - cluster_version uses variable
  - [ ] `terraform/modules/eks/main.tf` - http_tokens = "optional"
  - [ ] `terraform/modules/eks/main.tf` - pre_bootstrap_user_data removed
  - [ ] `terraform/modules/eks/variables.tf` - default cluster_version = "1.31"

- [ ] Configuration files present:
  - [ ] `terraform/main.tf`
  - [ ] `terraform/variables.tf`
  - [ ] `terraform/meracommerce-dev.tfvars`
  - [ ] `terraform/modules/eks/main.tf`

### ☐ 5. Cleanup Previous Failed Attempts

- [ ] Clean up any failed node groups
  ```bash
  ./scripts/cleanup-aws-resources.sh
  ```

- [ ] Remove old Terraform state locks
  ```bash
  cd terraform
  rm -rf .terraform .terraform.lock.hcl
  ```

---

## Deployment Checklist

### ☐ 6. Terraform Initialization

- [ ] Navigate to terraform directory
  ```bash
  cd terraform
  ```

- [ ] Initialize Terraform
  ```bash
  terraform init
  ```

- [ ] Verify initialization successful (check for `.terraform` directory)

### ☐ 7. Terraform Validation

- [ ] Format Terraform files
  ```bash
  terraform fmt -recursive
  ```

- [ ] Validate configuration
  ```bash
  terraform validate
  ```

- [ ] No syntax errors in output

### ☐ 8. Terraform Plan Review

- [ ] Generate execution plan
  ```bash
  terraform plan \
    -var cluster_name=meracommerce-dev \
    -var namespace=customer-ns \
    -var service_account=customer-sa \
    -var-file=meracommerce-dev.tfvars
  ```

- [ ] Review plan output:
  - [ ] EKS cluster will be created/updated
  - [ ] Node group configuration looks correct
  - [ ] Instance type: t3.medium
  - [ ] Desired nodes: 2
  - [ ] AMI type: AL2023_x86_64_STANDARD
  - [ ] IMDSv2: optional (not required)

- [ ] No unexpected resource deletions

### ☐ 9. Terraform Apply

- [ ] Apply changes
  ```bash
  terraform apply -auto-approve \
    -var cluster_name=meracommerce-dev \
    -var namespace=customer-ns \
    -var service_account=customer-sa \
    -var-file=meracommerce-dev.tfvars
  ```

- [ ] Monitor apply progress (expect ~20 minutes)

---

## Monitoring Checklist

### ☐ 10. Cluster Creation Monitoring

- [ ] Monitor cluster status
  ```bash
  watch -n 10 'aws eks describe-cluster \
    --name meracommerce-dev \
    --query "cluster.{Status:status,Endpoint:endpoint,Version:version}"'
  ```

- [ ] Wait for status: `ACTIVE` (typically 10-12 minutes)

### ☐ 11. Node Group Monitoring

- [ ] Monitor node group creation
  ```bash
  watch -n 10 'aws eks describe-nodegroup \
    --cluster-name meracommerce-dev \
    --nodegroup-name meracommerce-dev-ng \
    --query "nodegroup.{Status:status,Health:health,Desired:scalingConfig.desiredSize,Current:scalingConfig.currentSize}"'
  ```

- [ ] Wait for:
  - Status: `ACTIVE`
  - Health: `HEALTHY`
  - Current == Desired (2 nodes)

- [ ] NO instances showing `NodeCreationFailure`

### ☐ 12. Node Join Verification

- [ ] Update kubeconfig
  ```bash
  aws eks update-kubeconfig --name meracommerce-dev --region us-east-1
  ```

- [ ] Verify nodes joined cluster
  ```bash
  kubectl get nodes
  ```

- [ ] Expected output: 2 nodes in `Ready` state
  ```
  NAME                          STATUS   ROLES    AGE   VERSION
  ip-xxx-xxx-xxx-xxx.ec2...     Ready    <none>   2m    v1.31.x
  ip-xxx-xxx-xxx-xxx.ec2...     Ready    <none>   2m    v1.31.x
  ```

---

## Post-Deployment Verification

### ☐ 13. Cluster Health Checks

- [ ] Check all nodes are ready
  ```bash
  kubectl get nodes
  ```

- [ ] Verify system pods running
  ```bash
  kubectl get pods -n kube-system
  ```

- [ ] Check CoreDNS pods (should be 2)
  ```bash
  kubectl get pods -n kube-system -l k8s-app=kube-dns
  ```

- [ ] Verify AWS Load Balancer Controller
  ```bash
  kubectl get deployment -n kube-system aws-load-balancer-controller
  ```

### ☐ 14. Namespace and RBAC Verification

- [ ] Check microservice namespaces created
  ```bash
  kubectl get namespaces | grep -E 'order-service-ns|catalog-service-ns|customer-service-ns'
  ```

- [ ] Verify service accounts
  ```bash
  kubectl get sa -n order-service-ns
  kubectl get sa -n catalog-service-ns
  kubectl get sa -n customer-service-ns
  ```

- [ ] Check IAM roles for service accounts (IRSA)
  ```bash
  kubectl describe sa order-sa -n order-service-ns
  kubectl describe sa catalog-sa -n catalog-service-ns
  kubectl describe sa customer-sa -n customer-service-ns
  ```

### ☐ 15. Network Policy Verification

- [ ] Verify network policies exist
  ```bash
  kubectl get networkpolicies -A
  ```

- [ ] Check resource quotas
  ```bash
  kubectl get resourcequota -A
  ```

- [ ] Check limit ranges
  ```bash
  kubectl get limitrange -A
  ```

### ☐ 16. CloudWatch and Logging

- [ ] Verify CloudWatch log groups created
  ```bash
  aws logs describe-log-groups --log-group-name-prefix /aws/eks/meracommerce-dev
  ```

- [ ] Check for error logs
  ```bash
  aws logs tail /aws/eks/meracommerce-dev/cluster --since 1h
  ```

### ☐ 17. Final Validation

- [ ] Run a test deployment
  ```bash
  kubectl run nginx --image=nginx -n order-service-ns
  kubectl get pods -n order-service-ns
  kubectl delete pod nginx -n order-service-ns
  ```

- [ ] Verify pod can access AWS services (if IRSA configured)

- [ ] Document cluster endpoint and configuration

---

## Rollback Plan (If Deployment Fails)

### ☐ Emergency Rollback

1. [ ] Stop ongoing deployment
   ```bash
   # Ctrl+C in terraform apply terminal
   ```

2. [ ] Destroy failed resources
   ```bash
   cd terraform
   terraform destroy -auto-approve \
     -var cluster_name=meracommerce-dev \
     -var namespace=customer-ns \
     -var service_account=customer-sa \
     -var-file=meracommerce-dev.tfvars
   ```

3. [ ] Clean up manually if terraform destroy fails
   ```bash
   ./scripts/cleanup-aws-resources.sh
   ```

4. [ ] Review logs and errors
   - [ ] Terraform output
   - [ ] CloudWatch logs
   - [ ] AWS Console events

5. [ ] Address issues based on:
   - [ ] `terraform/eks-troubleshooting-guide.md`
   - [ ] `QUICK-FIX-SUMMARY.md`

6. [ ] Retry deployment after fixes

---

## Troubleshooting Quick Reference

### Common Issues

| Issue | Check | Solution |
|-------|-------|----------|
| Nodes not joining | IMDSv2 settings | Verify `http_tokens = "optional"` in main.tf |
| Launch failures | Subnet IP availability | Ensure 10+ IPs available per subnet |
| Instance launch errors | Instance type availability | Try `t3a.medium` or `t3.small` |
| Permission errors | IAM policies | Verify EKS, EC2, VPC policies attached |
| Timeout errors | Region/AZ capacity | Check AWS service health dashboard |
| Bootstrap failures | User data scripts | Ensure no custom pre_bootstrap_user_data |

### Get Help

- **Detailed Guide**: [terraform/eks-troubleshooting-guide.md](terraform/eks-troubleshooting-guide.md)
- **Quick Fix**: [QUICK-FIX-SUMMARY.md](QUICK-FIX-SUMMARY.md)
- **Prerequisites**: Run `./scripts/verify-eks-prerequisites.sh`
- **AWS Support**: https://console.aws.amazon.com/support/

---

**Checklist Version**: 1.0  
**Last Updated**: 2026-08-25  
**Cluster**: meracommerce-dev  
**Region**: us-east-1
