resource "kubernetes_namespace_v1" "groceries" {
  metadata {
    name = var.namespace
  }
}
