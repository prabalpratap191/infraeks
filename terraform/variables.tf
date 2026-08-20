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
