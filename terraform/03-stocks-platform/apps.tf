locals {
  ns            = kubernetes_namespace_v1.stocks.metadata[0].name
  registry_host = data.terraform_remote_state.infra.outputs.registry_host

  images = {
    pipeline         = "${local.registry_host}/stocks/stocks-pipeline:${var.pipeline_image_tag}"
    web              = "${local.registry_host}/stocks/stocks-web:${var.web_image_tag}"
    news_pipeline    = "${local.registry_host}/stocks/stocks-news-pipeline:${var.news_pipeline_image_tag}"
    company_pipeline = "${local.registry_host}/stocks/stocks-company-pipeline:${var.company_pipeline_image_tag}"
  }
}

# --- stocks-pipeline (batch job: fetch -> compute -> flag -> commentary -> persist) ---

resource "kubernetes_cron_job_v1" "pipeline" {
  metadata {
    name      = "stocks-pipeline"
    namespace = local.ns
  }

  spec {
    schedule = var.pipeline_schedule
    timezone = "Etc/UTC"

    # A run should never overlap the next one -- one daily snapshot per day.
    concurrency_policy = "Forbid"

    successful_jobs_history_limit = 3
    failed_jobs_history_limit     = 3

    job_template {
      metadata {}

      spec {
        # Don't hammer yfinance/Foundry on transient failures; a systemic
        # failure aborts the run itself (see pipeline.py), so one retry is
        # enough to ride out a one-off blip.
        backoff_limit = 1

        template {
          metadata {
            labels = { app = "stocks-pipeline" }
          }

          spec {
            restart_policy = "Never"

            container {
              name  = "stocks-pipeline"
              image = local.images.pipeline

              env {
                name = "DATABASE_URL"
                value_from {
                  secret_key_ref {
                    name = kubernetes_secret_v1.postgres.metadata[0].name
                    key  = "DATABASE_URL"
                  }
                }
              }
              env {
                name = "FOUNDRY_ENDPOINT"
                value_from {
                  secret_key_ref {
                    name = kubernetes_secret_v1.foundry.metadata[0].name
                    key  = "FOUNDRY_ENDPOINT"
                  }
                }
              }
              env {
                name = "FOUNDRY_API_KEY"
                value_from {
                  secret_key_ref {
                    name = kubernetes_secret_v1.foundry.metadata[0].name
                    key  = "FOUNDRY_API_KEY"
                  }
                }
              }
              env {
                name = "FOUNDRY_DEPLOYMENT"
                value_from {
                  secret_key_ref {
                    name = kubernetes_secret_v1.foundry.metadata[0].name
                    key  = "FOUNDRY_DEPLOYMENT"
                  }
                }
              }
              env {
                name = "FOUNDRY_API_VERSION"
                value_from {
                  secret_key_ref {
                    name = kubernetes_secret_v1.foundry.metadata[0].name
                    key  = "FOUNDRY_API_VERSION"
                  }
                }
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
            }
          }
        }
      }
    }
  }
}

# --- stocks-news-pipeline (batch job: fetch -> score -> persist) ---

resource "kubernetes_cron_job_v1" "news_pipeline" {
  metadata {
    name      = "stocks-news-pipeline"
    namespace = local.ns
  }

  spec {
    schedule = var.news_pipeline_schedule
    timezone = "Etc/UTC"

    # A run should never overlap the next one -- it re-queries unscored
    # articles from the last run rather than assuming a clean slate.
    concurrency_policy = "Forbid"

    successful_jobs_history_limit = 3
    failed_jobs_history_limit     = 3

    job_template {
      metadata {}

      spec {
        # Same rationale as stocks-pipeline: one retry is enough to ride out
        # a one-off Finnhub/Foundry blip; a systemic failure aborts the run
        # itself (see news/pipeline.py).
        backoff_limit = 1

        template {
          metadata {
            labels = { app = "stocks-news-pipeline" }
          }

          spec {
            restart_policy = "Never"

            container {
              name  = "stocks-news-pipeline"
              image = local.images.news_pipeline

              env {
                name = "DATABASE_URL"
                value_from {
                  secret_key_ref {
                    name = kubernetes_secret_v1.postgres.metadata[0].name
                    key  = "DATABASE_URL"
                  }
                }
              }
              env {
                name = "FINNHUB_API_KEY"
                value_from {
                  secret_key_ref {
                    name = kubernetes_secret_v1.finnhub.metadata[0].name
                    key  = "FINNHUB_API_KEY"
                  }
                }
              }
              env {
                name = "FOUNDRY_ENDPOINT"
                value_from {
                  secret_key_ref {
                    name = kubernetes_secret_v1.foundry.metadata[0].name
                    key  = "FOUNDRY_ENDPOINT"
                  }
                }
              }
              env {
                name = "FOUNDRY_API_KEY"
                value_from {
                  secret_key_ref {
                    name = kubernetes_secret_v1.foundry.metadata[0].name
                    key  = "FOUNDRY_API_KEY"
                  }
                }
              }
              env {
                name = "FOUNDRY_DEPLOYMENT"
                value_from {
                  secret_key_ref {
                    name = kubernetes_secret_v1.foundry.metadata[0].name
                    key  = "FOUNDRY_DEPLOYMENT"
                  }
                }
              }
              env {
                name = "FOUNDRY_API_VERSION"
                value_from {
                  secret_key_ref {
                    name = kubernetes_secret_v1.foundry.metadata[0].name
                    key  = "FOUNDRY_API_VERSION"
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

# --- stocks-company-pipeline (batch job: fetch -> persist company profiles) ---

resource "kubernetes_cron_job_v1" "company_pipeline" {
  metadata {
    name      = "stocks-company-pipeline"
    namespace = local.ns
  }

  spec {
    schedule = var.company_pipeline_schedule
    timezone = "Etc/UTC"

    # A run should never overlap the next one -- same reasoning as the other pipelines.
    concurrency_policy = "Forbid"

    successful_jobs_history_limit = 3
    failed_jobs_history_limit     = 3

    job_template {
      metadata {}

      spec {
        # Don't hammer yfinance on transient failures; a systemic failure
        # aborts the run itself (see company/pipeline.py), so one retry is
        # enough to ride out a one-off blip.
        backoff_limit = 1

        template {
          metadata {
            labels = { app = "stocks-company-pipeline" }
          }

          spec {
            restart_policy = "Never"

            container {
              name  = "stocks-company-pipeline"
              image = local.images.company_pipeline

              env {
                name = "DATABASE_URL"
                value_from {
                  secret_key_ref {
                    name = kubernetes_secret_v1.postgres.metadata[0].name
                    key  = "DATABASE_URL"
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

# --- stocks-web (Streamlit, read-only over Postgres) ---

resource "kubernetes_deployment_v1" "web" {
  metadata {
    name      = "stocks-web"
    namespace = local.ns
    labels    = { app = "stocks-web" }
  }

  spec {
    replicas = 1
    selector { match_labels = { app = "stocks-web" } }

    template {
      metadata { labels = { app = "stocks-web" } }

      spec {
        container {
          name  = "stocks-web"
          image = local.images.web

          port { container_port = 8501 }

          env {
            name = "DATABASE_URL"
            value_from {
              secret_key_ref {
                name = kubernetes_secret_v1.postgres.metadata[0].name
                key  = "DATABASE_URL"
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
              path = "/_stcore/health"
              port = 8501
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
    name      = "stocks-web"
    namespace = local.ns
  }

  spec {
    selector = { app = "stocks-web" }
    type     = "NodePort"

    port {
      port        = 8501
      target_port = 8501
      node_port   = var.web_node_port
    }
  }
}
