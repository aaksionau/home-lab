variable "kubeconfig_path" {
  description = "Path to the kubeconfig produced by the 01-infrastructure stack."
  type        = string
  default     = "../01-infrastructure/kubeconfig.yaml"
}

variable "namespace" {
  type    = string
  default = "weather"
}

variable "registry_host" {
  description = "host:port of the Docker registry the images were pushed to (matches 01-infrastructure's registry_host output)."
  type        = string
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
