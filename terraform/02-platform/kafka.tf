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
            # Single-node KRaft: this broker is the only controller, voting
            # for itself. Routing that self-connection through the Service
            # ClusterIP relies on hairpin NAT working, which isn't reliable
            # here -- use the pod's own real IP instead. $(POD_IP) below is
            # Kubernetes' dependent-env-var substitution, resolved before the
            # container starts; it requires POD_IP to be defined earlier in
            # this list, which is why it's first.
            name = "POD_IP"
            value_from {
              field_ref {
                field_path = "status.podIP"
              }
            }
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
            # Both use POD_IP, not the Service name. Kafka clients (including
            # our own readiness probe) only use the bootstrap-server address
            # (the "kafka" Service) for their *first* connection -- metadata
            # comes back pointing at whatever's in advertised.listeners, and
            # every request after that reconnects there directly. If that's
            # the Service name, it resolves to the ClusterIP and hits the
            # same hairpin self-connection failure CONTROLLER did, just for
            # PLAINTEXT instead. Pod IPs are directly routable cluster-wide
            # (a basic CNI guarantee, no NAT involved), so advertising the
            # real pod IP sidesteps the problem entirely -- for the probe
            # and for real traffic from other services. The "kafka" Service
            # name still works fine as the stable *bootstrap* address other
            # pods use to find whichever pod is currently running.
            value = "PLAINTEXT://$(POD_IP):29092,CONTROLLER://$(POD_IP):9093"
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
            value = "1@$(POD_IP):9093"
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
              # localhost, not the Service name -- this runs inside the pod
              # itself, so there's no reason to route it through the Service
              # (and thus no risk of hitting the same hairpin issue as the
              # controller self-connection above).
              command = ["/opt/kafka/bin/kafka-broker-api-versions.sh", "--bootstrap-server", "localhost:29092"]
            }
            initial_delay_seconds = 15
            period_seconds        = 10
            failure_threshold     = 10
            # Default timeout is 1s -- too tight for a command that starts a
            # whole new JVM on every single invocation. It works fine when
            # run manually (no timeout), which is exactly the symptom this
            # produces: probe fails forever even though the command is
            # genuinely correct and would succeed given more than 1s.
            timeout_seconds = 10
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
