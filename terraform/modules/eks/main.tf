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

# Filter subnets to exclude us-east-1e and ensure they're in allowed AZs
data "aws_subnets" "filtered" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }

  filter {
    name   = "availability-zone"
    values = ["us-east-1a", "us-east-1b", "us-east-1c"]
  }

  # Ensure subnets have available IP addresses
  filter {
    name   = "state"
    values = ["available"]
  }
}

module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.0"

  cluster_name    = var.cluster_name
  cluster_version = var.cluster_version  # Use variable to allow flexibility

  cluster_endpoint_public_access = true
  cluster_endpoint_private_access = true

  # Enable IRSA (IAM Roles for Service Accounts)
  enable_irsa = true

  vpc_id     = data.aws_vpc.default.id
  
  # Use dynamic subnets with proper filtering for us-east-1a, us-east-1b, us-east-1c only
  subnet_ids = data.aws_subnets.filtered.ids

  # Configure cluster security group rules
  cluster_security_group_additional_rules = {
    ingress_nodes_ephemeral_ports_tcp = {
      description                = "Nodes to cluster API"
      protocol                   = "tcp"
      from_port                  = 1025
      to_port                    = 65535
      type                       = "ingress"
      source_node_security_group = true
    }
  }

  # Configure node security group rules
  node_security_group_additional_rules = {
    ingress_self_all = {
      description = "Node to node all ports/protocols"
      protocol    = "-1"
      from_port   = 0
      to_port     = 0
      type        = "ingress"
      self        = true
    }
    ingress_cluster_all = {
      description                   = "Cluster to node all ports/protocols"
      protocol                      = "-1"
      from_port                     = 0
      to_port                       = 0
      type                          = "ingress"
      source_cluster_security_group = true
    }
    egress_all = {
      description      = "Node all egress"
      protocol         = "-1"
      from_port        = 0
      to_port          = 0
      type             = "egress"
      cidr_blocks      = ["0.0.0.0/0"]
      ipv6_cidr_blocks = ["::/0"]
    }
  }

  eks_managed_node_groups = {
    default = {
      name            = "${var.cluster_name}-ng"
      use_name_prefix = false
      
      # Shorten IAM role name to avoid 38 character limit
      iam_role_name          = "${var.cluster_name}-node-role"
      iam_role_use_name_prefix = false

      desired_size = var.node_desired
      min_size     = var.node_min
      max_size     = var.node_max

      instance_types = [var.node_instance_type]
      capacity_type  = "ON_DEMAND"

      # Explicitly configure AMI type
      ami_type = "AL2023_x86_64_STANDARD"  # Amazon Linux 2023

      # Enable detailed monitoring
      enable_monitoring = true

      # Configure instance metadata options
      # Note: Using "optional" for http_tokens to avoid bootstrap issues with AL2023
      metadata_options = {
        http_endpoint               = "enabled"
        http_tokens                 = "optional"  # Changed from "required" to fix AL2023 bootstrap issues
        http_put_response_hop_limit = 2
        instance_metadata_tags      = "disabled"
      }

      # Block device mappings
      block_device_mappings = {
        xvda = {
          device_name = "/dev/xvda"
          ebs = {
            volume_size           = 30
            volume_type           = "gp3"
            iops                  = 3000
            throughput            = 125
            encrypted             = true
            delete_on_termination = true
          }
        }
      }

      # IAM role configuration - CRITICAL for node authentication
      iam_role_attach_cni_policy = true
      iam_role_additional_policies = {
        AmazonSSMManagedInstanceCore = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
      }

      # User data template - minimal configuration to avoid bootstrap conflicts
      # Removed pre_bootstrap_user_data to prevent interference with default AL2023 bootstrap
      enable_bootstrap_user_data = true

      tags = {
        Environment = "dev"
        Terraform   = "true"
        Name        = "${var.cluster_name}-eks-node"
      }
    }
  }

  tags = {
    Environment = "dev"
    Terraform   = "true"
    ManagedBy   = "Terraform"
  }
}
