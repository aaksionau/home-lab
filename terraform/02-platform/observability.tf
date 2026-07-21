# OpenTelemetry Collector -> Prometheus (metrics) + Loki (logs) -> Grafana.
# Mirrors the docker-compose observability stack in weather-home-station.
# Config content is copied in rather than read from that repo with file(),
# because Terraform runs on the Ubuntu host, which has no guaranteed
# checkout of weather-home-station at a fixed relative path. Small configs
# are inlined below; the dashboard JSON lives in ./dashboards/ as its own
# file purely for readability and must be kept in sync by hand with
# weather-home-station's grafana/provisioning/dashboards/json/ copy.

# --- OpenTelemetry Collector ---

resource "kubernetes_config_map_v1" "otel_collector_config" {
  metadata {
    name      = "otel-collector-config"
    namespace = local.ns
  }

  data = {
    "config.yaml" = <<-EOT
      receivers:
        otlp:
          protocols:
            grpc:
              endpoint: 0.0.0.0:4317
            http:
              endpoint: 0.0.0.0:4318

      processors:
        batch: {}

      exporters:
        prometheus:
          endpoint: 0.0.0.0:8889
        loki:
          endpoint: http://loki:3100/loki/api/v1/push

      service:
        pipelines:
          metrics:
            receivers: [otlp]
            processors: [batch]
            exporters: [prometheus]
          logs:
            receivers: [otlp]
            processors: [batch]
            exporters: [loki]
    EOT
  }
}

resource "kubernetes_deployment_v1" "otel_collector" {
  metadata {
    name      = "otel-collector"
    namespace = local.ns
    labels    = { app = "otel-collector" }
  }

  spec {
    replicas = 1
    selector { match_labels = { app = "otel-collector" } }

    template {
      metadata { labels = { app = "otel-collector" } }

      spec {
        container {
          name  = "otel-collector"
          image = "otel/opentelemetry-collector-contrib:0.116.1"
          args  = ["--config=/etc/otelcol-contrib/config.yaml"]

          port { container_port = 4317 } # OTLP gRPC
          port { container_port = 4318 } # OTLP HTTP
          port { container_port = 8889 } # Prometheus scrape endpoint

          volume_mount {
            name       = "config"
            mount_path = "/etc/otelcol-contrib/config.yaml"
            sub_path   = "config.yaml"
          }

          resources {
            requests = {
              cpu    = "50m"
              memory = "64Mi"
            }
            limits = {
              cpu    = "200m"
              memory = "128Mi"
            }
          }
        }

        volume {
          name = "config"
          config_map {
            name = kubernetes_config_map_v1.otel_collector_config.metadata[0].name
          }
        }
      }
    }
  }
}

resource "kubernetes_service_v1" "otel_collector" {
  metadata {
    name      = "otel-collector"
    namespace = local.ns
  }

  spec {
    selector = { app = "otel-collector" }

    port {
      name        = "otlp-grpc"
      port        = 4317
      target_port = 4317
    }
    port {
      name        = "otlp-http"
      port        = 4318
      target_port = 4318
    }
    port {
      name        = "metrics"
      port        = 8889
      target_port = 8889
    }
  }
}

# --- Prometheus ---

resource "kubernetes_config_map_v1" "prometheus_config" {
  metadata {
    name      = "prometheus-config"
    namespace = local.ns
  }

  data = {
    "prometheus.yml" = <<-EOT
      global:
        scrape_interval: 15s

      scrape_configs:
        - job_name: otel-collector
          static_configs:
            - targets: ["otel-collector:8889"]
    EOT
  }
}

resource "kubernetes_persistent_volume_claim_v1" "prometheus" {
  wait_until_bound = false

  metadata {
    name      = "prometheus-data"
    namespace = local.ns
  }

  spec {
    access_modes       = ["ReadWriteOnce"]
    storage_class_name = var.storage_class

    resources {
      requests = {
        storage = "10Gi"
      }
    }
  }
}

