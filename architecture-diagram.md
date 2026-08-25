# Multi-Microservices Architecture Diagram

## High-Level Architecture

```mermaid
graph TB
    subgraph Internet
        Users[Users/API Clients]
    end
    
    subgraph AWS[AWS Cloud - us-east-1]
        subgraph VPC[Default VPC]
            ALB[Application Load Balancer<br/>internet-facing]
            
            subgraph EKS[EKS Cluster: meracommerce-dev]
                subgraph ControlPlane[Control Plane]
                    API[Kubernetes API Server]
                end
                
                subgraph Nodes[Node Group - t3.medium x2]
                    subgraph NS1[Namespace: order-service-ns]
                        OrderPod1[Order Service Pod 1]
                        OrderPod2[Order Service Pod 2]
                        OrderSvc[Service: order-service<br/>ClusterIP:8080]
                        OrderSA[ServiceAccount: order-sa]
                    end
                    
                    subgraph NS2[Namespace: catalog-service-ns]
                        CatalogPod1[Catalog Service Pod 1]
                        CatalogPod2[Catalog Service Pod 2]
                        CatalogSvc[Service: catalog-service<br/>ClusterIP:8080]
                        CatalogSA[ServiceAccount: catalog-sa]
                    end
                    
                    subgraph NS3[Namespace: customer-service-ns]
                        CustomerPod1[Customer Service Pod 1]
                        CustomerPod2[Customer Service Pod 2]
                        CustomerSvc[Service: customer-service<br/>ClusterIP:8080]
                        CustomerSA[ServiceAccount: customer-sa]
                    end
                    
                    subgraph SysNS[Namespace: kube-system]
                        ALBController[AWS LB Controller]
                        CoreDNS[CoreDNS]
                    end
                end
                
                Ingress[Ingress Resource<br/>Path-based Routing]
            end
        end
        
        subgraph IAM[IAM]
            OrderRole[IAM Role: order-service-irsa]
            CatalogRole[IAM Role: catalog-service-irsa]
            CustomerRole[IAM Role: customer-service-irsa]
            ALBRole[IAM Role: alb-controller]
        end
        
        subgraph Resources[AWS Resources]
            S3[S3 Buckets]
            DDB[DynamoDB Tables]
            SQS[SQS Queues]
            Secrets[Secrets Manager]
            ECR[ECR Repositories]
        end
    end
    
    subgraph CICD[CI/CD]
        Jenkins[Jenkins]
        OrderPipeline[Order Service Pipeline]
        CatalogPipeline[Catalog Service Pipeline]
        CustomerPipeline[Customer Service Pipeline]
    end
    
    %% User flow
    Users -->|HTTPS| ALB
    ALB -->|/api/orders| Ingress
    ALB -->|/api/catalog| Ingress
    ALB -->|/api/customers| Ingress
    
    %% Ingress routing
    Ingress -->|route| OrderSvc
    Ingress -->|route| CatalogSvc
    Ingress -->|route| CustomerSvc
    
    %% Service to Pods
    OrderSvc --> OrderPod1
    OrderSvc --> OrderPod2
    CatalogSvc --> CatalogPod1
    CatalogSvc --> CatalogPod2
    CustomerSvc --> CustomerPod1
    CustomerSvc --> CustomerPod2
    
    %% Inter-service communication
    OrderPod1 -.->|HTTP| CatalogSvc
    OrderPod1 -.->|HTTP| CustomerSvc
    
    %% IRSA
    OrderSA -->|assumes| OrderRole
    CatalogSA -->|assumes| CatalogRole
    CustomerSA -->|assumes| CustomerRole
    ALBController -->|assumes| ALBRole
    
    %% AWS resource access
    OrderRole -->|access| S3
    OrderRole -->|access| DDB
    OrderRole -->|access| SQS
    CatalogRole -->|access| S3
    CatalogRole -->|access| DDB
    CustomerRole -->|access| DDB
    CustomerRole -->|access| Secrets
    
    %% ALB management
    ALBController -->|manages| ALB
    ALBController -->|watches| Ingress
    
    %% CI/CD
    Jenkins --> OrderPipeline
    Jenkins --> CatalogPipeline
    Jenkins --> CustomerPipeline
    
    OrderPipeline -->|build & push| ECR
    OrderPipeline -->|deploy| OrderPod1
    CatalogPipeline -->|build & push| ECR
    CatalogPipeline -->|deploy| CatalogPod1
    CustomerPipeline -->|build & push| ECR
    CustomerPipeline -->|deploy| CustomerPod1
    
    %% DNS
    OrderPod1 -->|DNS lookup| CoreDNS
    CatalogPod1 -->|DNS lookup| CoreDNS
    CustomerPod1 -->|DNS lookup| CoreDNS
    
    classDef aws fill:#FF9900,stroke:#232F3E,stroke-width:2px,color:#fff
    classDef k8s fill:#326CE5,stroke:#fff,stroke-width:2px,color:#fff
    classDef service fill:#13aa52,stroke:#fff,stroke-width:2px,color:#fff
    classDef cicd fill:#D24939,stroke:#fff,stroke-width:2px,color:#fff
    
    class ALB,IAM,Resources,S3,DDB,SQS,Secrets,ECR aws
    class EKS,Nodes,NS1,NS2,NS3,SysNS,Ingress k8s
    class OrderSvc,CatalogSvc,CustomerSvc,ALBController service
    class Jenkins,OrderPipeline,CatalogPipeline,CustomerPipeline cicd
```

