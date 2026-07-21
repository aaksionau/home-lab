locals {
  control_plane_mac = "52:54:00:12:34:01"
  worker_mac         = "52:54:00:12:34:02"

  lan_prefix_length = split("/", var.lan_subnet_cidr)[1]

  registry_host = "${var.server_host}:${var.registry_port}"
}