resource "kubernetes_deployment_v1" "prometheus" {
  metadata {
    name      = "prometheus"
    namespace = local.ns
    labels    = { app = "prometheus" }
  }

  spec {
    replicas = 1
    selector { match_labels = { app = "prometheus" } }

    strategy {
      type = "Recreate"
    }

    template {
      metadata { labels = { app = "prometheus" } }

      spec {
        # The official image runs as the "nobody" user (65534) and won't be
        # able to write to a freshly-provisioned, root-owned PVC otherwise.
        security_context {
          fs_group = 65534
        }

        container {
          name  = "prometheus"
          image = "prom/prometheus:v2.55.1"

          port { container_port = 9090 }

          volume_mount {
            name       = "config"
            mount_path = "/etc/prometheus/prometheus.yml"
            sub_path   = "prometheus.yml"
          }

          volume_mount {
            name       = "data"
            mount_path = "/prometheus"
          }

          resources {
            requests = {
              cpu    = "100m"
              memory = "256Mi"
            }
            limits = {
              cpu    = "500m"
              memory = "768Mi"
            }
          }

          readiness_probe {
            http_get {
              path = "/-/ready"
              port = 9090
            }
            initial_delay_seconds = 5
            period_seconds        = 10
          }
        }

        volume {
          name = "config"
          config_map {
            name = kubernetes_config_map_v1.prometheus_config.metadata[0].name
          }
        }

        volume {
          name = "data"
          persistent_volume_claim {
            claim_name = kubernetes_persistent_volume_claim_v1.prometheus.metadata[0].name
          }
        }
      }
    }
  }
}

resource "kubernetes_service_v1" "prometheus" {
  metadata {
    name      = "prometheus"
    namespace = local.ns
  }

  spec {
    selector = { app = "prometheus" }

    port {
      port        = 9090
      target_port = 9090
    }
  }
}

# --- Loki ---

resource "kubernetes_persistent_volume_claim_v1" "loki" {
  wait_until_bound = false

  metadata {
    name      = "loki-data"
    namespace = local.ns
  }

  spec {
    access_modes       = ["ReadWriteOnce"]
    storage_class_name = var.storage_class

    resources {
      requests = {
        storage = "10Gi"
      }
    }
  }
}

resource "kubernetes_deployment_v1" "loki" {
  metadata {
    name      = "loki"
    namespace = local.ns
    labels    = { app = "loki" }
  }

  spec {
    replicas = 1
    selector { match_labels = { app = "loki" } }

    strategy {
      type = "Recreate"
    }

    template {
      metadata { labels = { app = "loki" } }

      spec {
        # The official image runs as uid/gid 10001 -- same PVC-ownership
        # issue as Prometheus below.
        security_context {
          fs_group = 10001
        }

        container {
          name  = "loki"
          image = "grafana/loki:3.2.0"

          port { container_port = 3100 }

          volume_mount {
            name       = "data"
            mount_path = "/loki"
          }

          resources {
            requests = {
              cpu    = "50m"
              memory = "128Mi"
            }
            limits = {
              cpu    = "300m"
              memory = "384Mi"
            }
          }

          readiness_probe {
            http_get {
              path = "/ready"
              port = 3100
            }
            initial_delay_seconds = 10
            period_seconds        = 10
          }
        }

        volume {
          name = "data"
          persistent_volume_claim {
            claim_name = kubernetes_persistent_volume_claim_v1.loki.metadata[0].name
          }
        }
      }
    }
  }
}

resource "kubernetes_service_v1" "loki" {
  metadata {
    name      = "loki"
    namespace = local.ns
  }

  spec {
    selector = { app = "loki" }

    port {
      port        = 3100
      target_port = 3100
    }
  }
}

# --- Grafana ---

resource "kubernetes_config_map_v1" "grafana_datasources" {
  metadata {
    name      = "grafana-datasources"
    namespace = local.ns
  }

  data = {
    "datasources.yaml" = <<-EOT
      apiVersion: 1

      datasources:
        - name: Prometheus
          uid: prometheus
          type: prometheus
          access: proxy
          url: http://prometheus:9090
          isDefault: true

        - name: Loki
          uid: loki
          type: loki
          access: proxy
          url: http://loki:3100
    EOT
  }
}

