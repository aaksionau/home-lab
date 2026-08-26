resource "kubernetes_namespace_v1" "coach" {
  metadata {
    name = var.namespace
  }
}
