# Multi-Microservices Deployment Architecture

## Overview

This document outlines the architecture and changes required to deploy multiple Java microservices (Order Service, Catalog Service, Customer Service) to the EKS cluster from separate CI/CD pipelines.

## Current State Analysis

### ✅ What's Already Provisioned
- **EKS Cluster**: `meracommerce-dev` with Kubernetes 1.31
- **Node Group**: 2 t3.medium instances (min: 1, max: 3)
- **Networking**: Default VPC with filtered subnets (us-east-1a, us-east-1b, us-east-1c)
- **IAM**: IRSA enabled for service account authentication
- **Basic Modules**:
  - Namespace module (single namespace support)
  - Service Account module (single service account support)
  - IRSA module (basic IAM role creation)

### ❌ What's Missing for Multi-Microservice Deployment

1. **Multiple Namespace Support** - Currently only supports 1 namespace
2. **AWS Load Balancer Controller** - Required for ALB/NLB ingress
3. **Ingress Controller** - For routing traffic to services
4. **Network Policies Module** - For ingress/egress rules
5. **ConfigMap/Secret Management** - For microservice configuration
6. **RBAC Module** - For fine-grained access control
7. **Service Mesh (Optional)** - For advanced traffic management
8. **Monitoring Stack** - For observability

## Proposed Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                         AWS Account                              │
│  ┌───────────────────────────────────────────────────────────┐  │
│  │                    VPC (Default)                           │  │
│  │  ┌─────────────────────────────────────────────────────┐  │  │
│  │  │          EKS Cluster (meracommerce-dev)            │  │  │
│  │  │                                                     │  │  │
│  │  │  ┌──────────────────────────────────────────────┐  │  │  │
│  │  │  │  Namespace: order-service-ns                │  │  │  │
│  │  │  │  ├── ServiceAccount: order-sa (IRSA)        │  │  │  │
│  │  │  │  ├── Deployment: order-service              │  │  │  │
│  │  │  │  ├── Service: order-svc (ClusterIP)         │  │  │  │
│  │  │  │  ├── ConfigMap: order-config                │  │  │  │
│  │  │  │  └── NetworkPolicy: order-netpol            │  │  │  │
│  │  │  └──────────────────────────────────────────────┘  │  │  │
│  │  │                                                     │  │  │
│  │  │  ┌──────────────────────────────────────────────┐  │  │  │
│  │  │  │  Namespace: catalog-service-ns              │  │  │  │
│  │  │  │  ├── ServiceAccount: catalog-sa (IRSA)      │  │  │  │
│  │  │  │  ├── Deployment: catalog-service            │  │  │  │
│  │  │  │  ├── Service: catalog-svc (ClusterIP)       │  │  │  │
│  │  │  │  ├── ConfigMap: catalog-config              │  │  │  │
│  │  │  │  └── NetworkPolicy: catalog-netpol          │  │  │  │
│  │  │  └──────────────────────────────────────────────┘  │  │  │
│  │  │                                                     │  │  │
│  │  │  ┌──────────────────────────────────────────────┐  │  │  │
│  │  │  │  Namespace: customer-service-ns             │  │  │  │
│  │  │  │  ├── ServiceAccount: customer-sa (IRSA)     │  │  │  │
│  │  │  │  ├── Deployment: customer-service           │  │  │  │
│  │  │  │  ├── Service: customer-svc (ClusterIP)      │  │  │  │
│  │  │  │  ├── ConfigMap: customer-config             │  │  │  │
│  │  │  │  └── NetworkPolicy: customer-netpol         │  │  │  │
│  │  │  └──────────────────────────────────────────────┘  │  │  │
│  │  │                                                     │  │  │
│  │  │  ┌──────────────────────────────────────────────┐  │  │  │
│  │  │  │  Namespace: ingress-nginx                   │  │  │  │
│  │  │  │  └── AWS Load Balancer Controller           │  │  │  │
│  │  │  └──────────────────────────────────────────────┘  │  │  │
│  │  │                                                     │  │  │
│  │  │  ┌──────────────────────────────────────────────┐  │  │  │
│  │  │  │  Ingress Resources                          │  │  │  │
│  │  │  │  ├── /api/orders → order-service            │  │  │  │
│  │  │  │  ├── /api/catalog → catalog-service         │  │  │  │
│  │  │  │  └── /api/customers → customer-service      │  │  │  │
│  │  │  └──────────────────────────────────────────────┘  │  │  │
│  │  └─────────────────────────────────────────────────┘  │  │
│  └───────────────────────────────────────────────────────┘  │
│                            ↑                                  │
│                            │                                  │
│  ┌─────────────────────────┴──────────────────────────────┐  │
│  │    Application Load Balancer (ALB)                     │  │
│  │    - Public Subnet                                      │  │
│  │    - SSL Termination                                    │  │
│  │    - Path-based Routing                                 │  │
│  └─────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────┘
```

## Required Changes

### 1. Infrastructure Changes (Terraform)

#### A. Update Main Configuration to Support Multiple Namespaces
**File**: `terraform/main.tf`

**Changes**:
- Convert single namespace/service-account to list/map structure
- Add AWS Load Balancer Controller module
- Add Ingress Controller module
- Add Network Policy module

#### B. Create Microservices Module
**New Module**: `terraform/modules/microservices`

This module will:
- Create namespace per microservice
- Create service account with IRSA
- Setup RBAC (Role/RoleBinding)
- Create NetworkPolicy for ingress/egress
- Export outputs for CI/CD pipelines

#### C. Add AWS Load Balancer Controller
**New Module**: `terraform/modules/aws-load-balancer-controller`

This will:
- Install AWS Load Balancer Controller via Helm
- Configure IRSA for controller
- Setup required IAM policies

#### D. Add Storage Class Configuration
**New Module**: `terraform/modules/storage`

For persistent volumes if needed by microservices.

### 2. Kubernetes Resources for Each Microservice

Each CI/CD pipeline will deploy:

```yaml
# Deployment
apiVersion: apps/v1
kind: Deployment
metadata:
  name: <service-name>
  namespace: <service-namespace>

