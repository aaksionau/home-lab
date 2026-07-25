resource "libvirt_pool" "vms" {
  name = "weather-k3s"
  type = "dir"

  # dmacvicar/libvirt v0.8.x has no `autostart` argument for pools (only
  # domains) — this pool needs `virsh pool-autostart weather-k3s` run
  # manually once, otherwise the VM disks in it won't be available for the
  # VMs to autostart against after a host reboot.
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
