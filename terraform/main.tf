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
