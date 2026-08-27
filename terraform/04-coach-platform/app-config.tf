# coach-web application configuration, beyond the Postgres connection string
# (that stays wired directly from the postgres-credentials secret in apps.tf).
#
# Split non-secret / secret so the ConfigMap can be inspected freely while the
# keys, tokens and passwords stay in a Secret. Both are projected wholesale
# into the container with `env_from` (see apps.tf), and ASP.NET Core maps the
# "__" in each key to a ":" config section: AzureAi__ApiKey -> AzureAi:ApiKey.
#
# The Garmin CronJob does NOT consume these -- it only needs the DB plus its
# own garmin-credentials secret.

resource "kubernetes_config_map_v1" "coach_web" {
  metadata {
    name      = "coach-web-config"
    namespace = local.ns
  }

  data = {
    ASPNETCORE_ENVIRONMENT = "Production"

    AzureAi__Endpoint       = var.azure_ai_endpoint
    AzureAi__DeploymentName = var.azure_ai_deployment_name

    GoogleCalendar__ClientId   = var.google_calendar_client_id
    GoogleCalendar__CalendarId = var.google_calendar_id

    Sms__SmtpUsername = var.sms_smtp_username
    Sms__ToNumber     = var.sms_to_number

    Digest__TimeZoneId = var.digest_timezone_id
    Nudge__TimeZoneId  = var.nudge_timezone_id
  }
}

resource "kubernetes_secret_v1" "coach_web" {
  metadata {
    name      = "coach-web-secrets"
    namespace = local.ns
  }

  data = {
    AzureAi__ApiKey = var.azure_ai_api_key

    GoogleCalendar__ClientSecret = var.google_calendar_client_secret
    GoogleCalendar__RefreshToken = var.google_calendar_refresh_token

    Sms__SmtpPassword = var.sms_smtp_password
  }
}
