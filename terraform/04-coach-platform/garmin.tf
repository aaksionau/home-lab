# Credentials for the daily Garmin ingestion CronJob (see apps.tf). The Garmin
# account has no MFA, which is what makes an unattended scheduled login viable.
resource "kubernetes_secret_v1" "garmin" {
  metadata {
    name      = "garmin-credentials"
    namespace = kubernetes_namespace_v1.coach.metadata[0].name
  }

  data = {
    EMAIL    = var.garmin_email
    PASSWORD = var.garmin_password
  }
}
