output "dashboard_url" {
  value = "http://<control-plane-or-worker-ip>:${var.dashboard_node_port}"
}

output "gateway_ingest_url" {
  value = "http://<control-plane-or-worker-ip>:${var.gateway_node_port}"
}
