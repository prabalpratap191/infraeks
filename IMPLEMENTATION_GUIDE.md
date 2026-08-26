# Multi-Microservices Deployment - Implementation Guide

## Overview

This guide provides step-by-step instructions to deploy multiple Java microservices (Order, Catalog, Customer) to your EKS cluster from separate CI/CD pipelines.

## Changes Made to Support Multi-Microservice Deployment

### ✅ New Terraform Modules Created

1. **`terraform/modules/microservices/`** - Comprehensive module for each microservice
   - Namespace creation with labels
   - Service Account with IRSA (IAM Roles for Service Accounts)
   - IAM Role and Policies for AWS resource access (S3, DynamoDB, SQS, Secrets Manager)
   - RBAC (Role/RoleBinding)
   - Network Policies for ingress/egress rules
   - Resource Quotas and Limit Ranges

2. **`terraform/modules/aws-load-balancer-controller/`** - ALB/NLB support
   - Installs AWS Load Balancer Controller via Helm
   - Configures IRSA for the controller
   - Sets up required IAM policies

### ✅ Updated Terraform Configuration

1. **`terraform/main.tf`**
   - Added Helm provider for Kubernetes addons
   - Instantiated AWS Load Balancer Controller
   - Created 3 microservice instances (order, catalog, customer)
   - Configured inter-service network policies

2. **`terraform/variables.tf`**
   - Added microservice-specific AWS resource access variables
   - Support for per-service S3, DynamoDB, SQS, Secrets Manager permissions

3. **`terraform/outputs.tf`**
   - Export namespace names, service accounts, IAM role ARNs
   - kubectl configuration command

4. **`terraform/provider.tf`**
   - Added Helm provider configuration

5. **`terraform/modules/eks/outputs.tf`**
   - Added OIDC provider outputs for IRSA

### ✅ Kubernetes Manifests Created

- **`k8s-manifests/order-service/deployment.yaml`**
- **`k8s-manifests/catalog-service/deployment.yaml`**
- **`k8s-manifests/customer-service/deployment.yaml`**
- **`k8s-manifests/ingress.yaml`** - Shared ALB ingress

Each includes:
- Deployment with health checks, resource limits
- ClusterIP Service
- ConfigMap for application config
- Secret placeholder

### ✅ CI/CD Pipeline Templates

- **`jenkins-pipelines/Jenkinsfile-order-service`**
- **`jenkins-pipelines/Jenkinsfile-catalog-service`**
- **`jenkins-pipelines/Jenkinsfile-customer-service`** (similar pattern)

---

## Prerequisites

### 1. AWS Resources
- ✅ EKS Cluster (already provisioned: `meracommerce-dev`)
- ✅ ECR Repositories for each service
- ⚠️ (Optional) ACM Certificate for HTTPS
- ⚠️ (Optional) Route53 hosted zone for DNS

### 2. Jenkins Setup
- Jenkins with AWS credentials configured (ID: `jenkins-user`)
- Jenkins plugins:
  - AWS Credentials Plugin
  - Kubernetes CLI Plugin
  - Docker Pipeline Plugin
  - Pipeline Plugin

### 3. Local Tools
- AWS CLI configured
- kubectl
- Terraform >= 1.0
- Docker

---

## Step-by-Step Implementation

### Phase 1: Infrastructure Setup (Terraform)

#### Step 1.1: Create ECR Repositories

```bash
# Create ECR repositories for microservices
aws ecr create-repository --repository-name order-service --region us-east-1
aws ecr create-repository --repository-name catalog-service --region us-east-1
aws ecr create-repository --repository-name customer-service --region us-east-1

# Get repository URIs
aws ecr describe-repositories --region us-east-1 --query 'repositories[].repositoryUri'
```

#### Step 1.2: Update tfvars (Optional - if services need AWS resource access)

Edit `terraform/meracommerce-dev.tfvars`:

```hcl
# Existing variables
cluster_name        = "meracommerce-dev"
region              = "us-east-1"
availability_zones  = ["us-east-1a", "us-east-1b", "us-east-1c"]
namespace           = "customer-ns"  # Legacy - not used
service_account     = "customer-sa"  # Legacy - not used
cluster_version     = "1.31"
node_instance_type  = "t3.medium"
node_desired        = 2
node_min            = 1
node_max            = 3
environment         = "dev"

# Order Service AWS Resources (add if needed)
order_service_s3_buckets       = ["my-orders-bucket"]
order_service_dynamodb_tables  = ["orders-table"]
order_service_sqs_queues       = ["order-queue"]
order_service_secrets          = ["arn:aws:secretsmanager:us-east-1:ACCOUNT:secret:order-db-password"]

# Catalog Service AWS Resources
catalog_service_s3_buckets     = ["catalog-images-bucket"]
catalog_service_dynamodb_tables = ["products-table"]

# Customer Service AWS Resources
customer_service_dynamodb_tables = ["customers-table"]
```

#### Step 1.3: Initialize and Apply Terraform