# Service (ClusterIP)
apiVersion: v1
kind: Service
metadata:
  name: <service-name>
  namespace: <service-namespace>
spec:
  type: ClusterIP

# ConfigMap
apiVersion: v1
kind: ConfigMap
metadata:
  name: <service-name>-config
  namespace: <service-namespace>

# Secrets (managed via AWS Secrets Manager + External Secrets Operator)
apiVersion: v1
kind: Secret
metadata:
  name: <service-name>-secret
  namespace: <service-namespace>
```

### 3. Ingress Configuration

**Shared Ingress** (Recommended):
```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: microservices-ingress
  namespace: default
  annotations:
    kubernetes.io/ingress.class: alb
    alb.ingress.kubernetes.io/scheme: internet-facing
    alb.ingress.kubernetes.io/target-type: ip
    alb.ingress.kubernetes.io/healthcheck-path: /actuator/health
spec:
  rules:
  - host: api.meracommerce.com
    http:
      paths:
      - path: /api/orders
        pathType: Prefix
        backend:
          service:
            name: order-service
            port:
              number: 8080
      - path: /api/catalog
        pathType: Prefix
        backend:
          service:
            name: catalog-service
            port:
              number: 8080
      - path: /api/customers
        pathType: Prefix
        backend:
          service:
            name: customer-service
            port:
              number: 8080
```

### 4. Network Policies

**Order Service Example**:
```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: order-service-netpol
  namespace: order-service-ns
