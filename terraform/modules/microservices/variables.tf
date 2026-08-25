variable "cluster_name" {
  description = "Name of the EKS cluster"
  type        = string
}

variable "service_name" {
  description = "Name of the microservice"
  type        = string
}

variable "namespace" {
  description = "Kubernetes namespace for the microservice"
  type        = string
}

variable "service_account_name" {
  description = "Name of the Kubernetes service account"
  type        = string
}

variable "environment" {
  description = "Environment (dev, staging, prod)"
  type        = string
  default     = "dev"
}

variable "oidc_provider" {
  description = "OIDC provider URL (without https://)"
  type        = string
}

variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

# AWS Resource Access
variable "s3_buckets" {
  description = "List of S3 bucket names the service needs access to"
  type        = list(string)
  default     = []
}

variable "dynamodb_tables" {
  description = "List of DynamoDB table names the service needs access to"
  type        = list(string)
  default     = []
}

variable "sqs_queues" {
  description = "List of SQS queue names the service needs access to"
  type        = list(string)
  default     = []
}

variable "secrets_manager_arns" {
  description = "List of AWS Secrets Manager ARNs the service needs access to"
  type        = list(string)
  default     = []
}

# Network Policy
variable "enable_network_policy" {
  description = "Enable network policy for the namespace"
  type        = bool
  default     = true
}

variable "ingress_rules" {
  description = "List of ingress rules for network policy"
  type = list(object({
    namespace_labels = map(string)
    protocol         = string
    port             = number
  }))
  default = [
    {
      namespace_labels = { name = "ingress-nginx" }
      protocol         = "TCP"
      port             = 8080
    }
  ]
}

variable "egress_rules" {
  description = "List of egress rules for network policy"
  type = list(object({
    namespace_labels = map(string)
    protocol         = string
    port             = number
  }))
  default = []
}

# Resource Quota
variable "enable_resource_quota" {
  description = "Enable resource quota for the namespace"
  type        = bool
  default     = false
}

variable "resource_quota" {
  description = "Resource quota settings"
  type = object({
    requests_cpu    = string
    requests_memory = string
    limits_cpu      = string
    limits_memory   = string
    pods            = string
  })
  default = {
    requests_cpu    = "4"
    requests_memory = "8Gi"
    limits_cpu      = "8"
    limits_memory   = "16Gi"
    pods            = "10"
  }
}

# Limit Range
variable "enable_limit_range" {
  description = "Enable limit range for the namespace"
  type        = bool
  default     = true
}

variable "limit_range" {
  description = "Limit range settings for containers"
  type = object({
    default_cpu            = string
    default_memory         = string
    default_request_cpu    = string
    default_request_memory = string
  })
  default = {
    default_cpu            = "500m"
    default_memory         = "512Mi"
    default_request_cpu    = "250m"
    default_request_memory = "256Mi"
  }
}
