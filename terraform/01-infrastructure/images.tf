resource "libvirt_pool" "vms" {
  name = "weather-k3s"
  type = "dir"

  target {
    path = "/var/lib/libvirt/images/weather-k3s"
  }
}

resource "libvirt_volume" "ubuntu_base" {
  name   = "ubuntu-base.qcow2"
  pool   = libvirt_pool.vms.name
  source = var.ubuntu_image_url
  format = "qcow2"
}
