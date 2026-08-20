resource "kubernetes_service_account" "service_account" {

  metadata {

    name = var.service_account

    namespace = var.namespace
  }
}