## Network Policy Flow

```mermaid
graph LR
    subgraph Internet
        Client[External Client]
    end
    
    subgraph EKS_Cluster
        ALB[ALB]
        
        subgraph Ingress_NS[ingress-nginx namespace]
            IngressCtrl[Ingress Controller]
        end
        
        subgraph Order_NS[order-service-ns]
            OrderPod[Order Pod]
        end
        
        subgraph Catalog_NS[catalog-service-ns]
            CatalogPod[Catalog Pod]
        end
        
        subgraph Customer_NS[customer-service-ns]
            CustomerPod[Customer Pod]
        end
        
        subgraph System_NS[kube-system]
            DNS[CoreDNS]
        end
        
        subgraph AWS_Services
            S3_DDB[S3/DynamoDB/SQS]
        end
    end
    
    Client -->|HTTPS:443| ALB
    ALB -->|HTTP:80| IngressCtrl
    IngressCtrl -->|TCP:8080<br/>✅ ALLOW| OrderPod
    IngressCtrl -->|TCP:8080<br/>✅ ALLOW| CatalogPod
    IngressCtrl -->|TCP:8080<br/>✅ ALLOW| CustomerPod
    
    OrderPod -->|TCP:8080<br/>✅ ALLOW| CatalogPod
    OrderPod -->|TCP:8080<br/>✅ ALLOW| CustomerPod
    CatalogPod -.->|TCP:8080<br/>❌ DENY| OrderPod
    CustomerPod -.->|TCP:8080<br/>❌ DENY| OrderPod
    
    OrderPod -->|UDP:53<br/>✅ ALLOW| DNS
    CatalogPod -->|UDP:53<br/>✅ ALLOW| DNS
    CustomerPod -->|UDP:53<br/>✅ ALLOW| DNS
    
    OrderPod -->|HTTPS:443<br/>✅ ALLOW| S3_DDB
    CatalogPod -->|HTTPS:443<br/>✅ ALLOW| S3_DDB
    CustomerPod -->|HTTPS:443<br/>✅ ALLOW| S3_DDB
    
    style Client fill:#e1f5ff
    style OrderPod fill:#ffe1e1
    style CatalogPod fill:#e1ffe1
    style CustomerPod fill:#ffe1ff
```

## CI/CD Pipeline Flow

```mermaid
sequenceDiagram
    participant Dev as Developer
    participant Git as Git Repository
    participant Jenkins as Jenkins
    participant Maven as Maven Build
    participant Docker as Docker
    participant ECR as AWS ECR
    participant EKS as EKS Cluster
    participant ALB as Application LB
    
    Dev->>Git: Push code
    Git->>Jenkins: Webhook trigger
    Jenkins->>Git: Checkout code
    Jenkins->>Maven: mvn clean package
    Maven-->>Jenkins: Build artifact (.jar)
    
    Jenkins->>Maven: mvn test
    Maven-->>Jenkins: Test results
    
    Jenkins->>Docker: docker build
    Docker-->>Jenkins: Image created
    
    Jenkins->>ECR: docker push
    ECR-->>Jenkins: Image pushed
    
    Jenkins->>EKS: kubectl apply -f deployment.yaml
    EKS->>EKS: Pull image from ECR
    EKS->>EKS: Create pods
    EKS->>EKS: Run health checks
    
    alt Deployment Success
        EKS-->>Jenkins: Rollout complete
        Jenkins->>EKS: kubectl rollout status
        EKS-->>Jenkins: Deployment successful
        EKS->>ALB: Register pods as targets
        Jenkins-->>Dev: ✅ Deployment Success
    else Deployment Failure
        EKS-->>Jenkins: Rollout failed
        Jenkins->>EKS: kubectl rollout undo
        EKS->>EKS: Rollback to previous version
        Jenkins-->>Dev: ❌ Deployment Failed - Rolled back
    end
```

## IRSA (IAM Roles for Service Accounts) Flow

```mermaid
sequenceDiagram
    participant Pod as Service Pod
    participant SA as Service Account
    participant Webhook as IRSA Webhook
    participant STS as AWS STS
    participant IAM as IAM Role
    participant S3 as AWS S3/DynamoDB
    
    Pod->>SA: Pod uses ServiceAccount
    SA->>Webhook: Webhook injects IRSA token
    Webhook->>Pod: Token mounted at /var/run/secrets/eks.amazonaws.com/serviceaccount/token
    
    Pod->>STS: AssumeRoleWithWebIdentity(token)
    STS->>STS: Verify OIDC token
    STS->>IAM: Validate role trust policy
    IAM-->>STS: Trust policy valid
    STS-->>Pod: Temporary credentials (AccessKey, SecretKey, SessionToken)
    
    Pod->>S3: API call with temporary credentials
    S3->>IAM: Validate permissions
    IAM-->>S3: Permissions granted
    S3-->>Pod: ✅ Access granted
```

