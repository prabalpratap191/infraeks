# Microservices Module - Creates namespace, service account, and RBAC for each microservice

resource "kubernetes_namespace" "microservice" {
  metadata {
    name = var.namespace
    labels = {
      name        = var.namespace
      environment = var.environment
      managed-by  = "terraform"
      service     = var.service_name
    }
  }
  
  timeouts {
    create = "5m"
    delete = "5m"
  }
}

# Service Account with IRSA annotation
resource "kubernetes_service_account" "microservice" {
  metadata {
    name      = var.service_account_name
    namespace = kubernetes_namespace.microservice.metadata[0].name
    annotations = {
      "eks.amazonaws.com/role-arn" = aws_iam_role.microservice_irsa.arn
    }
    labels = {
      "app.kubernetes.io/name"       = var.service_name
      "app.kubernetes.io/managed-by" = "terraform"
    }
  }
  
  timeouts {
    create = "5m"
  }
}

# IAM Role for IRSA (IAM Roles for Service Accounts)
data "aws_caller_identity" "current" {}

data "aws_iam_policy_document" "microservice_assume_role" {
  statement {
    effect = "Allow"
    principals {
      type        = "Federated"
      identifiers = ["arn:aws:iam::${data.aws_caller_identity.current.account_id}:oidc-provider/${var.oidc_provider}"]
    }
    actions = ["sts:AssumeRoleWithWebIdentity"]
    condition {
      test     = "StringEquals"
      variable = "${var.oidc_provider}:sub"
      values   = ["system:serviceaccount:${var.namespace}:${var.service_account_name}"]
    }
    condition {
      test     = "StringEquals"
      variable = "${var.oidc_provider}:aud"
      values   = ["sts.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "microservice_irsa" {
  name               = "${var.cluster_name}-${var.service_name}-irsa"
  assume_role_policy = data.aws_iam_policy_document.microservice_assume_role.json

  tags = {
    Name        = "${var.cluster_name}-${var.service_name}-irsa"
    Service     = var.service_name
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}

# IAM Policy for microservice - customizable per service
data "aws_iam_policy_document" "microservice_policy" {
  # S3 Access (if needed)
  dynamic "statement" {
    for_each = var.s3_buckets
    content {
      effect = "Allow"
      actions = [
        "s3:GetObject",
        "s3:PutObject",
        "s3:ListBucket"
      ]
      resources = [
        "arn:aws:s3:::${statement.value}",
        "arn:aws:s3:::${statement.value}/*"
      ]
    }
  }

  # DynamoDB Access (if needed)
  dynamic "statement" {
    for_each = var.dynamodb_tables
    content {
      effect = "Allow"
      actions = [
        "dynamodb:GetItem",
        "dynamodb:PutItem",
        "dynamodb:UpdateItem",
        "dynamodb:DeleteItem",
        "dynamodb:Query",
        "dynamodb:Scan"
      ]
      resources = [
        "arn:aws:dynamodb:${var.aws_region}:${data.aws_caller_identity.current.account_id}:table/${statement.value}"
      ]
    }
  }

  # SQS Access (if needed)
  dynamic "statement" {
    for_each = var.sqs_queues
    content {
      effect = "Allow"
      actions = [
        "sqs:SendMessage",
        "sqs:ReceiveMessage",
        "sqs:DeleteMessage",
        "sqs:GetQueueAttributes"
      ]
      resources = [
        "arn:aws:sqs:${var.aws_region}:${data.aws_caller_identity.current.account_id}:${statement.value}"
      ]
    }
  }

  # Secrets Manager Access (if needed)
  dynamic "statement" {
    for_each = var.secrets_manager_arns
    content {
      effect = "Allow"
      actions = [
        "secretsmanager:GetSecretValue",
        "secretsmanager:DescribeSecret"
      ]
      resources = [statement.value]
    }
  }

  # CloudWatch Logs
  statement {
    effect = "Allow"
    actions = [
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:PutLogEvents",
      "logs:DescribeLogStreams"
    ]
    resources = ["arn:aws:logs:${var.aws_region}:${data.aws_caller_identity.current.account_id}:log-group:/aws/eks/${var.cluster_name}/${var.service_name}:*"]
  }
}

resource "aws_iam_role_policy" "microservice_policy" {
  name   = "${var.service_name}-policy"
  role   = aws_iam_role.microservice_irsa.id
  policy = data.aws_iam_policy_document.microservice_policy.json
}

# RBAC - Role for namespace-scoped permissions
resource "kubernetes_role" "microservice" {
  metadata {
    name      = "${var.service_name}-role"
    namespace = kubernetes_namespace.microservice.metadata[0].name
  }

  rule {
    api_groups = [""]
    resources  = ["pods", "services", "configmaps", "secrets"]
    verbs      = ["get", "list", "watch"]
  }

  rule {
    api_groups = ["apps"]
    resources  = ["deployments", "replicasets"]
    verbs      = ["get", "list", "watch"]
  }

  rule {
    api_groups = [""]
    resources  = ["pods/log"]
    verbs      = ["get", "list"]
  }
}

# RBAC - RoleBinding
resource "kubernetes_role_binding" "microservice" {
  metadata {
    name      = "${var.service_name}-rolebinding"
    namespace = kubernetes_namespace.microservice.metadata[0].name
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "Role"
    name      = kubernetes_role.microservice.metadata[0].name
  }

  subject {
    kind      = "ServiceAccount"
    name      = kubernetes_service_account.microservice.metadata[0].name
    namespace = kubernetes_namespace.microservice.metadata[0].name
  }
}

# Network Policy for microservice
resource "kubernetes_network_policy" "microservice" {
  count = var.enable_network_policy ? 1 : 0

  metadata {
    name      = "${var.service_name}-netpol"
    namespace = kubernetes_namespace.microservice.metadata[0].name
  }

  spec {
    pod_selector {
      match_labels = {
        app = var.service_name
      }
    }

    policy_types = ["Ingress", "Egress"]

    # Ingress rules
    dynamic "ingress" {
      for_each = var.ingress_rules
      content {
        from {
          namespace_selector {
            match_labels = ingress.value.namespace_labels
          }
        }
        ports {
          protocol = ingress.value.protocol
          port     = ingress.value.port
        }
      }
    }

    # Egress - Allow DNS
    egress {
      to {
        namespace_selector {
          match_labels = {
            name = "kube-system"
          }
        }
      }
      ports {
        protocol = "UDP"
        port     = 53
      }
    }

    # Egress - Allow HTTPS (for AWS services)
    egress {
      to {
        pod_selector {}
      }
      ports {
        protocol = "TCP"
        port     = 443
      }
    }

    # Custom egress rules
    dynamic "egress" {
      for_each = var.egress_rules
      content {
        to {
          namespace_selector {
            match_labels = egress.value.namespace_labels
          }
        }
        ports {
          protocol = egress.value.protocol
          port     = egress.value.port
        }
      }
    }
  }
}

# Resource Quota (optional)
resource "kubernetes_resource_quota" "microservice" {
  count = var.enable_resource_quota ? 1 : 0

  metadata {
    name      = "${var.service_name}-quota"
    namespace = kubernetes_namespace.microservice.metadata[0].name
  }

  spec {
    hard = {
      "requests.cpu"    = var.resource_quota.requests_cpu
      "requests.memory" = var.resource_quota.requests_memory
      "limits.cpu"      = var.resource_quota.limits_cpu
      "limits.memory"   = var.resource_quota.limits_memory
      "pods"            = var.resource_quota.pods
    }
  }
}

# Limit Range (optional)
resource "kubernetes_limit_range" "microservice" {
  count = var.enable_limit_range ? 1 : 0

  metadata {
    name      = "${var.service_name}-limit-range"
    namespace = kubernetes_namespace.microservice.metadata[0].name
  }

  spec {
    limit {
      type = "Container"
      default = {
        cpu    = var.limit_range.default_cpu
        memory = var.limit_range.default_memory
      }
      default_request = {
        cpu    = var.limit_range.default_request_cpu
        memory = var.limit_range.default_request_memory
      }
    }
  }
}
