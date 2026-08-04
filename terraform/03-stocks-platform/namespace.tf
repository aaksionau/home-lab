resource "kubernetes_namespace_v1" "stocks" {
  metadata {
    name = var.namespace
  }
}
