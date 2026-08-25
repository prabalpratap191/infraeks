# EKS Cluster Outputs
output "cluster_name" {
  description = "Name of the EKS cluster"
  value       = module.eks.cluster_name
}

output "cluster_endpoint" {
  description = "Endpoint for EKS control plane"
  value       = module.eks.cluster_endpoint
}

output "cluster_region" {
  description = "AWS region where cluster is deployed"
  value       = var.region
}

# Order Service Outputs
output "order_service_namespace" {
  description = "Namespace for order service"
  value       = module.order_service.namespace
}

output "order_service_sa" {
  description = "Service account for order service"
  value       = module.order_service.service_account_name
}

output "order_service_irsa_role_arn" {
  description = "IAM role ARN for order service"
  value       = module.order_service.irsa_role_arn
}

# Catalog Service Outputs
output "catalog_service_namespace" {
  description = "Namespace for catalog service"
  value       = module.catalog_service.namespace
}

output "catalog_service_sa" {
  description = "Service account for catalog service"
  value       = module.catalog_service.service_account_name
}

output "catalog_service_irsa_role_arn" {
  description = "IAM role ARN for catalog service"
  value       = module.catalog_service.irsa_role_arn
}

# Customer Service Outputs
output "customer_service_namespace" {
  description = "Namespace for customer service"
  value       = module.customer_service.namespace
}

output "customer_service_sa" {
  description = "Service account for customer service"
  value       = module.customer_service.service_account_name
}

output "customer_service_irsa_role_arn" {
  description = "IAM role ARN for customer service"
  value       = module.customer_service.irsa_role_arn
}

# Load Balancer Controller
output "alb_controller_role_arn" {
  description = "IAM role ARN for AWS Load Balancer Controller"
  value       = module.aws_load_balancer_controller.iam_role_arn
}

# Kubeconfig Command
output "configure_kubectl" {
  description = "Command to configure kubectl"
  value       = "aws eks update-kubeconfig --region ${var.region} --name ${module.eks.cluster_name}"
}