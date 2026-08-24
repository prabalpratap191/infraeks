variable "cluster_name" {
  description = "Name of the EKS cluster"
  type        = string
}

variable "node_instance_type" {
  description = "EC2 instance type for EKS worker nodes"
  type        = string
}

variable "node_desired" {
  description = "Desired number of worker nodes"
  type        = number
}

variable "node_min" {
  description = "Minimum number of worker nodes"
  type        = number
}

variable "node_max" {
  description = "Maximum number of worker nodes"
  type        = number
}

variable "cluster_version" {
  description = "Kubernetes version for the EKS cluster"
  type        = string
  default     = "1.33"
}