resource "kubernetes_config_map_v1" "grafana_dashboards_provider" {
  metadata {
    name      = "grafana-dashboards-provider"
    namespace = local.ns
  }

  data = {
    "dashboards.yaml" = <<-EOT
      apiVersion: 1

      providers:
        - name: Weather Pipeline
          orgId: 1
          folder: ""
          type: file
          disableDeletion: false
          updateIntervalSeconds: 30
          allowUiUpdates: true
          options:
            path: /etc/grafana/provisioning/dashboards/json
    EOT
  }
}

resource "kubernetes_config_map_v1" "grafana_dashboard_weather_pipeline" {
  metadata {
    name      = "grafana-dashboard-weather-pipeline"
    namespace = local.ns
  }

  # Keep in sync with weather-home-station's
  # grafana/provisioning/dashboards/json/weather-pipeline-overview.json.
  data = {
    "weather-pipeline-overview.json" = file("${path.module}/dashboards/weather-pipeline-overview.json")
  }
}

resource "kubernetes_persistent_volume_claim_v1" "grafana" {
  wait_until_bound = false

  metadata {
    name      = "grafana-data"
    namespace = local.ns
  }

  spec {
    access_modes       = ["ReadWriteOnce"]
    storage_class_name = var.storage_class

    resources {
      requests = {
        storage = "1Gi"
      }
    }
  }
}

resource "kubernetes_deployment_v1" "grafana" {
  metadata {
    name      = "grafana"
    namespace = local.ns
    labels    = { app = "grafana" }
  }

  spec {
    replicas = 1
    selector { match_labels = { app = "grafana" } }

    strategy {
      type = "Recreate"
    }

    template {
      metadata { labels = { app = "grafana" } }

      spec {
        # The official image runs as uid/gid 472 -- same PVC-ownership issue
        # as Prometheus and Loki above.
        security_context {
          fs_group = 472
        }

        container {
          name  = "grafana"
          image = "grafana/grafana:11.3.1"

          port { container_port = 3000 }

          env {
            # Anonymous admin access, same as the docker-compose stack --
            # fine on a LAN-only NodePort, do not expose this host to the
            # internet without locking it down (see README).
            name  = "GF_AUTH_ANONYMOUS_ENABLED"
            value = "true"
          }
          env {
            name  = "GF_AUTH_ANONYMOUS_ORG_ROLE"
            value = "Admin"
          }

          volume_mount {
            name       = "datasources"
            mount_path = "/etc/grafana/provisioning/datasources"
          }
          volume_mount {
            name       = "dashboards-provider"
            mount_path = "/etc/grafana/provisioning/dashboards"
          }
          volume_mount {
            name       = "dashboards-json"
            mount_path = "/etc/grafana/provisioning/dashboards/json"
          }
          volume_mount {
            name       = "data"
            mount_path = "/var/lib/grafana"
          }

          resources {
            requests = {
              cpu    = "50m"
              memory = "128Mi"
            }
            limits = {
              cpu    = "300m"
              memory = "256Mi"
            }
          }

          readiness_probe {
            http_get {
              path = "/api/health"
              port = 3000
            }
            initial_delay_seconds = 5
            period_seconds        = 10
          }
        }

        volume {
          name = "datasources"
          config_map {
            name = kubernetes_config_map_v1.grafana_datasources.metadata[0].name
          }
        }
        volume {
          name = "dashboards-provider"
          config_map {
            name = kubernetes_config_map_v1.grafana_dashboards_provider.metadata[0].name
          }
        }
        volume {
          name = "dashboards-json"
          config_map {
            name = kubernetes_config_map_v1.grafana_dashboard_weather_pipeline.metadata[0].name
          }
        }
        volume {
          name = "data"
          persistent_volume_claim {
            claim_name = kubernetes_persistent_volume_claim_v1.grafana.metadata[0].name
          }
        }
      }
    }
  }
}

resource "kubernetes_service_v1" "grafana" {
  metadata {
    name      = "grafana"
    namespace = local.ns
  }

  spec {
    selector = { app = "grafana" }
    type     = "NodePort"

    port {
      port        = 3000
      target_port = 3000
      node_port   = var.grafana_node_port
    }
  }
}
