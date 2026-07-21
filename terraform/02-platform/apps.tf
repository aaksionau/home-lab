locals {
  ns = kubernetes_namespace_v1.weather.metadata[0].name

  images = {
    gateway_api      = "${var.registry_host}/weather/weather-gateway-api:${var.image_tag}"
    processor_worker = "${var.registry_host}/weather/weather-processor-worker:${var.image_tag}"
    rules_worker     = "${var.registry_host}/weather/weather-rules-worker:${var.image_tag}"
    dashboard_api    = "${var.registry_host}/weather/dashboard-api:${var.image_tag}"
    dashboard_web    = "${var.registry_host}/weather/dashboard-web:${var.image_tag}"
  }

  azurite_connection_string = "DefaultEndpointsProtocol=http;AccountName=devstoreaccount1;AccountKey=Eby8vdM02xNOcqFlqUwJPLlmEtlCDXJ1OUzFT50uSRZ6IFsuFq2UVErCz4I6tq/K1SZFPTOtr/KBHBeksoGMGw==;BlobEndpoint=http://azurite:10000/devstoreaccount1;"
}

# --- WeatherGateway.API (public-facing ingest, called by the ESP32 station) ---

resource "kubernetes_deployment_v1" "gateway_api" {
  metadata {
    name      = "weather-gateway-api"
    namespace = local.ns
    labels    = { app = "weather-gateway-api" }
  }

  spec {
    replicas = 1
    selector { match_labels = { app = "weather-gateway-api" } }

    template {
      metadata { labels = { app = "weather-gateway-api" } }

      spec {
        container {
          name  = "weather-gateway-api"
          image = local.images.gateway_api

          port { container_port = 8080 }

          env {
            name  = "ASPNETCORE_ENVIRONMENT"
            value = "Production"
          }
          env {
            name  = "Kafka__BootstrapServers"
            value = "kafka:29092"
          }
          env {
            name  = "Kafka__WeatherReadingsTopic"
            value = "weather.raw"
          }
          env {
            name  = "OTEL_SERVICE_NAME"
            value = "weather-gateway-api"
          }
          env {
            name  = "OTEL_EXPORTER_OTLP_ENDPOINT"
            value = "http://otel-collector:4317"
          }
          env {
            name  = "OTEL_METRIC_EXPORT_INTERVAL"
            value = "15000"
          }

          resources {
            requests = {
              cpu    = "100m"
              memory = "128Mi"
            }
            limits = {
              cpu    = "500m"
              memory = "384Mi"
            }
          }

          readiness_probe {
            http_get {
              path = "/health"
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

resource "kubernetes_service_v1" "gateway_api" {
  metadata {
    name      = "weather-gateway-api"
    namespace = local.ns
  }

  spec {
    selector = { app = "weather-gateway-api" }
    type     = "NodePort"

    port {
      port        = 8080
      target_port = 8080
      node_port   = var.gateway_node_port
    }
  }
}

# --- WeatherProcessor.Worker (enrichment, Kafka consumer + Postgres writer) ---

resource "kubernetes_deployment_v1" "processor_worker" {
  metadata {
    name      = "weather-processor-worker"
    namespace = local.ns
    labels    = { app = "weather-processor-worker" }
  }

  spec {
    replicas = 1
    selector { match_labels = { app = "weather-processor-worker" } }

    template {
      metadata { labels = { app = "weather-processor-worker" } }

      spec {
        container {
          name  = "weather-processor-worker"
          image = local.images.processor_worker

          env {
            name  = "Kafka__BootstrapServers"
            value = "kafka:29092"
          }
          env {
            name  = "Kafka__RawTopic"
            value = "weather.raw"
          }
          env {
            name  = "Kafka__ProcessedTopic"
            value = "weather.processed"
          }
          env {
            name  = "Kafka__ConsumerGroupId"
            value = "weather-processor"
          }
          env {
            name = "Postgres__ConnectionString"
            value_from {
              secret_key_ref {
                name = kubernetes_secret_v1.postgres.metadata[0].name
                key  = "CONNECTION_STRING"
              }
            }
          }
          env {
            name  = "OTEL_SERVICE_NAME"
            value = "weather-processor-worker"
          }
          env {
            name  = "OTEL_EXPORTER_OTLP_ENDPOINT"
            value = "http://otel-collector:4317"
          }
          env {
            name  = "OTEL_METRIC_EXPORT_INTERVAL"
            value = "15000"
          }

          resources {
            requests = {
              cpu    = "100m"
              memory = "128Mi"
            }
            limits = {
              cpu    = "500m"
              memory = "384Mi"
            }
          }
        }
      }
    }
  }
}

# --- WeatherRules.Worker (thresholds/anomaly checks, Kafka + Postgres + Azurite) ---

resource "kubernetes_deployment_v1" "rules_worker" {
  metadata {
    name      = "weather-rules-worker"
    namespace = local.ns
    labels    = { app = "weather-rules-worker" }
  }

  spec {
    replicas = 1
    selector { match_labels = { app = "weather-rules-worker" } }

    template {
      metadata { labels = { app = "weather-rules-worker" } }

      spec {
        container {
          name  = "weather-rules-worker"
          image = local.images.rules_worker

          env {
            name  = "Kafka__BootstrapServers"
            value = "kafka:29092"
          }
          env {
            name  = "Kafka__ProcessedTopic"
            value = "weather.processed"
          }
          env {
            name  = "Kafka__AlertsTopic"
            value = "weather.alerts"
          }
          env {
            name  = "Kafka__ConsumerGroupId"
            value = "weather-rules-engine"
          }
          env {
            name = "Postgres__ConnectionString"
            value_from {
              secret_key_ref {
                name = kubernetes_secret_v1.postgres.metadata[0].name
                key  = "CONNECTION_STRING"
              }
            }
          }
          env {
            name  = "BlobStorage__ConnectionString"
            value = local.azurite_connection_string
          }
          env {
            name  = "BlobStorage__ContainerName"
            value = "rules"
          }
          env {
            name  = "BlobStorage__RulesBlobName"
            value = "weather-alert-rules.json"
          }
          env {
            name  = "OTEL_SERVICE_NAME"
            value = "weather-rules-worker"
          }
          env {
            name  = "OTEL_EXPORTER_OTLP_ENDPOINT"
            value = "http://otel-collector:4317"
          }
          env {
            name  = "OTEL_METRIC_EXPORT_INTERVAL"
            value = "15000"
          }

          resources {
            requests = {
              cpu    = "100m"
              memory = "128Mi"
            }
            limits = {
              cpu    = "500m"
              memory = "384Mi"
            }
          }
        }
      }
    }
  }
}

# --- Dashboard.API (read-only, no Kafka dependency) ---

resource "kubernetes_deployment_v1" "dashboard_api" {
  metadata {
    name      = "dashboard-api"
    namespace = local.ns
    labels    = { app = "dashboard-api" }
  }

  spec {
    replicas = 1
    selector { match_labels = { app = "dashboard-api" } }

    template {
      metadata { labels = { app = "dashboard-api" } }

      spec {
        container {
          name  = "dashboard-api"
          image = local.images.dashboard_api

          port { container_port = 8080 }

          env {
            name  = "ASPNETCORE_ENVIRONMENT"
            value = "Production"
          }
          env {
            name = "Postgres__ConnectionString"
            value_from {
              secret_key_ref {
                name = kubernetes_secret_v1.postgres.metadata[0].name
                key  = "CONNECTION_STRING"
              }
            }
          }
          env {
            name  = "OTEL_SERVICE_NAME"
            value = "weather-dashboard-api"
          }
          env {
            name  = "OTEL_EXPORTER_OTLP_ENDPOINT"
            value = "http://otel-collector:4317"
          }
          env {
            name  = "OTEL_METRIC_EXPORT_INTERVAL"
            value = "15000"
          }

          resources {
            requests = {
              cpu    = "100m"
              memory = "128Mi"
            }
            limits = {
              cpu    = "500m"
              memory = "384Mi"
            }
          }

          readiness_probe {
            http_get {
              path = "/health"
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

resource "kubernetes_service_v1" "dashboard_api" {
  metadata {
    # Name must stay "dashboard-api" — Dashboard.Web's nginx.conf proxies
    # /api/ to http://dashboard-api:8080/api/.
    name      = "dashboard-api"
    namespace = local.ns
  }

  spec {
    selector = { app = "dashboard-api" }

    port {
      port        = 8080
      target_port = 8080
    }
  }
}

# --- Dashboard.Web (nginx + static SPA, proxies /api/ to dashboard-api) ---

resource "kubernetes_deployment_v1" "dashboard_web" {
  metadata {
    name      = "dashboard-web"
    namespace = local.ns
    labels    = { app = "dashboard-web" }
  }

  spec {
    replicas = 1
    selector { match_labels = { app = "dashboard-web" } }

    template {
      metadata { labels = { app = "dashboard-web" } }

      spec {
        container {
          name  = "dashboard-web"
          image = local.images.dashboard_web

          port { container_port = 80 }

          resources {
            requests = {
              cpu    = "20m"
              memory = "32Mi"
            }
            limits = {
              cpu    = "200m"
              memory = "128Mi"
            }
          }
        }
      }
    }
  }
}

resource "kubernetes_service_v1" "dashboard_web" {
  metadata {
    name      = "dashboard-web"
    namespace = local.ns
  }

  spec {
    selector = { app = "dashboard-web" }
    type     = "NodePort"

    port {
      port        = 80
      target_port = 80
      node_port   = var.dashboard_node_port
    }
  }
}
