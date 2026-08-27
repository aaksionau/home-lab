locals {
  ns            = kubernetes_namespace_v1.coach.metadata[0].name
  registry_host = data.terraform_remote_state.infra.outputs.registry_host

  images = {
    web              = "${local.registry_host}/coach/coach-web:${var.web_image_tag}"
    garmin_ingestion = "${local.registry_host}/coach/coach-garmin-ingestion:${var.garmin_ingestion_image_tag}"
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
      metadata {
        labels = { app = "coach-web" }

        # env_from doesn't roll the pod when the ConfigMap/Secret contents
        # change, so fold their hashes into the pod template -- a changed
        # value in terraform.tfvars then forces a fresh rollout on apply.
        annotations = {
          "coach.config/checksum" = sha256(jsonencode({
            config = kubernetes_config_map_v1.coach_web.data
            secret = kubernetes_secret_v1.coach_web.data
          }))
        }
      }

      spec {
        container {
          name  = "coach-web"
          image = local.images.web

          port { container_port = 8080 }

          # Application config (Azure OpenAI, Google Calendar, SMS, schedules,
          # ASPNETCORE_ENVIRONMENT) -- see app-config.tf.
          env_from {
            config_map_ref {
              name = kubernetes_config_map_v1.coach_web.metadata[0].name
            }
          }
          env_from {
            secret_ref {
              name = kubernetes_secret_v1.coach_web.metadata[0].name
            }
          }

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

# --- coach-garmin-ingestion (daily batch job: log into Garmin -> upsert daily metrics) ---

resource "kubernetes_cron_job_v1" "garmin_ingestion" {
  metadata {
    name      = "coach-garmin-ingestion"
    namespace = local.ns
  }

  spec {
    schedule = var.garmin_ingestion_schedule
    timezone = "Etc/UTC"

    # One daily pull; a run should never overlap the next.
    concurrency_policy = "Forbid"

    successful_jobs_history_limit = 3
    failed_jobs_history_limit     = 3

    job_template {
      metadata {}

      spec {
        # The job aborts its own run on a systemic failure (bad login, API change)
        # and exits non-zero, so one retry is enough to ride out a transient blip.
        backoff_limit = 1

        template {
          metadata {
            labels = { app = "coach-garmin-ingestion" }
          }

          spec {
            restart_policy = "Never"

            container {
              name  = "coach-garmin-ingestion"
              image = local.images.garmin_ingestion

              env {
                name = "ConnectionStrings__CoachDb"
                value_from {
                  secret_key_ref {
                    name = kubernetes_secret_v1.postgres.metadata[0].name
                    key  = "CONNECTION_STRING"
                  }
                }
              }
              env {
                name = "Garmin__Email"
                value_from {
                  secret_key_ref {
                    name = kubernetes_secret_v1.garmin.metadata[0].name
                    key  = "EMAIL"
                  }
                }
              }
              env {
                name = "Garmin__Password"
                value_from {
                  secret_key_ref {
                    name = kubernetes_secret_v1.garmin.metadata[0].name
                    key  = "PASSWORD"
                  }
                }
              }

              resources {
                requests = {
                  cpu    = "100m"
                  memory = "128Mi"
                }
                limits = {
                  cpu    = "500m"
                  memory = "512Mi"
                }
              }
            }
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
