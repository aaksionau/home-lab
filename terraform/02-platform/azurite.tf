resource "kubernetes_persistent_volume_claim_v1" "azurite" {
  metadata {
    name      = "azurite-data"
    namespace = kubernetes_namespace_v1.weather.metadata[0].name
  }

  spec {
    access_modes       = ["ReadWriteOnce"]
    storage_class_name = var.storage_class

    resources {
      requests = {
        storage = "5Gi"
      }
    }
  }
}

resource "kubernetes_deployment_v1" "azurite" {
  metadata {
    name      = "azurite"
    namespace = kubernetes_namespace_v1.weather.metadata[0].name
    labels    = { app = "azurite" }
  }

  spec {
    replicas = 1

    selector {
      match_labels = { app = "azurite" }
    }

    strategy {
      type = "Recreate"
    }

    template {
      metadata {
        labels = { app = "azurite" }
      }

      spec {
        container {
          name    = "azurite"
          image   = "mcr.microsoft.com/azure-storage/azurite:latest"
          command = ["azurite-blob", "--blobHost", "0.0.0.0", "--blobPort", "10000", "--skipApiVersionCheck"]

          port {
            container_port = 10000
          }

          volume_mount {
            name       = "data"
            mount_path = "/data"
          }
        }

        volume {
          name = "data"
          persistent_volume_claim {
            claim_name = kubernetes_persistent_volume_claim_v1.azurite.metadata[0].name
          }
        }
      }
    }
  }
}

resource "kubernetes_service_v1" "azurite" {
  metadata {
    name      = "azurite"
    namespace = kubernetes_namespace_v1.weather.metadata[0].name
  }

  spec {
    selector = { app = "azurite" }

    port {
      port        = 10000
      target_port = 10000
    }
  }
}
