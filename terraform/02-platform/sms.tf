resource "kubernetes_secret_v1" "sms" {
  metadata {
    name      = "sms-credentials"
    namespace = kubernetes_namespace_v1.weather.metadata[0].name
  }

  data = {
    SMTP_USERNAME = var.sms_smtp_username
    SMTP_PASSWORD = var.sms_smtp_password
  }
}
