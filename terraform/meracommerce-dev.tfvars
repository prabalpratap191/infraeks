# Environment: Development
cluster_name        = "meracommerce-dev"
region              = "us-east-1"
availability_zones = ["us-east-1a", "us-east-1b", "us-east-1c"]  
namespace           = "customer-service-ns"
service_account     = "customer-sa"
cluster_version     = "1.31"  # Using stable Kubernetes version
node_instance_type  = "t2.medium"
node_desired        = 1
node_min            = 1
node_max            = 2
