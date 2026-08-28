# InfraEKS - Multi-Microservices Infrastructure on AWS EKS

[![Terraform](https://img.shields.io/badge/Terraform-%3E%3D1.0-623CE4?logo=terraform)](https://www.terraform.io/)
[![Kubernetes](https://img.shields.io/badge/Kubernetes-1.31-326CE5?logo=kubernetes)](https://kubernetes.io/)
[![AWS EKS](https://img.shields.io/badge/AWS-EKS-FF9900?logo=amazon-aws)](https://aws.amazon.com/eks/)
[![License](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)

## 📋 Overview

InfraEKS is a production-ready Infrastructure-as-Code (IaC) solution for deploying and managing multiple Java microservices on AWS Elastic Kubernetes Service (EKS). This project provides a complete, secure, and scalable infrastructure with isolated namespaces, IAM Roles for Service Accounts (IRSA), network policies, and AWS Load Balancer integration.

### Key Highlights

- **Single EKS Cluster** with multi-tenant microservices architecture
- **3 Pre-configured Microservices**: Order, Catalog, and Customer services
- **Complete Isolation**: Separate namespaces with network policies
- **Secure AWS Access**: IRSA for fine-grained IAM permissions
- **Production-Ready**: Health checks, resource quotas, and auto-scaling support
- **CI/CD Ready**: Independent deployment pipelines for each service

---

## 🏗️ Architecture

### High-Level Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                        Internet / Users                          │
└──────────────────────────┬──────────────────────────────────────┘
                           │ HTTPS
                           ▼
              ┌────────────────────────────┐
              │  Application Load Balancer  │
              │    (AWS ALB Controller)     │
              └────────────┬───────────────┘
                           │
              ┌────────────┴────────────┐
              │    Ingress Controller    │
              │   (Path-based Routing)   │
              └────────────┬────────────┘
                           │
        ┌──────────────────┼──────────────────┐
        │                  │                  │
        ▼                  ▼                  ▼
  ┌─────────────┐   ┌─────────────┐   ┌─────────────┐
  │   Order     │   │  Catalog    │   │  Customer   │
  │  Service    │   │  Service    │   │  Service    │
  │    NS       │   │    NS       │   │    NS       │
  ├─────────────┤   ├─────────────┤   ├─────────────┤
  │ • 2 Pods    │   │ • 2 Pods    │   │ • 2 Pods    │
  │ • IRSA      │   │ • IRSA      │   │ • IRSA      │
  │ • NetworkPol│   │ • NetworkPol│   │ • NetworkPol│
  └──────┬──────┘   └──────┬──────┘   └──────┬──────┘
         │                 │                  │
         └─────────────────┴──────────────────┘
                           │
                           ▼
              ┌────────────────────────────┐
              │   AWS Services (via IRSA)  │
              │  • S3  • DynamoDB  • SQS   │
              │  • Secrets Manager         │
              └────────────────────────────┘
```

### Cluster Details

| Component | Configuration |
|-----------|---------------|
| **Cluster Name** | meracommerce-dev-cluster |
| **Region** | us-east-1 |
| **Kubernetes Version** | 1.31 |
| **Node Type** | t3.medium |
| **Node Count** | 2 (min: 1, max: 3) |
| **Availability Zones** | us-east-1a, us-east-1b, us-east-1c |
| **Network Plugin** | Amazon VPC CNI |

### Microservices Configuration

| Service | Namespace | Service Account | Port | Ingress Path | Replicas |
|---------|-----------|----------------|------|--------------|----------|
| **Order Service** | order-service-ns | order-sa | 8080 | /api/orders | 2 |
| **Catalog Service** | catalog-service-ns | catalog-sa | 8080 | /api/catalog, /api/products | 2 |
| **Customer Service** | customer-service-ns | customer-sa | 8080 | /api/customers, /api/users | 2 |

---

## ✨ Features

### 🔒 Security

- ✅ **IRSA (IAM Roles for Service Accounts)** - Fine-grained AWS permissions per service
- ✅ **Network Policies** - Traffic isolation between microservices
- ✅ **RBAC** - Role-Based Access Control with least privilege
- ✅ **IMDSv2** - Enhanced EC2 metadata security
- ✅ **EBS Encryption** - Encrypted storage volumes
- ✅ **Private Node Groups** - Nodes in private subnets

### 📈 Scalability

- ✅ **Resource Quotas** - Per-namespace resource limits
- ✅ **Limit Ranges** - Container-level constraints
- ✅ **HPA Ready** - Health probes for Horizontal Pod Autoscaling
- ✅ **Cluster Autoscaler Compatible** - Auto-scaling node groups

### 🌐 Networking

- ✅ **AWS Load Balancer Controller** - Native ALB/NLB integration
- ✅ **Path-based Routing** - Ingress with intelligent routing
- ✅ **Service Mesh Ready** - Compatible with Istio/Linkerd
- ✅ **Network Isolation** - Controlled inter-service communication

### 🚀 CI/CD

- ✅ **Independent Pipelines** - Separate deployment for each service
- ✅ **Automated Health Checks** - Liveness and readiness probes
- ✅ **Rollback on Failure** - Automatic deployment rollback
- ✅ **ECR Integration** - Private Docker registry

---

## 📁 Project Structure

```
infraeKS-master/
├── terraform/                              # Terraform IaC configuration
│   ├── modules/
│   │   ├── eks/                            # EKS cluster module
│   │   │   ├── main.tf
│   │   │   ├── outputs.tf
│   │   │   └── variables.tf
│   │   ├── microservices/                  # Microservice resources module
│   │   │   ├── main.tf                     # Namespace, SA, IRSA, RBAC
│   │   │   ├── outputs.tf
│   │   │   └── variables.tf
│   │   ├── aws-load-balancer-controller/   # ALB controller module
│   │   │   ├── main.tf
│   │   │   ├── outputs.tf
│   │   │   └── variables.tf
│   │   ├── irsa/                           # Legacy IRSA module
│   │   ├── namespace/                      # Legacy namespace module
│   │   └── service-account/                # Legacy SA module
│   ├── main.tf                             # Root Terraform config
│   ├── variables.tf                        # Input variables
│   ├── outputs.tf                          # Output values
│   ├── provider.tf                         # Provider configuration
│   ├── meracommerce-dev-cluster.tfvars            # Development environment vars
│   └── backend/
│       └── backend.tf                      # Remote state configuration
├── k8s-manifests/                          # Kubernetes manifests
│   ├── order-service/
│   │   └── deployment.yaml                 # Order service K8s resources
│   ├── catalog-service/
│   │   └── deployment.yaml                 # Catalog service K8s resources
│   ├── customer-service/
│   │   └── deployment.yaml                 # Customer service K8s resources
│   └── ingress.yaml                        # Shared ALB ingress
├── jenkins-pipelines/                      # CI/CD pipeline definitions
│   ├── Jenkinsfile-order-service
│   ├── Jenkinsfile-catalog-service
│   └── Jenkinsfile (similar for customer)
├── scripts/                                # Utility scripts
│   ├── kubeconfig.sh                       # Configure kubectl
│   └── verify.sh                           # Verification script
├── Jenkinsfile                             # Infrastructure deployment pipeline
└── docs/                                   # Documentation
    ├── IMPLEMENTATION_GUIDE.md
    ├── MICROSERVICES_DEPLOYMENT_ARCHITECTURE.md
    ├── EKS_NODE_GROUP_TROUBLESHOOTING.md
    ├── DEPLOYMENT_CHECKLIST.md
    ├── CHANGES_SUMMARY.md
    ├── GIT_SETUP_GUIDE.md
    └── architecture-diagram.md
```

---

## 🚀 Quick Start

### Prerequisites

Ensure you have the following tools installed and configured:

#### Required Tools

| Tool | Version | Installation |
|------|---------|-------------|
| **AWS CLI** | >= 2.0 | [Install Guide](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html) |
| **Terraform** | >= 1.0 | [Install Guide](https://learn.hashicorp.com/tutorials/terraform/install-cli) |
| **kubectl** | >= 1.28 | [Install Guide](https://kubernetes.io/docs/tasks/tools/) |
| **Jenkins** | Latest | [Install Guide](https://www.jenkins.io/doc/book/installing/) |

#### AWS Permissions Required

- EKS cluster creation and management
- IAM role and policy creation
- VPC and networking configuration
- EC2 instance management
- ECR repository access

### Step 1: Configure AWS Credentials

```bash
# Configure AWS CLI with your credentials
aws configure

# Verify access
aws sts get-caller-identity
```

### Step 2: Create ECR Repositories

```bash
# Create ECR repositories for each microservice
aws ecr create-repository --repository-name order-service --region us-east-1
aws ecr create-repository --repository-name catalog-service --region us-east-1
aws ecr create-repository --repository-name customer-service --region us-east-1

# Retrieve repository URIs
aws ecr describe-repositories --region us-east-1 \
  --query 'repositories[].repositoryUri' --output table
```

### Step 3: Deploy Infrastructure with Terraform

```bash
# Clone the repository
git clone https://github.com/prabalpratap191/infraeks.git
cd infraeks/terraform

# Initialize Terraform
terraform init

# Validate configuration
terraform validate

# Review execution plan
terraform plan -var-file=meracommerce-dev-cluster.tfvars

# Apply infrastructure
terraform apply -var-file=meracommerce-dev-cluster.tfvars -auto-approve
```

**Expected deployment time: 15-20 minutes**

### Step 4: Configure kubectl

```bash
# Update kubeconfig to access the cluster
aws eks update-kubeconfig --name meracommerce-dev-cluster --region us-east-1

# Verify cluster access
kubectl cluster-info
kubectl get nodes
```

### Step 5: Verify Infrastructure

```bash
# Check namespaces
kubectl get namespaces | grep -E "order|catalog|customer"

# Expected output:
order-service-ns      Active   1m
catalog-service-ns    Active   1m
customer-service-ns   Active   1m

# Verify service accounts
kubectl get sa -n order-service-ns
kubectl get sa -n catalog-service-ns
kubectl get sa -n customer-service-ns

# Check AWS Load Balancer Controller
kubectl get deployment -n kube-system aws-load-balancer-controller

# View Terraform outputs
cd terraform
terraform output
```

### Step 6: Deploy Microservices

#### Option A: Using Jenkins (Recommended)

1. **Configure Jenkins credentials**:
   - Add AWS credentials with ID: `jenkins-user`
   - Add GitHub token with ID: `github-token`

2. **Create Jenkins pipeline jobs**:
   - `order-service-deployment`
   - `catalog-service-deployment`
   - `customer-service-deployment`

3. **Trigger deployments** from Jenkins UI

#### Option B: Manual Deployment

```bash
# Apply Kubernetes manifests
kubectl apply -f k8s-manifests/order-service/deployment.yaml
kubectl apply -f k8s-manifests/catalog-service/deployment.yaml
kubectl apply -f k8s-manifests/customer-service/deployment.yaml

# Apply shared ingress
kubectl apply -f k8s-manifests/ingress.yaml

# Verify deployments
kubectl get pods --all-namespaces | grep -E "order|catalog|customer"
```

### Step 7: Access Your Services

```bash
# Get Load Balancer DNS name
kubectl get ingress microservices-ingress \
  -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'

# Test endpoints (replace with your ALB DNS)
curl http://<ALB-DNS>/api/orders/health
curl http://<ALB-DNS>/api/catalog/health
curl http://<ALB-DNS>/api/customers/health
```

---

## 📚 Detailed Documentation

For comprehensive guides and detailed information, refer to:

### 🚀 Getting Started
| Document | Description |
|----------|-------------|
| **[QUICK_START.md](QUICK_START.md)** | ⚡ Deploy in ~30 minutes - Fast track guide |
| **[IMPLEMENTATION_GUIDE.md](IMPLEMENTATION_GUIDE.md)** | Complete step-by-step deployment guide |
| **[DEPLOYMENT_CHECKLIST.md](DEPLOYMENT_CHECKLIST.md)** | Pre-deployment verification checklist |

### 🏗️ Architecture & Design
| Document | Description |
|----------|-------------|
| **[architecture-diagram.md](architecture-diagram.md)** | Visual architecture diagrams (Mermaid) |
| **[MICROSERVICES_DEPLOYMENT_ARCHITECTURE.md](MICROSERVICES_DEPLOYMENT_ARCHITECTURE.md)** | Detailed architecture and design decisions |

### 🔧 Troubleshooting & Fixes
| Document | Description |
|----------|-------------|
| **[COMMON_ERRORS_QUICK_FIX.md](COMMON_ERRORS_QUICK_FIX.md)** | 🔥 Quick fixes for 10+ common errors |
| **[RESOURCE_ALREADY_EXISTS_FIX.md](RESOURCE_ALREADY_EXISTS_FIX.md)** | Fix for KMS/CloudWatch resources already exist |
| **[EKS_NODE_GROUP_TROUBLESHOOTING.md](EKS_NODE_GROUP_TROUBLESHOOTING.md)** | Node group issues and solutions |
| **[IAM_ROLE_NAME_LENGTH_FIX.md](IAM_ROLE_NAME_LENGTH_FIX.md)** | Fix for IAM role name length errors |
| **[BEFORE_AFTER_COMPARISON.md](BEFORE_AFTER_COMPARISON.md)** | Visual comparison of IAM fix changes |

### 📋 Project Management
| Document | Description |
|----------|-------------|
| **[DEPLOYMENT_SUCCESS_SUMMARY.md](DEPLOYMENT_SUCCESS_SUMMARY.md)** | Overview of fixes and deployment status |
| **[CHANGES_SUMMARY.md](CHANGES_SUMMARY.md)** | Change log and migration guide |
| **[GIT_SETUP_GUIDE.md](GIT_SETUP_GUIDE.md)** | Git repository setup instructions |

---

## 🔧 Configuration

### Environment Variables (tfvars)

Edit `terraform/meracommerce-dev-cluster.tfvars` to customize your deployment:

```hcl
# Cluster Configuration
cluster_name        = "meracommerce-dev-cluster"
region              = "us-east-1"
availability_zones  = ["us-east-1a", "us-east-1b", "us-east-1c"]
cluster_version     = "1.31"
environment         = "dev"

# Node Group Configuration
node_instance_type  = "t3.medium"
node_desired        = 2
node_min            = 1
node_max            = 3

# Order Service AWS Resources
order_service_s3_buckets       = ["my-orders-bucket"]
order_service_dynamodb_tables  = ["orders-table"]
order_service_sqs_queues       = ["order-queue"]
order_service_secrets          = []

# Catalog Service AWS Resources
catalog_service_s3_buckets     = ["catalog-images-bucket"]
catalog_service_dynamodb_tables = ["products-table"]
catalog_service_sqs_queues     = []
catalog_service_secrets        = []

# Customer Service AWS Resources
customer_service_s3_buckets    = []
customer_service_dynamodb_tables = ["customers-table"]
customer_service_sqs_queues    = []
customer_service_secrets       = ["arn:aws:secretsmanager:us-east-1:ACCOUNT:secret:customer-db"]
```

### Network Policies

Network policies are automatically configured with the following rules:

#### Order Service
- **Ingress**: Allows traffic from ingress controller on port 8080
- **Egress**: 
  - To Catalog Service (port 8080)
  - To Customer Service (port 8080)
  - To kube-system for DNS (UDP 53)
  - To internet for AWS APIs (HTTPS 443)

#### Catalog Service
- **Ingress**: 
  - From ingress controller (port 8080)
  - From Order Service (port 8080)
- **Egress**: DNS and AWS APIs

#### Customer Service
- **Ingress**: 
  - From ingress controller (port 8080)
  - From Order Service (port 8080)
- **Egress**: DNS and AWS APIs

---

## 🛠️ Maintenance & Operations

### Scaling Operations

#### Scale Node Group

```bash
# Update desired capacity
cd terraform
terraform apply \
  -var node_desired=3 \
  -var node_max=5 \
  -var-file=meracommerce-dev-cluster.tfvars
```

#### Scale Microservice Pods

```bash
# Scale order service to 3 replicas
kubectl scale deployment order-service -n order-service-ns --replicas=3

# Verify scaling
kubectl get pods -n order-service-ns
```

### Update Kubernetes Version

```bash
cd terraform
terraform apply -var cluster_version="1.32" -var-file=meracommerce-dev-cluster.tfvars
```

### Add New Microservice

1. **Add Terraform module** in `terraform/main.tf`:

```hcl
module "payment_service" {
  source = "./modules/microservices"
  
  cluster_name         = var.cluster_name
  service_name         = "payment-service"
  namespace            = "payment-service-ns"
  service_account_name = "payment-sa"
  environment          = var.environment
  oidc_provider        = replace(module.eks.cluster_oidc_issuer_url, "https://", "")
  aws_region           = var.region
  
  # AWS resource access
  s3_buckets            = var.payment_service_s3_buckets
  dynamodb_tables       = var.payment_service_dynamodb_tables
  
  # Network policies
  enable_network_policy = true
  ingress_rules = [
    {
      namespace_labels = { name = "ingress-nginx" }
      protocol         = "TCP"
      port             = 8080
    }
  ]
  
  enable_resource_quota = true
  enable_limit_range    = true
  
  depends_on = [module.eks]
}
```

2. **Create Kubernetes manifests** in `k8s-manifests/payment-service/deployment.yaml`

3. **Create Jenkins pipeline** in `jenkins-pipelines/Jenkinsfile-payment-service`

4. **Apply changes**:

```bash
terraform apply -var-file=meracommerce-dev-cluster.tfvars
```

---

## 🐛 Troubleshooting

### Common Issues

#### Pods Not Starting

```bash
# Check pod status and events
kubectl describe pod <pod-name> -n <namespace>

# Check logs
kubectl logs <pod-name> -n <namespace>

# Common causes:
# - Image pull errors: Check ECR permissions
# - Resource limits: Adjust in deployment.yaml
# - ConfigMap/Secret missing: Create required resources
```

#### Service Not Accessible

```bash
# Check service endpoints
kubectl get endpoints <service-name> -n <namespace>

# Test service connectivity from a test pod
kubectl run curl-test --image=curlimages/curl --rm -it -- \
  curl http://<service-name>.<namespace>.svc.cluster.local:8080/actuator/health
```

#### ALB Not Created

```bash
# Check ALB controller logs
kubectl logs -n kube-system deployment/aws-load-balancer-controller

# Verify ingress status
kubectl describe ingress microservices-ingress

# Common issues:
# - IAM permissions: Check controller IAM role
# - Subnet tags: Ensure proper kubernetes.io tags on subnets
# - Security groups: Verify VPC security groups allow traffic
```

#### Network Policy Blocking Traffic

```bash
# Temporarily disable network policy for testing
kubectl delete networkpolicy <policy-name> -n <namespace>

# Test connectivity
# Re-enable and adjust rules as needed
```

#### IRSA Not Working

```bash
# Verify service account annotation
kubectl get sa <service-account> -n <namespace> -o yaml | grep eks.amazonaws.com/role-arn

# Check IAM role trust policy
aws iam get-role --role-name <irsa-role-name>

# Verify OIDC provider
aws iam list-open-id-connect-providers
```

For detailed troubleshooting guides, see:
- [IMPLEMENTATION_GUIDE.md - Troubleshooting Section](IMPLEMENTATION_GUIDE.md#troubleshooting)
- [EKS_NODE_GROUP_TROUBLESHOOTING.md](EKS_NODE_GROUP_TROUBLESHOOTING.md)

---

## 🧪 Testing

### Health Check Endpoints

```bash
# Get ALB DNS
ALB_DNS=$(kubectl get ingress microservices-ingress -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')

# Test all health endpoints
curl http://$ALB_DNS/api/orders/actuator/health
curl http://$ALB_DNS/api/catalog/actuator/health
curl http://$ALB_DNS/api/customers/actuator/health
```

### Inter-Service Communication

```bash
# Test from order-service to catalog-service
kubectl exec -n order-service-ns deployment/order-service -- \
  curl -s http://catalog-service.catalog-service-ns.svc.cluster.local:8080/actuator/health

# Expected output: {"status":"UP"}
```

### Load Testing

```bash
# Install Apache Bench (if not installed)
sudo apt-get install apache2-utils

# Simple load test (1000 requests, 10 concurrent)
ab -n 1000 -c 10 http://$ALB_DNS/api/catalog/actuator/health
```

---

## 🔐 Security Best Practices

### Implemented Security Measures

1. **IRSA (IAM Roles for Service Accounts)**
   - Each microservice has its own IAM role
   - Fine-grained permissions per service
   - No AWS credentials stored in pods

2. **Network Policies**
   - Default deny-all traffic
   - Explicit allow rules for required communication
   - Namespace isolation

3. **Resource Limits**
   - CPU and memory limits per pod
   - Namespace-level resource quotas
   - Prevention of resource exhaustion

4. **RBAC**
   - Least privilege access
   - Role-based permissions per namespace
   - Service account bindings

### Recommended Additional Security

- [ ] Enable AWS Secrets Manager or External Secrets Operator
- [ ] Implement Pod Security Standards (PSS)
- [ ] Add AWS WAF rules to ALB
- [ ] Enable VPC Flow Logs
- [ ] Implement AWS GuardDuty
- [ ] Use AWS Certificate Manager for HTTPS
- [ ] Enable audit logging
- [ ] Implement container image scanning

---

## 📊 Monitoring & Observability

### Recommended Monitoring Stack

1. **Metrics**: Prometheus + Grafana
2. **Logs**: AWS CloudWatch Container Insights
3. **Tracing**: AWS X-Ray or Jaeger
4. **Alerts**: CloudWatch Alarms + SNS

### Quick Setup for CloudWatch Container Insights

```bash
# Install CloudWatch agent
curl https://raw.githubusercontent.com/aws-samples/amazon-cloudwatch-container-insights/latest/k8s-deployment-manifest-templates/deployment-mode/daemonset/container-insights-monitoring/quickstart/cwagent-fluentd-quickstart.yaml | sed "s/{{cluster_name}}/meracommerce-dev-cluster/;s/{{region_name}}/us-east-1/" | kubectl apply -f -

# Verify installation
kubectl get pods -n amazon-cloudwatch
```

### Key Metrics to Monitor

- Pod CPU and memory usage
- Node resource utilization
- Application error rates
- Request latency (p50, p95, p99)
- AWS service API errors
- Load balancer request count

---

## 🚀 CI/CD Pipeline

### Jenkins Pipeline Stages

Each microservice pipeline includes:

1. **Checkout**: Clone source code
2. **Build**: Maven/Gradle build
3. **Test**: Run unit tests
4. **Docker Build**: Create container image
5. **Push to ECR**: Upload image to ECR
6. **Deploy to EKS**: Apply Kubernetes manifests
7. **Health Check**: Verify deployment
8. **Rollback**: Automatic rollback on failure

### Pipeline Environment Variables

```groovy
environment {
    AWS_REGION = 'us-east-1'
    ECR_REGISTRY = '<account-id>.dkr.ecr.us-east-1.amazonaws.com'
    IMAGE_NAME = 'order-service'
    CLUSTER_NAME = 'meracommerce-dev-cluster'
    NAMESPACE = 'order-service-ns'
}
```

### Example Jenkins Credentials

- `jenkins-user`: AWS credentials (Access Key ID + Secret)
- `github-token`: GitHub personal access token

---

## 🎯 Roadmap & Future Enhancements

### Planned Features

- [ ] **GitOps**: Implement ArgoCD for declarative deployments
- [ ] **Service Mesh**: Add Istio for advanced traffic management
- [ ] **Auto-scaling**: Configure HPA and Cluster Autoscaler
- [ ] **Blue-Green Deployments**: Implement zero-downtime releases
- [ ] **Canary Deployments**: Gradual traffic shifting
- [ ] **Disaster Recovery**: Multi-region setup
- [ ] **Cost Optimization**: Spot instances for non-critical workloads
- [ ] **Observability**: Full Prometheus + Grafana stack
- [ ] **Secrets Management**: External Secrets Operator
- [ ] **Policy Enforcement**: OPA/Gatekeeper for policy as code

---

## 🤝 Contributing

Contributions are welcome! Please follow these guidelines:

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

### Development Guidelines

- Follow Terraform best practices
- Use semantic commit messages
- Update documentation for any changes
- Test changes in a development environment first
- Ensure backward compatibility

---

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

---

## 👥 Authors & Contributors

- **Infrastructure Team** - Initial architecture and Terraform modules
- **DevOps Team** - CI/CD pipelines and automation
- **Prabal Pratap** - Project maintainer

---

## 🙏 Acknowledgments

- AWS EKS team for excellent documentation
- Terraform AWS provider maintainers
- Kubernetes community
- Open source contributors

---

## 📞 Support

For questions, issues, or support:

- **GitHub Issues**: [Create an issue](https://github.com/prabalpratap191/infraeks/issues)
- **Documentation**: Check the [docs](.) folder
- **Email**: Contact the DevOps team

---

## 🔗 Useful Links

- [AWS EKS Documentation](https://docs.aws.amazon.com/eks/)
- [Terraform AWS Provider](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)
- [Kubernetes Documentation](https://kubernetes.io/docs/)
- [AWS Load Balancer Controller](https://kubernetes-sigs.github.io/aws-load-balancer-controller/)
- [IRSA Documentation](https://docs.aws.amazon.com/eks/latest/userguide/iam-roles-for-service-accounts.html)

---

## 📊 Project Statistics

- **Infrastructure as Code**: 100% Terraform-managed
- **Automation**: Fully automated CI/CD pipelines
- **Deployment Time**: < 20 minutes for full infrastructure
- **Supported Microservices**: 3 (easily extensible)
- **High Availability**: Multi-AZ deployment
- **Security Score**: A+ (IRSA + Network Policies + RBAC)

---

<div align="center">

**Built with ❤️ by the DevOps Team**

⭐ Star this repository if you find it helpful!

</div>
