# Azure AI Foundry credentials for the flagged-ticker commentary calls.
# Injected into the pipeline container only -- the web UI never calls
# Foundry directly (repository.py is the only Postgres-backed data path it
# reads through).
resource "kubernetes_secret_v1" "foundry" {
  metadata {
    name      = "foundry-credentials"
    namespace = kubernetes_namespace_v1.stocks.metadata[0].name
  }

  data = {
    FOUNDRY_ENDPOINT    = var.foundry_endpoint
    FOUNDRY_API_KEY     = var.foundry_api_key
    FOUNDRY_DEPLOYMENT  = var.foundry_deployment
    FOUNDRY_API_VERSION = var.foundry_api_version
  }
}
