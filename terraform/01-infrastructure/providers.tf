provider "libvirt" {
  # Assumes Terraform runs directly on the Ubuntu/libvirt host itself (as
  # documented in the README) — so this connects locally, no SSH involved.
  # Requires the user running `terraform apply` to be in the `libvirt` group.
  uri = "qemu:///system"
}

provider "docker" {
  # Local Docker socket — requires the user running `terraform apply` to be
  # in the `docker` group.
  host = "unix:///var/run/docker.sock"
}
