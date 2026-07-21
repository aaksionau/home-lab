provider "libvirt" {
  # Requires passwordless SSH (key-based) from the machine running
  # `terraform apply` to ${var.server_user}@${var.server_host} already working,
  # e.g. `ssh ${var.server_user}@${var.server_host}` succeeds with no prompt.
  # The libvirt provider shells out to the system `ssh` client, so this must
  # be run from WSL/Linux/macOS, not native Windows (no libvirt client lib there).
  uri = "qemu+ssh://${var.server_user}@${var.server_host}/system?keyfile=${var.ssh_private_key_path}&sshauth=privkey"
}

provider "docker" {
  host = "ssh://${var.server_user}@${var.server_host}:22"
}
