variable "cluster_name" {
  description = "Name of the EKS cluster"
  type        = string
}

variable "region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "environment" {
  description = "Environment (dev, staging, prod)"
  type        = string
  default     = "dev"
}

# Legacy variables (kept for backward compatibility)
variable "namespace" {
  description = "Legacy namespace variable (use microservice-specific modules instead)"
  type        = string
  default     = ""
}

variable "service_account" {
  description = "Legacy service account variable (use microservice-specific modules instead)"
  type        = string
  default     = ""
}

variable "node_instance_type" {
  description = "EC2 instance type for EKS nodes"
  type        = string
  default     = "t3.medium"
}

variable "node_desired" {
  description = "Desired number of worker nodes"
  type        = number
  default     = 2
}

variable "node_min" {
  description = "Minimum number of worker nodes"
  type        = number
  default     = 1
}

variable "node_max" {
  description = "Maximum number of worker nodes"
  type        = number
  default     = 3
}

variable "cluster_version" {
  description = "Kubernetes version for the EKS cluster"
  type        = string
  default     = "1.31"
}

variable "availability_zones" {
  description = "List of availability zones for the EKS cluster"
  type        = list(string)
  default     = ["us-east-1a", "us-east-1b", "us-east-1c"]
}

# Order Service Configuration
variable "order_service_s3_buckets" {
  description = "S3 buckets that order service needs access to"
  type        = list(string)
  default     = []
}

variable "order_service_dynamodb_tables" {
  description = "DynamoDB tables that order service needs access to"
  type        = list(string)
  default     = []
}

variable "order_service_sqs_queues" {
  description = "SQS queues that order service needs access to"
  type        = list(string)
  default     = []
}

variable "order_service_secrets" {
  description = "AWS Secrets Manager ARNs for order service"
  type        = list(string)
  default     = []
}

# Catalog Service Configuration
variable "catalog_service_s3_buckets" {
  description = "S3 buckets that catalog service needs access to"
  type        = list(string)
  default     = []
}

variable "catalog_service_dynamodb_tables" {
  description = "DynamoDB tables that catalog service needs access to"
  type        = list(string)
  default     = []
}

variable "catalog_service_sqs_queues" {
  description = "SQS queues that catalog service needs access to"
  type        = list(string)
  default     = []
}

variable "catalog_service_secrets" {
  description = "AWS Secrets Manager ARNs for catalog service"
  type        = list(string)
  default     = []
}

# Customer Service Configuration
variable "customer_service_s3_buckets" {
  description = "S3 buckets that customer service needs access to"
  type        = list(string)
  default     = []
}

variable "customer_service_dynamodb_tables" {
  description = "DynamoDB tables that customer service needs access to"
  type        = list(string)
  default     = []
}

variable "customer_service_sqs_queues" {
  description = "SQS queues that customer service needs access to"
  type        = list(string)
  default     = []
}

variable "customer_service_secrets" {
  description = "AWS Secrets Manager ARNs for customer service"
  type        = list(string)
  default     = []
}
