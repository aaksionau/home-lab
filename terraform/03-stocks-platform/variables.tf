variable "kubeconfig_path" {
  description = "Path to the kubeconfig produced by the 01-infrastructure stack."
  type        = string
  default     = "../01-infrastructure/kubeconfig.yaml"
}

variable "namespace" {
  type    = string
  default = "stocks"
}

variable "storage_class" {
  description = "StorageClass for persistent volumes. k3s ships with 'local-path' by default."
  type        = string
  default     = "local-path"
}

variable "pipeline_image_tag" {
  description = "Tag of the stocks-pipeline image to deploy (produced by scripts/build-and-push-stocks.sh)."
  type        = string
  default     = "latest"
}

variable "web_image_tag" {
  description = "Tag of the stocks-web image to deploy (produced by scripts/build-and-push-stocks.sh)."
  type        = string
  default     = "latest"
}

variable "news_pipeline_image_tag" {
  description = "Tag of the stocks-news-pipeline image to deploy (produced by scripts/build-and-push-stocks.sh)."
  type        = string
  default     = "latest"
}

variable "company_pipeline_image_tag" {
  description = "Tag of the stocks-company-pipeline image to deploy (produced by scripts/build-and-push-stocks.sh)."
  type        = string
  default     = "latest"
}

variable "web_node_port" {
  description = "NodePort the Streamlit web UI is exposed on."
  type        = number
  default     = 30200
}

variable "pipeline_schedule" {
  description = "Cron schedule (in the cluster's local time, which is UTC) for the daily pipeline CronJob. Default is 22:00 UTC on weekdays -- after US market close, before the AI Foundry commentary calls are needed the next morning."
  type        = string
  default     = "0 22 * * 1-5"
}

variable "news_pipeline_schedule" {
  description = "Cron schedule (in the cluster's local time, which is UTC) for the news pipeline CronJob. News moves faster than end-of-day prices, so this runs more often than pipeline_schedule -- every 4 hours by default."
  type        = string
  default     = "0 */4 * * *"
}

variable "company_pipeline_schedule" {
  description = "Cron schedule (in the cluster's local time, which is UTC) for the company profile CronJob. Company profile data (sector, industry, description) changes rarely, so this runs on a much looser cadence than the other pipelines -- weekly by default."
  type        = string
  default     = "0 6 * * 0"
}

variable "finnhub_api_key" {
  description = "Finnhub API key for news fetching (https://finnhub.io). Set this in terraform.tfvars, never commit it."
  type        = string
  sensitive   = true
}

variable "foundry_endpoint" {
  description = "Azure AI Foundry resource endpoint, e.g. https://<resource>.openai.azure.com. Set this in terraform.tfvars, never commit it."
  type        = string
  sensitive   = true
}

variable "foundry_api_key" {
  description = "Azure AI Foundry API key. Set this in terraform.tfvars, never commit it."
  type        = string
  sensitive   = true
}

variable "foundry_deployment" {
  description = "Azure AI Foundry model deployment name."
  type        = string
  default     = "gpt-4o-mini"
}

variable "foundry_api_version" {
  description = "Azure AI Foundry API version."
  type        = string
  default     = "2024-10-21"
}
