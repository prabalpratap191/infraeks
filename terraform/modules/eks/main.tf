module "eks" {

  source = "terraform-aws-modules/eks/aws"

  cluster_name    = var.cluster_name
  cluster_version = "1.33"

  eks_managed_node_groups = {

    default = {

      desired_size = var.node_desired
      min_size     = var.node_min
      max_size     = var.node_max

      instance_types = [
        var.node_instance_type
      ]
    }
  }
}
