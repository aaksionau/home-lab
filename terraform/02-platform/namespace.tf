resource "kubernetes_namespace_v1" "weather" {
  metadata {
    name = var.namespace
  }
}
