terraform {
  backend "s3" {
    bucket = "meracommerce-tf-state"
    key    = "eks/terraform.tfstate"
    region = "us-east-1"
  }
}