spec:
  podSelector:
    matchLabels:
      app: order-service
  policyTypes:
  - Ingress
  - Egress
  ingress:
  - from:
    - namespaceSelector:
        matchLabels:
          name: ingress-nginx
    ports:
    - protocol: TCP
      port: 8080
  egress:
  # Allow DNS
  - to:
    - namespaceSelector:
        matchLabels:
          name: kube-system
    ports:
    - protocol: UDP
      port: 53
  # Allow to catalog-service
  - to:
    - namespaceSelector:
        matchLabels:
          name: catalog-service-ns
    ports:
    - protocol: TCP
      port: 8080
  # Allow to external APIs (AWS services)
  - to:
    - podSelector: {}
    ports:
    - protocol: TCP
      port: 443
```

## CI/CD Pipeline Integration

### Pipeline Structure for Each Microservice

```groovy
pipeline {
    agent any
    
    parameters {
        string(name: 'SERVICE_NAME', defaultValue: 'order-service')
        string(name: 'NAMESPACE', defaultValue: 'order-service-ns')
        string(name: 'IMAGE_TAG', defaultValue: 'latest')
        string(name: 'CLUSTER_NAME', defaultValue: 'meracommerce-dev')
    }
    
    stages {
        stage('Build') {
            steps {
                sh 'mvn clean package'
            }
        }
        
        stage('Docker Build & Push') {
            steps {
                sh '''
                    docker build -t ${ECR_REGISTRY}/${SERVICE_NAME}:${IMAGE_TAG} .
                    aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin ${ECR_REGISTRY}
                    docker push ${ECR_REGISTRY}/${SERVICE_NAME}:${IMAGE_TAG}
                '''
            }
        }
        
        stage('Update Kubeconfig') {
            steps {
                sh 'aws eks update-kubeconfig --name ${CLUSTER_NAME} --region us-east-1'
            }
        }
        
        stage('Deploy to EKS') {
            steps {
                sh '''
                    kubectl apply -f k8s/namespace.yaml
                    kubectl apply -f k8s/configmap.yaml
                    kubectl apply -f k8s/deployment.yaml
                    kubectl apply -f k8s/service.yaml
                    kubectl rollout status deployment/${SERVICE_NAME} -n ${NAMESPACE}
                '''
            }
        }
        
        stage('Verify Deployment') {
            steps {
                sh '''
                    kubectl get pods -n ${NAMESPACE}
                    kubectl get svc -n ${NAMESPACE}
                '''
            }
        }
    }
}
```

## Summary of Required Changes

### High Priority (Required)
1. ✅ **Refactor namespace/service-account modules** to support multiple microservices
2. ✅ **Add AWS Load Balancer Controller** for ALB integration
3. ✅ **Create microservices module** for standardized namespace/SA/RBAC setup
4. ✅ **Add NetworkPolicy module** for ingress/egress rules
5. ✅ **Setup ECR repositories** for container images
6. ✅ **Create Ingress resources** for routing

### Medium Priority (Recommended)
7. ⚠️ **External Secrets Operator** for AWS Secrets Manager integration
8. ⚠️ **Cert-Manager** for SSL certificate management
9. ⚠️ **Cluster Autoscaler** for dynamic scaling
10. ⚠️ **Metrics Server** for HPA (Horizontal Pod Autoscaling)

### Low Priority (Optional)
11. 📌 **Service Mesh (Istio/Linkerd)** for advanced traffic management
12. 📌 **Monitoring Stack** (Prometheus/Grafana)
13. 📌 **Logging Stack** (Fluentd/CloudWatch)
14. 📌 **ArgoCD** for GitOps deployments

## Next Steps

1. Review and approve the architecture
2. Implement Terraform module changes
3. Create Kubernetes manifest templates for microservices
4. Setup ECR repositories
5. Update CI/CD pipelines
6. Test deployment with one microservice
7. Rollout to all three microservices
8. Configure monitoring and logging

---
**Estimated Implementation Time**: 2-3 days for core infrastructure, 1 week for full setup with monitoring
