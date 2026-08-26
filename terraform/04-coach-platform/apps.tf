locals {
  ns            = kubernetes_namespace_v1.coach.metadata[0].name
  registry_host = data.terraform_remote_state.infra.outputs.registry_host

  images = {
    web = "${local.registry_host}/coach/coach-web:${var.web_image_tag}"
  }
}

# --- coach-web (Blazor Server, no coach logic yet -- reachable page + Postgres check) ---

resource "kubernetes_deployment_v1" "web" {
  metadata {
    name      = "coach-web"
    namespace = local.ns
    labels    = { app = "coach-web" }
  }

  spec {
    replicas = 1
    selector { match_labels = { app = "coach-web" } }

    template {
      metadata { labels = { app = "coach-web" } }

      spec {
        container {
          name  = "coach-web"
          image = local.images.web

          port { container_port = 8080 }

          env {
            name = "ConnectionStrings__CoachDb"
            value_from {
              secret_key_ref {
                name = kubernetes_secret_v1.postgres.metadata[0].name
                key  = "CONNECTION_STRING"
              }
            }
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
      }
    }
  }
}

resource "kubernetes_service_v1" "web" {
  metadata {
    name      = "coach-web"
    namespace = local.ns
  }

  spec {
    selector = { app = "coach-web" }
    type     = "NodePort"

    port {
      port        = 8080
      target_port = 8080
      node_port   = var.web_node_port
    }
  }
}
