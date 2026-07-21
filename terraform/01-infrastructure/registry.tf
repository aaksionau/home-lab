# A plain, unauthenticated Docker registry running directly on the Ubuntu
# host (outside k3s) so both VMs can pull images for the 5 weather-station
# services. Both VMs trust it as an insecure/http registry via the
# registries.yaml written by cloud-init (see cloud-init/*-user-data.yaml.tftpl).

resource "docker_volume" "registry_data" {
  name = "weather-registry-data"
}

resource "docker_image" "registry" {
  name = "registry:2"
}

resource "docker_container" "registry" {
  name  = "weather-registry"
  image = docker_image.registry.image_id

  restart = "unless-stopped"

  ports {
    internal = 5000
    external = var.registry_port
  }

  volumes {
    volume_name    = docker_volume.registry_data.name
    container_path = "/var/lib/registry"
  }
}