## Deployment Architecture by Team

```mermaid
graph TB
    subgraph Team_A[Order Service Team]
        OrderRepo[Order Service<br/>Git Repository]
        OrderJenkins[Jenkins Job:<br/>order-service-deployment]
    end
    
    subgraph Team_B[Catalog Service Team]
        CatalogRepo[Catalog Service<br/>Git Repository]
        CatalogJenkins[Jenkins Job:<br/>catalog-service-deployment]
    end
    
    subgraph Team_C[Customer Service Team]
        CustomerRepo[Customer Service<br/>Git Repository]
        CustomerJenkins[Jenkins Job:<br/>customer-service-deployment]
    end
    
    subgraph Shared_EKS[Shared EKS Cluster: meracommerce-dev]
        subgraph Order_Isolated[Order Service Namespace ✅ ISOLATED]
            OrderDeploy[Order Deployment]
        end
        
        subgraph Catalog_Isolated[Catalog Service Namespace ✅ ISOLATED]
            CatalogDeploy[Catalog Deployment]
        end
        
        subgraph Customer_Isolated[Customer Service Namespace ✅ ISOLATED]
            CustomerDeploy[Customer Deployment]
        end
        
        SharedALB[Shared Application Load Balancer]
    end
    
    OrderRepo -->|Trigger| OrderJenkins
    OrderJenkins -->|Deploy| OrderDeploy
    
    CatalogRepo -->|Trigger| CatalogJenkins
    CatalogJenkins -->|Deploy| CatalogDeploy
    
    CustomerRepo -->|Trigger| CustomerJenkins
    CustomerJenkins -->|Deploy| CustomerDeploy
    
    OrderDeploy -.->|Route traffic| SharedALB
    CatalogDeploy -.->|Route traffic| SharedALB
    CustomerDeploy -.->|Route traffic| SharedALB
    
    style Team_A fill:#ff6b6b
    style Team_B fill:#4ecdc4
    style Team_C fill:#45b7d1
    style Order_Isolated fill:#ffe1e1
    style Catalog_Isolated fill:#e1fff8
    style Customer_Isolated fill:#e1f3ff
```

## Resource Hierarchy

```
AWS Account
└── Region: us-east-1
    ├── VPC: Default VPC
    │   ├── Subnets: us-east-1a, us-east-1b, us-east-1c
    │   └── Security Groups
    │
    ├── EKS Cluster: meracommerce-dev
    │   ├── Control Plane (v1.31)
    │   │   └── OIDC Provider: oidc.eks.us-east-1.amazonaws.com/id/XXX
    │   │
    │   ├── Node Group: meracommerce-dev-node-group
    │   │   ├── Instance Type: t3.medium
    │   │   ├── Min: 1, Desired: 2, Max: 3
    │   │   └── AMI: Amazon Linux 2023
    │   │
    │   └── Namespaces
    │       ├── kube-system
    │       │   ├── ServiceAccount: aws-load-balancer-controller
    │       │   └── Deployment: aws-load-balancer-controller
    │       │
    │       ├── order-service-ns
    │       │   ├── ServiceAccount: order-sa
    │       │   ├── Deployment: order-service (replicas: 2)
    │       │   ├── Service: order-service (ClusterIP)
    │       │   ├── ConfigMap: order-service-config
    │       │   ├── Secret: order-service-secret
    │       │   ├── NetworkPolicy: order-service-netpol
    │       │   ├── ResourceQuota: order-service-quota
    │       │   └── LimitRange: order-service-limit-range
    │       │
    │       ├── catalog-service-ns
    │       │   └── (Same structure as order-service-ns)
    │       │
    │       └── customer-service-ns
    │           └── (Same structure as order-service-ns)
    │
    ├── IAM Roles
    │   ├── meracommerce-dev-order-service-irsa
    │   │   └── Trust Policy: OIDC Provider + order-sa
    │   ├── meracommerce-dev-catalog-service-irsa
    │   ├── meracommerce-dev-customer-service-irsa
    │   └── meracommerce-dev-aws-load-balancer-controller
    │
    ├── ECR Repositories
    │   ├── order-service
    │   ├── catalog-service
    │   └── customer-service
    │
    └── Elastic Load Balancers
        └── k8s-default-microser-XXX (ALB)
            ├── Target Group: order-service
            ├── Target Group: catalog-service
            └── Target Group: customer-service
```

---

**Legend:**
- ✅ ALLOW - Network policy allows traffic
- ❌ DENY - Network policy blocks traffic
- Solid arrows (→) - Direct communication
- Dashed arrows (-.→) - Conditional/restricted communication