```bash
cd terraform

# Clean previous state
rm -rf .terraform .terraform.lock.hcl

# Initialize
terraform init

# Validate
terraform validate

# Plan
terraform plan \
  -var cluster_name=meracommerce-dev \
  -var namespace=customer-ns \
  -var service_account=customer-sa \
  -var-file=meracommerce-dev.tfvars

# Apply (this will create namespaces, service accounts, IRSA roles, and install ALB controller)
terraform apply \
  -var cluster_name=meracommerce-dev \
  -var namespace=customer-ns \
  -var service_account=customer-sa \
  -var-file=meracommerce-dev.tfvars \
  -auto-approve
```

#### Step 1.4: Verify Infrastructure

```bash
# Update kubeconfig
aws eks update-kubeconfig --name meracommerce-dev --region us-east-1

# Check namespaces
kubectl get namespaces | grep -E "order|catalog|customer"

# Expected output:
order-service-ns      Active   1m
catalog-service-ns    Active   1m
customer-service-ns   Active   1m

# Check service accounts
kubectl get sa -n order-service-ns
kubectl get sa -n catalog-service-ns
kubectl get sa -n customer-service-ns

# Check AWS Load Balancer Controller
kubectl get deployment -n kube-system aws-load-balancer-controller

# Get Terraform outputs
terraform output
```

**Expected Terraform Outputs:**
```
cluster_name = "meracommerce-dev"
order_service_namespace = "order-service-ns"
order_service_sa = "order-sa"
order_service_irsa_role_arn = "arn:aws:iam::ACCOUNT:role/meracommerce-dev-order-service-irsa"
catalog_service_namespace = "catalog-service-ns"
...
configure_kubectl = "aws eks update-kubeconfig --region us-east-1 --name meracommerce-dev"
```

---

### Phase 2: Application Deployment

#### Step 2.1: Prepare Microservice Code

For each microservice repository:

1. **Add Dockerfile** (example for Spring Boot):

```dockerfile
FROM eclipse-temurin:17-jre-alpine
WORKDIR /app
COPY target/*.jar app.jar
EXPOSE 8080
ENTRYPOINT ["java", "-jar", "app.jar"]
```

2. **Update `application.yml`** to use environment variables:

```yaml
spring:
  application:
    name: ${APPLICATION_NAME:order-service}
  profiles:
    active: ${SPRING_PROFILES_ACTIVE:prod}

server:
  port: ${SERVER_PORT:8080}

management:
  endpoints:
    web:
      exposure:
        include: health,info,metrics
  endpoint:
    health:
      probes:
        enabled: true
      show-details: always
```

3. **Copy Kubernetes manifests** to your service repo:

```bash
# In order-service repository
mkdir -p k8s
cp /path/to/infraeks/k8s-manifests/order-service/deployment.yaml k8s/

# In catalog-service repository
mkdir -p k8s
cp /path/to/infraeks/k8s-manifests/catalog-service/deployment.yaml k8s/
```

4. **Copy Jenkinsfile**:

```bash
# In order-service repository
cp /path/to/infraeks/jenkins-pipelines/Jenkinsfile-order-service Jenkinsfile

# In catalog-service repository
cp /path/to/infraeks/jenkins-pipelines/Jenkinsfile-catalog-service Jenkinsfile
```

#### Step 2.2: Setup Jenkins Jobs

For each microservice:

1. **Create new Pipeline job** in Jenkins
   - Name: `order-service-deployment`
   - Type: Pipeline
   - Pipeline definition: Pipeline script from SCM
   - SCM: Git
   - Repository URL: Your service Git URL
   - Script Path: `Jenkinsfile`

2. **Configure AWS Account ID**
   - In Jenkinsfile, set `AWS_ACCOUNT_ID` environment variable
   - Or configure in Jenkins global properties

#### Step 2.3: Deploy Order Service

1. **Trigger Jenkins job** for `order-service-deployment`
2. **Monitor deployment**:

```bash
# Watch deployment
kubectl get pods -n order-service-ns -w

# Check logs
kubectl logs -f deployment/order-service -n order-service-ns

# Verify service
kubectl get svc -n order-service-ns
```

#### Step 2.4: Deploy Catalog Service

Repeat Step 2.3 for catalog service.

#### Step 2.5: Deploy Customer Service

Repeat Step 2.3 for customer service.

---

### Phase 3: Ingress Configuration

#### Step 3.1: Update Ingress with Your Domain

Edit `k8s-manifests/ingress.yaml`:

```yaml
spec:
  rules:
  - host: api.yourdomain.com  # Replace with your actual domain
```

#### Step 3.2: Apply Ingress

```bash
kubectl apply -f k8s-manifests/ingress.yaml
```

#### Step 3.3: Get Load Balancer DNS

```bash
# Get ALB DNS name
kubectl get ingress microservices-ingress -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'

# Output example:
k8s-default-microser-abc123-1234567890.us-east-1.elb.amazonaws.com
```

#### Step 3.4: Configure DNS (Route53)

1. Go to Route53
2. Create CNAME record:
   - Name: `api.yourdomain.com`
   - Type: CNAME
   - Value: ALB DNS from Step 3.3

#### Step 3.5: Test Endpoints

