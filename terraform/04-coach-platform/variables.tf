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
