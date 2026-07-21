output "dashboard_url" {
  value = "http://<control-plane-or-worker-ip>:${var.dashboard_node_port}"
}

output "gateway_ingest_url" {
  value = "http://<control-plane-or-worker-ip>:${var.gateway_node_port}"
}

output "grafana_url" {
  value = "http://<control-plane-or-worker-ip>:${var.grafana_node_port}"
}
