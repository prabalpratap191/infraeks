# Get default VPC
data "aws_vpc" "default" {
  default = true
}

# Get default subnets
data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.0"

  cluster_name    = var.cluster_name
  cluster_version = "1.30"

  cluster_endpoint_public_access = true

  vpc_id     = data.aws_vpc.default.id
  #subnet_ids = data.aws_subnets.default.ids

  # CHANGE: Updated subnet IDs to exclude us-east-1e subnets
  subnet_ids = [
    aws_subnet.private_us_east_1a.id,
    aws_subnet.private_us_east_1b.id,
    aws_subnet.private_us_east_1c.id,
    # Removed: aws_subnet.private_us_east_1e.id
  ]

  eks_managed_node_groups = {
    default = {
      desired_size = var.node_desired
      min_size     = var.node_min
      max_size     = var.node_max

      instance_types = [var.node_instance_type]

      tags = {
        Environment = "dev"
        Terraform   = "true"
      }
    }
  }

  tags = {
    Environment = "dev"
    Terraform   = "true"
  }
}
