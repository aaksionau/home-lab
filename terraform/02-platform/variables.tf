variable "kubeconfig_path" {
  description = "Path to the kubeconfig produced by the 01-infrastructure stack."
  type        = string
  default     = "../01-infrastructure/kubeconfig.yaml"
}

variable "namespace" {
  type    = string
  default = "weather"
}

variable "image_tag" {
  description = "Tag of the weather-station images to deploy (produced by scripts/build-and-push.sh)."
  type        = string
  default     = "latest"
}

variable "storage_class" {
  description = "StorageClass for persistent volumes. k3s ships with 'local-path' by default."
  type        = string
  default     = "local-path"
}

variable "gateway_node_port" {
  description = "NodePort the WeatherGateway.API is exposed on, for the ESP32 station to POST readings to."
  type        = number
  default     = 30135
}

variable "dashboard_node_port" {
  description = "NodePort the dashboard web UI is exposed on."
  type        = number
  default     = 30190
}

variable "grafana_node_port" {
  description = "NodePort Grafana is exposed on."
  type        = number
  default     = 30300
}

variable "sms_smtp_username" {
  description = "Gmail address used to relay SMS alerts through Google Fi's email-to-SMS gateway. Requires a Gmail app password (myaccount.google.com/apppasswords), not the account's login password. Set this in terraform.tfvars, never commit it."
  type        = string
  sensitive   = true
}

variable "sms_smtp_password" {
  description = "Gmail app password for sms_smtp_username. Set this in terraform.tfvars, never commit it."
  type        = string
  sensitive   = true
}

variable "sms_recipient_numbers" {
  description = "10-digit Google Fi number(s) to receive SMS alerts, delivered via <number>@msg.fi.google.com."
  type        = list(string)
  sensitive   = true
}
