# Pull the kubeconfig off the control-plane once k3s has finished bootstrapping,
# rewriting the loopback server address to the control-plane's LAN IP so it's
# usable from outside the VM (including by the 02-platform Terraform stack
# and by kubectl on your workstation).

resource "time_sleep" "wait_for_k3s" {
  depends_on      = [libvirt_domain.control_plane, libvirt_domain.worker]
  create_duration = "90s"
}

resource "null_resource" "fetch_kubeconfig" {
  depends_on = [time_sleep.wait_for_k3s]

  triggers = {
    control_plane_id = libvirt_domain.control_plane.id
  }

  provisioner "local-exec" {
    interpreter = ["bash", "-c"]
    command     = <<-EOT
      set -e
      for i in $(seq 1 20); do
        if ssh -o StrictHostKeyChecking=no -o ConnectTimeout=5 \
            -i ${var.ssh_private_key_path} ${var.server_user}@${var.control_plane_ip} \
            "sudo cat /etc/rancher/k3s/k3s.yaml" > ${path.module}/kubeconfig.yaml 2>/dev/null; then
          break
        fi
        echo "k3s not ready yet, retrying in 15s ($i/20)..."
        sleep 15
      done
      sed -i "s/127.0.0.1/${var.control_plane_ip}/" ${path.module}/kubeconfig.yaml
    EOT
  }
}
