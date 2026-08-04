resource "libvirt_volume" "control_plane_disk" {
  name           = "control-plane.qcow2"
  pool           = libvirt_pool.vms.name
  base_volume_id = libvirt_volume.ubuntu_base.id
  size           = var.control_plane_disk_gb * 1024 * 1024 * 1024
  format         = "qcow2"
}

resource "libvirt_volume" "worker_disk" {
  name           = "worker.qcow2"
  pool           = libvirt_pool.vms.name
  base_volume_id = libvirt_volume.ubuntu_base.id
  size           = var.worker_disk_gb * 1024 * 1024 * 1024
  format         = "qcow2"
}

resource "libvirt_cloudinit_disk" "control_plane" {
  name = "control-plane-cloudinit.iso"
  pool = libvirt_pool.vms.name

  user_data = templatefile("${path.module}/cloud-init/control-plane-user-data.yaml.tftpl", {
    ssh_user         = var.server_user
    ssh_public_key   = var.ssh_public_key
    registry_host    = local.registry_host
    k3s_version      = var.k3s_version
    k3s_token        = random_password.k3s_token.result
    control_plane_ip = var.control_plane_ip
  })

  network_config = templatefile("${path.module}/cloud-init/network-config.yaml.tftpl", {
    mac_address    = local.control_plane_mac
    ip_address     = var.control_plane_ip
    prefix_length  = local.lan_prefix_length
    gateway        = var.lan_gateway
    dns_servers    = var.lan_dns_servers
  })
}

resource "libvirt_cloudinit_disk" "worker" {
  name = "worker-cloudinit.iso"
  pool = libvirt_pool.vms.name

  user_data = templatefile("${path.module}/cloud-init/worker-user-data.yaml.tftpl", {
    ssh_user         = var.server_user
    ssh_public_key   = var.ssh_public_key
    registry_host    = local.registry_host
    k3s_version      = var.k3s_version
    k3s_token        = random_password.k3s_token.result
    control_plane_ip = var.control_plane_ip
  })

  network_config = templatefile("${path.module}/cloud-init/network-config.yaml.tftpl", {
    mac_address    = local.worker_mac
    ip_address     = var.worker_ip
    prefix_length  = local.lan_prefix_length
    gateway        = var.lan_gateway
    dns_servers    = var.lan_dns_servers
  })
}

resource "libvirt_domain" "control_plane" {
  name      = "weather-k3s-control-plane"
  memory    = var.control_plane_memory_mb
  vcpu      = var.control_plane_vcpu
  autostart = true

  # Without this, QEMU falls back to a conservative default CPU model that
  # doesn't expose SSE4.2/POPCNT/etc. to the guest -- fine for the .NET
  # services, but breaks anything (e.g. NumPy/pandas wheels, which are
  # built expecting the x86-64-v2 baseline) that checks CPU features at
  # runtime. host-passthrough exposes the real host CPU (i5-8500T).
  cpu {
    mode = "host-passthrough"
  }

  cloudinit = libvirt_cloudinit_disk.control_plane.id

  network_interface {
    bridge         = var.libvirt_bridge_name
    mac            = local.control_plane_mac
    wait_for_lease = false
  }

  disk {
    volume_id = libvirt_volume.control_plane_disk.id
  }

  console {
    type        = "pty"
    target_type = "serial"
    target_port = "0"
  }

  console {
    type        = "pty"
    target_type = "virtio"
    target_port = "1"
  }
}

resource "libvirt_domain" "worker" {
  name      = "weather-k3s-worker"
  memory    = var.worker_memory_mb
  vcpu      = var.worker_vcpu
  autostart = true

  # See the same cpu block on libvirt_domain.control_plane for why --
  # this is the VM that actually runs stocks-web/stocks-pipeline, so
  # it's the one that was hitting the NumPy X86_V2 failure.
  cpu {
    mode = "host-passthrough"
  }

  cloudinit = libvirt_cloudinit_disk.worker.id

  network_interface {
    bridge         = var.libvirt_bridge_name
    mac            = local.worker_mac
    wait_for_lease = false
  }

  disk {
    volume_id = libvirt_volume.worker_disk.id
  }

  console {
    type        = "pty"
    target_type = "serial"
    target_port = "0"
  }

  console {
    type        = "pty"
    target_type = "virtio"
    target_port = "1"
  }

  # Not strictly required, but avoids the worker registering with k3s
  # before the control-plane API server exists.
  depends_on = [libvirt_domain.control_plane]
}
