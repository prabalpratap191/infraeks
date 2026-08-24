variable "cluster_name" {}
variable "region" {
  default = "us-east-1"
}
variable "namespace" {}
variable "service_account" {}
variable "node_instance_type" {
  default = "t3.medium"
}
variable "node_desired" {
  default = 2
}
variable "node_min" {
  default = 1
}
variable "node_max" {
  default = 3
}

variable "cluster_version" {
  description = "Kubernetes version for the EKS cluster"
  type        = string
  default     = "1.33"
}

variable "availability_zones" {
  description = "List of availability zones for the EKS cluster"
  type        = list(string)
  default     = ["us-east-1a", "us-east-1b", "us-east-1c"]
}
