terraform {
  required_version = ">= 1.0.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.20"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.12"
    }
  }
}

provider "aws" {
  region = var.region
}

# EKS Cluster Module
module "eks" {
  source = "./modules/eks"

  cluster_name        = var.cluster_name
  node_instance_type  = var.node_instance_type
  node_desired        = var.node_desired
  node_min            = var.node_min
  node_max            = var.node_max
}

# Data source for EKS cluster authentication
data "aws_eks_cluster_auth" "eks" {
  name = module.eks.cluster_name
}

# Get VPC ID for Load Balancer Controller
data "aws_vpc" "default" {
  default = true
}

# AWS Load Balancer Controller
module "aws_load_balancer_controller" {
  source = "./modules/aws-load-balancer-controller"

  cluster_name  = var.cluster_name
  oidc_provider = replace(module.eks.cluster_oidc_issuer_url, "https://", "")
  vpc_id        = data.aws_vpc.default.id
  aws_region    = var.region

  depends_on = [module.eks]
}

# Order Service Namespace and Resources
module "order_service" {
  source = "./modules/microservices"

  cluster_name         = var.cluster_name
  service_name         = "order-service"
  namespace            = "order-service-ns"
  service_account_name = "order-sa"
  environment          = var.environment
  oidc_provider        = replace(module.eks.cluster_oidc_issuer_url, "https://", "")
  aws_region           = var.region

  # AWS resource access (customize per service)
  s3_buckets            = var.order_service_s3_buckets
  dynamodb_tables       = var.order_service_dynamodb_tables
  sqs_queues            = var.order_service_sqs_queues
  secrets_manager_arns  = var.order_service_secrets

  # Network policies
  enable_network_policy = true
  ingress_rules = [
    {
      namespace_labels = { name = "ingress-nginx" }
      protocol         = "TCP"
      port             = 8080
    }
  ]
  egress_rules = [
    # Allow communication with catalog service
    {
      namespace_labels = { name = "catalog-service-ns" }
      protocol         = "TCP"
      port             = 8080
    },
    # Allow communication with customer service
    {
      namespace_labels = { name = "customer-service-ns" }
      protocol         = "TCP"
      port             = 8080
    }
  ]

  # Resource limits
  enable_resource_quota = true
  enable_limit_range    = true

  depends_on = [module.eks]
}

# Catalog Service Namespace and Resources
module "catalog_service" {
  source = "./modules/microservices"

  cluster_name         = var.cluster_name
  service_name         = "catalog-service"
  namespace            = "catalog-service-ns"
  service_account_name = "catalog-sa"
  environment          = var.environment
  oidc_provider        = replace(module.eks.cluster_oidc_issuer_url, "https://", "")
  aws_region           = var.region

  # AWS resource access
  s3_buckets            = var.catalog_service_s3_buckets
  dynamodb_tables       = var.catalog_service_dynamodb_tables
  sqs_queues            = var.catalog_service_sqs_queues
  secrets_manager_arns  = var.catalog_service_secrets

  # Network policies
  enable_network_policy = true
  ingress_rules = [
    {
      namespace_labels = { name = "ingress-nginx" }
      protocol         = "TCP"
      port             = 8080
    },
    # Allow from order service
    {
      namespace_labels = { name = "order-service-ns" }
      protocol         = "TCP"
      port             = 8080
    }
  ]

  # Resource limits
  enable_resource_quota = true
  enable_limit_range    = true

  depends_on = [module.eks]
}

# Customer Service Namespace and Resources
module "customer_service" {
  source = "./modules/microservices"

  cluster_name         = var.cluster_name
  service_name         = "customer-service"
  namespace            = "customer-service-ns"
  service_account_name = "customer-sa"
  environment          = var.environment
  oidc_provider        = replace(module.eks.cluster_oidc_issuer_url, "https://", "")
  aws_region           = var.region

  # AWS resource access
  s3_buckets            = var.customer_service_s3_buckets
  dynamodb_tables       = var.customer_service_dynamodb_tables
  sqs_queues            = var.customer_service_sqs_queues
  secrets_manager_arns  = var.customer_service_secrets

  # Network policies
  enable_network_policy = true
  ingress_rules = [
    {
      namespace_labels = { name = "ingress-nginx" }
      protocol         = "TCP"
      port             = 8080
    },
    # Allow from order service
    {
      namespace_labels = { name = "order-service-ns" }
      protocol         = "TCP"
      port             = 8080
    }
  ]

  # Resource limits
  enable_resource_quota = true
  enable_limit_range    = true

  depends_on = [module.eks]
}