```bash
# Test order service
curl http://api.yourdomain.com/api/orders/health

# Test catalog service
curl http://api.yourdomain.com/api/catalog/health

# Test customer service
curl http://api.yourdomain.com/api/customers/health
```

---

### Phase 4: Verification & Testing

#### Step 4.1: Check All Resources

```bash
# All namespaces
kubectl get ns | grep -E "order|catalog|customer"

# All pods
kubectl get pods --all-namespaces | grep -E "order|catalog|customer"

# All services
kubectl get svc --all-namespaces | grep -E "order|catalog|customer"

# Network policies
kubectl get networkpolicy -n order-service-ns
kubectl get networkpolicy -n catalog-service-ns
kubectl get networkpolicy -n customer-service-ns

# Resource quotas
kubectl get resourcequota -n order-service-ns
```

#### Step 4.2: Test Inter-Service Communication

```bash
# From order-service pod, test catalog-service connectivity
kubectl exec -n order-service-ns deployment/order-service -- \
  curl -s http://catalog-service.catalog-service-ns.svc.cluster.local:8080/actuator/health

# Expected: {"status":"UP"}
```

#### Step 4.3: Check IAM Roles

```bash
# Get service account annotations
kubectl get sa order-sa -n order-service-ns -o yaml | grep eks.amazonaws.com/role-arn

# Verify IAM role exists
aws iam get-role --role-name meracommerce-dev-order-service-irsa
```

---

## Network Policy Details

### Order Service Network Policy

**Ingress:**
- ✅ From `ingress-nginx` namespace on port 8080

**Egress:**
- ✅ To `kube-system` namespace (DNS) on UDP port 53
- ✅ To `catalog-service-ns` on TCP port 8080
- ✅ To `customer-service-ns` on TCP port 8080
- ✅ To internet (AWS services) on TCP port 443

### Catalog Service Network Policy

**Ingress:**
- ✅ From `ingress-nginx` namespace on port 8080
- ✅ From `order-service-ns` on TCP port 8080

**Egress:**
- ✅ To `kube-system` namespace (DNS)
- ✅ To internet (AWS services)

### Customer Service Network Policy

Similar to Catalog Service.

---

## Troubleshooting

### Issue: Pods not starting

```bash
# Check pod events
kubectl describe pod <pod-name> -n <namespace>

# Check logs
kubectl logs <pod-name> -n <namespace>

# Common issues:
# 1. Image pull errors - check ECR permissions
# 2. ConfigMap/Secret not found - create them first
# 3. Resource limits - adjust in deployment.yaml
```

### Issue: Service not accessible

```bash
# Check service endpoints
kubectl get endpoints <service-name> -n <namespace>

# Test from another pod
kubectl run curl-test --image=curlimages/curl --rm -it -- \
  curl http://<service-name>.<namespace>.svc.cluster.local:8080/actuator/health
```

### Issue: ALB not created

```bash
# Check ALB controller logs
kubectl logs -n kube-system deployment/aws-load-balancer-controller

# Check ingress status
kubectl describe ingress microservices-ingress

# Common issues:
# 1. IAM permissions - check controller IAM role
# 2. Subnet tags - ensure subnets have proper tags
# 3. Security groups - check VPC security groups
```

### Issue: Network policy blocking traffic

```bash
# Temporarily disable network policy
kubectl delete networkpolicy <policy-name> -n <namespace>

# Test connectivity
# Then re-enable and adjust rules
```

---

## Next Steps & Enhancements

### Security
- [x] Enable SSL/TLS (add ACM certificate to ingress)
- [x] Implement External Secrets Operator for secret management
- [x] Add WAF rules to ALB
- [x] Enable Pod Security Standards

### Monitoring
- [ ] Install Prometheus & Grafana
- [ ] Configure CloudWatch Container Insights
- [ ] Setup alerts for pod failures
- [ ] Add custom metrics

### Scaling
- [ ] Configure Horizontal Pod Autoscaler (HPA)
- [ ] Install Cluster Autoscaler
- [ ] Add PodDisruptionBudgets

### CI/CD
- [ ] Implement blue-green deployments
- [ ] Add canary deployments
- [ ] Setup ArgoCD for GitOps
- [ ] Add automated rollback

---

## Summary

✅ **What You Now Have:**

1. **Single EKS Cluster** running 3 isolated microservices
2. **Separate Namespaces** for each service with network isolation
3. **IRSA** for secure AWS resource access per service
4. **AWS Load Balancer** for external traffic routing
5. **Network Policies** controlling inter-service communication
6. **Resource Quotas** preventing resource exhaustion
7. **CI/CD Pipelines** for independent deployments

✅ **Each Microservice Has:**
- Dedicated namespace
- Service account with IAM role
- Network policies (ingress/egress)
- Resource limits
- Health checks
- Independent deployment pipeline

**You can now deploy each microservice independently from its own CI/CD pipeline!**

---

**Questions or Issues?** Refer to:
- [MICROSERVICES_DEPLOYMENT_ARCHITECTURE.md](MICROSERVICES_DEPLOYMENT_ARCHITECTURE.md)
- [EKS_NODE_GROUP_TROUBLESHOOTING.md](EKS_NODE_GROUP_TROUBLESHOOTING.md)
