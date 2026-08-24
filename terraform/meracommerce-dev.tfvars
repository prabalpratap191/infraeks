# Environment: Development
cluster_name        = "meracommerce-dev"
region              = "us-east-1"
availability_zones = ["us-east-1a", "us-east-1b", "us-east-1c"]  
namespace           = "customer-ns"
service_account     = "customer-sa"
cluster_version     = "1.33"
node_instance_type  = "t3.medium"
node_desired        = 2
node_min            = 1
node_max            = 3
