resource "kubernetes_persistent_volume_claim_v1" "kafka" {
  wait_until_bound = false

  metadata {
    name      = "kafka-data"
    namespace = kubernetes_namespace_v1.weather.metadata[0].name
  }

  spec {
    access_modes       = ["ReadWriteOnce"]
    storage_class_name = var.storage_class

    resources {
      requests = {
        storage = "20Gi"
      }
    }
  }
}

resource "kubernetes_deployment_v1" "kafka" {
  metadata {
    name      = "kafka"
    namespace = kubernetes_namespace_v1.weather.metadata[0].name
    labels    = { app = "kafka" }
  }

  spec {
    replicas = 1

    selector {
      match_labels = { app = "kafka" }
    }

    strategy {
      type = "Recreate"
    }

    template {
      metadata {
        labels = { app = "kafka" }
      }

      spec {
        container {
          name  = "kafka"
          image = "apache/kafka:3.9.0"

          port {
            container_port = 29092
          }

          env {
            name  = "KAFKA_NODE_ID"
            value = "1"
          }
          env {
            name  = "KAFKA_PROCESS_ROLES"
            value = "broker,controller"
          }
          env {
            name = "KAFKA_LISTENERS"
            # Bind to the wildcard address, not the Service DNS name -- "kafka"
            # resolves to the Service's ClusterIP, which no pod actually owns
            # on its own network interface, so binding to it fails with
            # "Address not available". KAFKA_ADVERTISED_LISTENERS (below) is
            # the one that should use the Service name -- that's what other
            # pods connect to, a separate concern from what this pod binds to.
            value = "PLAINTEXT://0.0.0.0:29092,CONTROLLER://0.0.0.0:9093"
          }
          env {
            name = "KAFKA_ADVERTISED_LISTENERS"
            # Must explicitly include CONTROLLER too, even though it's not
            # meant to be client-facing -- if omitted, Kafka auto-derives it
            # from KAFKA_LISTENERS (now 0.0.0.0) and then wrongly validates
            # that auto-derived value as needing to be routable. Known
            # Kafka 3.9.0 bug: https://issues.apache.org/jira/browse/KAFKA-18281
            value = "PLAINTEXT://kafka:29092,CONTROLLER://kafka:9093"
          }
          env {
            name  = "KAFKA_LISTENER_SECURITY_PROTOCOL_MAP"
            value = "CONTROLLER:PLAINTEXT,PLAINTEXT:PLAINTEXT"
          }
          env {
            name  = "KAFKA_CONTROLLER_LISTENER_NAMES"
            value = "CONTROLLER"
          }
          env {
            name  = "KAFKA_CONTROLLER_QUORUM_VOTERS"
            value = "1@kafka:9093"
          }
          env {
            name  = "KAFKA_INTER_BROKER_LISTENER_NAME"
            value = "PLAINTEXT"
          }
          env {
            name  = "KAFKA_OFFSETS_TOPIC_REPLICATION_FACTOR"
            value = "1"
          }
          env {
            name  = "CLUSTER_ID"
            value = "MkU3OEVBNTcwNTJENDM2Qk"
          }
          env {
            # Keep the JVM heap comfortably under the memory limit below —
            # otherwise it sizes itself off host memory and gets OOM-killed.
            name  = "KAFKA_HEAP_OPTS"
            value = "-Xmx768m -Xms512m"
          }

          volume_mount {
            name       = "data"
            mount_path = "/var/lib/kafka/data"
          }

          resources {
            requests = {
              cpu    = "300m"
              memory = "768Mi"
            }
            limits = {
              cpu    = "1"
              memory = "1536Mi"
            }
          }

          readiness_probe {
            exec {
              command = ["/opt/kafka/bin/kafka-broker-api-versions.sh", "--bootstrap-server", "kafka:29092"]
            }
            initial_delay_seconds = 15
            period_seconds         = 10
            failure_threshold      = 10
          }
        }

        volume {
          name = "data"
          persistent_volume_claim {
            claim_name = kubernetes_persistent_volume_claim_v1.kafka.metadata[0].name
          }
        }
      }
    }
  }
}

resource "kubernetes_service_v1" "kafka" {
  metadata {
    name      = "kafka"
    namespace = kubernetes_namespace_v1.weather.metadata[0].name
  }

  spec {
    selector = { app = "kafka" }

    port {
      name        = "plaintext"
      port        = 29092
      target_port = 29092
    }
    port {
      name        = "controller"
      port        = 9093
      target_port = 9093
    }
  }
}
