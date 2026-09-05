variable "kubeconfig_path" {
  description = "Path to the kubeconfig produced by the 01-infrastructure stack."
  type        = string
  default     = "../01-infrastructure/kubeconfig.yaml"
}

variable "namespace" {
  type    = string
  default = "groceries"
}

variable "storage_class" {
  description = "StorageClass for persistent volumes. k3s ships with 'local-path' by default."
  type        = string
  default     = "local-path"
}

variable "web_image_tag" {
  description = "Tag of the checkscanner-web image to deploy (produced by scripts/build-and-push-checkscanner.sh)."
  type        = string
  default     = "latest"
}

variable "web_node_port" {
  description = "NodePort the Blazor web UI is exposed on."
  type        = number
  default     = 30500
}

variable "azure_foundry_endpoint" {
  description = "Azure AI Foundry project endpoint used for receipt parsing."
  type        = string
  sensitive   = true
}

variable "azure_foundry_api_key" {
  description = "Azure AI Foundry API key used for receipt parsing."
  type        = string
  sensitive   = true
}

variable "azure_foundry_deployment_name" {
  description = "Azure AI Foundry model deployment name."
  type        = string
  default     = "gpt-4o-mini"
}
