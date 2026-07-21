output "control_plane_ip" {
  value = var.control_plane_ip
}

output "worker_ip" {
  value = var.worker_ip
}

output "registry_host" {
  value = local.registry_host
}

output "kubeconfig_path" {
  value      = "${path.module}/kubeconfig.yaml"
  depends_on = [null_resource.fetch_kubeconfig]
}
