provider "libvirt" {
  # Requires passwordless SSH (key-based) from the machine running
  # `terraform apply` to ${var.server_user}@${var.server_host} already working,
  # e.g. `ssh ${var.server_user}@${var.server_host}` succeeds with no prompt.
  # The provider does its own SSH connection (Go-native, not the system `ssh`
  # binary), so `keyfile` must be an absolute path — it won't expand `~`.
  uri = "qemu+ssh://${var.server_user}@${var.server_host}/system?keyfile=${pathexpand(var.ssh_private_key_path)}&sshauth=privkey"
}

provider "docker" {
  host = "ssh://${var.server_user}@${var.server_host}:22"
}
