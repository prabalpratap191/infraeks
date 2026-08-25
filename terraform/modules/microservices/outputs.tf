output "namespace" {
  description = "Name of the created namespace"
  value       = kubernetes_namespace.microservice.metadata[0].name
}

output "service_account_name" {
  description = "Name of the service account"
  value       = kubernetes_service_account.microservice.metadata[0].name
}

output "irsa_role_arn" {
  description = "ARN of the IRSA IAM role"
  value       = aws_iam_role.microservice_irsa.arn
}

output "irsa_role_name" {
  description = "Name of the IRSA IAM role"
  value       = aws_iam_role.microservice_irsa.name
}

output "namespace_labels" {
  description = "Labels applied to the namespace"
  value       = kubernetes_namespace.microservice.metadata[0].labels
}
