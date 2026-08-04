# Finnhub API key for the news pipeline's company-news fetch. Injected into
# the news-pipeline container only.
resource "kubernetes_secret_v1" "finnhub" {
  metadata {
    name      = "finnhub-credentials"
    namespace = kubernetes_namespace_v1.stocks.metadata[0].name
  }

  data = {
    FINNHUB_API_KEY = var.finnhub_api_key
  }
}
