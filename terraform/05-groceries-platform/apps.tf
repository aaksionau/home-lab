locals {
  ns            = kubernetes_namespace_v1.groceries.metadata[0].name
  registry_host = data.terraform_remote_state.infra.outputs.registry_host

  images = {
    web = "${local.registry_host}/groceries/checkscanner-web:${var.web_image_tag}"
  }
}

# --- checkscanner-web (Blazor Server: upload receipt photos, persist, browse list) ---

resource "kubernetes_deployment_v1" "web" {
  metadata {
    name      = "checkscanner-web"
    namespace = local.ns
    labels    = { app = "checkscanner-web" }
  }

  spec {
    replicas = 1
    selector { match_labels = { app = "checkscanner-web" } }

    template {
      metadata { labels = { app = "checkscanner-web" } }

      spec {
        container {
          name  = "checkscanner-web"
          image = local.images.web

          port { container_port = 8080 }

          env {
            name = "ConnectionStrings__CheckScannerDb"
            value_from {
              secret_key_ref {
                name = kubernetes_secret_v1.postgres.metadata[0].name
                key  = "CONNECTION_STRING"
              }
            }
          }
          env {
            name  = "PhotoStorage__BasePath"
            value = "/data/photos"
          }

          volume_mount {
            name       = "photos"
            mount_path = "/data/photos"
          }

          resources {
            requests = {
              cpu    = "100m"
              memory = "256Mi"
            }
            limits = {
              cpu    = "500m"
              memory = "512Mi"
            }
          }

          readiness_probe {
            http_get {
              path = "/"
              port = 8080
            }
            initial_delay_seconds = 5
            period_seconds        = 10
          }
        }

        volume {
          name = "photos"
          persistent_volume_claim {
            claim_name = kubernetes_persistent_volume_claim_v1.receipt_photos.metadata[0].name
          }
        }
      }
    }
  }
}

resource "kubernetes_service_v1" "web" {
  metadata {
    name      = "checkscanner-web"
    namespace = local.ns
  }

  spec {
    selector = { app = "checkscanner-web" }
    type     = "NodePort"

    port {
      port        = 8080
      target_port = 8080
      node_port   = var.web_node_port
    }
  }
}
