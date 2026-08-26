resource "random_password" "postgres" {
  length  = 24
  special = false
}

resource "kubernetes_secret_v1" "postgres" {
  metadata {
    name      = "postgres-credentials"
    namespace = kubernetes_namespace_v1.coach.metadata[0].name
  }

  data = {
    POSTGRES_USER     = "coach"
    POSTGRES_PASSWORD = random_password.postgres.result
    POSTGRES_DB       = "coach"
    # Coach.Web binds this straight into ConnectionStrings:CoachDb via the
    # ConnectionStrings__CoachDb env var (ASP.NET Core's double-underscore
    # config convention) -- Npgsql keyword=value format, not a URL.
    CONNECTION_STRING = "Host=postgres;Port=5432;Database=coach;Username=coach;Password=${random_password.postgres.result}"
  }
}

resource "kubernetes_persistent_volume_claim_v1" "postgres" {
  # local-path (k3s's default StorageClass) uses WaitForFirstConsumer binding
  # -- it won't bind until a pod that mounts it is scheduled. Without this,
  # Terraform waits for Bound before creating the Deployment that would
  # supply that pod, which deadlocks the two against each other.
  wait_until_bound = false

  metadata {
    name      = "postgres-data"
    namespace = kubernetes_namespace_v1.coach.metadata[0].name
  }

  spec {
    access_modes       = ["ReadWriteOnce"]
    storage_class_name = var.storage_class

    resources {
      requests = {
        # Personal goals/reflections/chat history, not sensor data -- small
        # at single-user scale, sized with headroom rather than tightly.
        storage = "5Gi"
      }
    }
  }
}

resource "kubernetes_deployment_v1" "postgres" {
  metadata {
    name      = "postgres"
    namespace = kubernetes_namespace_v1.coach.metadata[0].name
    labels    = { app = "postgres" }
  }

  spec {
    replicas = 1

    selector {
      match_labels = { app = "postgres" }
    }

    strategy {
      type = "Recreate"
    }

    template {
      metadata {
        labels = { app = "postgres" }
      }

      spec {
        container {
          name  = "postgres"
          image = "postgres:16-alpine"

          port {
            container_port = 5432
          }

          env {
            name = "POSTGRES_USER"
            value_from {
              secret_key_ref {
                name = kubernetes_secret_v1.postgres.metadata[0].name
                key  = "POSTGRES_USER"
              }
            }
          }
          env {
            name = "POSTGRES_PASSWORD"
            value_from {
              secret_key_ref {
                name = kubernetes_secret_v1.postgres.metadata[0].name
                key  = "POSTGRES_PASSWORD"
              }
            }
          }
          env {
            name = "POSTGRES_DB"
            value_from {
              secret_key_ref {
                name = kubernetes_secret_v1.postgres.metadata[0].name
                key  = "POSTGRES_DB"
              }
            }
          }

          volume_mount {
            name       = "data"
            mount_path = "/var/lib/postgresql/data"
          }

          resources {
            requests = {
              cpu    = "200m"
              memory = "256Mi"
            }
            limits = {
              cpu    = "1"
              memory = "1Gi"
            }
          }

          readiness_probe {
            exec {
              command = ["pg_isready", "-U", "coach", "-d", "coach"]
            }
            initial_delay_seconds = 5
            period_seconds        = 10
          }
        }

        volume {
          name = "data"
          persistent_volume_claim {
            claim_name = kubernetes_persistent_volume_claim_v1.postgres.metadata[0].name
          }
        }
      }
    }
  }
}

resource "kubernetes_service_v1" "postgres" {
  metadata {
    name      = "postgres"
    namespace = kubernetes_namespace_v1.coach.metadata[0].name
  }

  spec {
    selector = { app = "postgres" }

    port {
      port        = 5432
      target_port = 5432
    }
  }
}
