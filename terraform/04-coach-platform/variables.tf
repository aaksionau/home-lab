variable "kubeconfig_path" {
  description = "Path to the kubeconfig produced by the 01-infrastructure stack."
  type        = string
  default     = "../01-infrastructure/kubeconfig.yaml"
}

variable "namespace" {
  type    = string
  default = "coach"
}

variable "storage_class" {
  description = "StorageClass for persistent volumes. k3s ships with 'local-path' by default."
  type        = string
  default     = "local-path"
}

variable "web_image_tag" {
  description = "Tag of the coach-web image to deploy (produced by scripts/build-and-push-coach.sh)."
  type        = string
  default     = "latest"
}

variable "garmin_ingestion_image_tag" {
  description = "Tag of the coach-garmin-ingestion image to deploy (produced by scripts/build-and-push-coach.sh)."
  type        = string
  default     = "latest"
}

variable "garmin_ingestion_schedule" {
  description = "Cron schedule (UTC) for the daily Garmin ingestion job."
  type        = string
  default     = "30 5 * * *"
}

variable "garmin_email" {
  description = "Garmin Connect account email for the ingestion job (account must have MFA disabled)."
  type        = string
  sensitive   = true
}

variable "garmin_password" {
  description = "Garmin Connect account password for the ingestion job."
  type        = string
  sensitive   = true
}

variable "web_node_port" {
  description = "NodePort the Blazor web UI is exposed on."
  type        = number
  default     = 30400
}

# --- coach-web application config (see app-config.tf) -----------------------
# These bind into ASP.NET Core config via the "__" -> ":" env-var convention:
# azure_ai_api_key -> AzureAi__ApiKey -> AzureAi:ApiKey. Values come from the
# personal-coach user-secrets store; docs/*-setup.md in that repo explain each.

variable "azure_ai_endpoint" {
  description = "Azure OpenAI resource endpoint, e.g. https://<name>.openai.azure.com/."
  type        = string
}

variable "azure_ai_api_key" {
  description = "Azure OpenAI API key."
  type        = string
  sensitive   = true
}

variable "azure_ai_deployment_name" {
  description = "Azure OpenAI deployment (model) name the coach chats against."
  type        = string
  default     = "gpt-4o"
}

variable "google_calendar_client_id" {
  description = "OAuth client ID for the Google Calendar integration."
  type        = string
}

variable "google_calendar_client_secret" {
  description = "OAuth client secret for the Google Calendar integration."
  type        = string
  sensitive   = true
}

variable "google_calendar_refresh_token" {
  description = "OAuth refresh token for the Google Calendar integration (see docs/google-calendar-setup.md)."
  type        = string
  sensitive   = true
}

variable "google_calendar_id" {
  description = "Calendar to read/write; 'primary' is the account's default calendar."
  type        = string
  default     = "primary"
}

variable "sms_smtp_username" {
  description = "Gmail address used as the SMTP sender for SMS-via-email notifications."
  type        = string
}

variable "sms_smtp_password" {
  description = "Gmail app password (not the account password) for the SMS SMTP sender."
  type        = string
  sensitive   = true
}

variable "sms_to_number" {
  description = "Destination phone number for notifications, E.164 format, e.g. +16125551234."
  type        = string
}

variable "digest_timezone_id" {
  description = "IANA timezone the weekly digest schedule is evaluated in."
  type        = string
  default     = "America/Chicago"
}

variable "nudge_timezone_id" {
  description = "IANA timezone the due-date nudge schedule is evaluated in."
  type        = string
  default     = "America/Chicago"
}
