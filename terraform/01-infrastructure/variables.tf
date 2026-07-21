variable "server_host" {
  description = "IP address or hostname of the Ubuntu server (the libvirt/KVM host)."
  type        = string
}

variable "server_user" {
  description = "SSH user on the Ubuntu server, used both for the libvirt connection and to SSH into the VMs once they're up (same key is injected into the VMs)."
  type        = string
  default     = "ubuntu"
}

variable "ssh_private_key_path" {
  description = "Path (on the machine running Terraform) to the private key that authenticates to the Ubuntu server and to the VMs."
  type        = string
  default     = "~/.ssh/id_ed25519"
}

variable "ssh_public_key" {
  description = "Full contents of the SSH public key to inject into both VMs via cloud-init (paste the .pub file contents)."
  type        = string
}

variable "host_physical_interface" {
  description = "Name of the physical NIC on the Ubuntu server to attach the VMs to via macvtap bridge mode, e.g. 'enp1s0' (find with `ip a` on the server). VMs get real LAN IPs directly off this interface, no host bridge needed."
  type        = string
}

variable "lan_subnet_cidr" {
  description = "CIDR of your home LAN, used only to derive the netmask/prefix length for the VMs' static IPs, e.g. \"192.168.1.0/24\"."
  type        = string
}

variable "lan_gateway" {
  description = "Default gateway (your router) on the LAN, e.g. \"192.168.1.1\"."
  type        = string
}

variable "lan_dns_servers" {
  description = "DNS servers for the VMs to use."
  type        = list(string)
  default     = ["1.1.1.1", "8.8.8.8"]
}

variable "control_plane_ip" {
  description = "Static LAN IP to assign to the k3s control-plane VM. Pick something outside your router's DHCP range."
  type        = string
}

variable "worker_ip" {
  description = "Static LAN IP to assign to the k3s worker VM. Pick something outside your router's DHCP range."
  type        = string
}

variable "control_plane_vcpu" {
  type    = number
  default = 2
}

variable "control_plane_memory_mb" {
  type    = number
  default = 4096
}

variable "control_plane_disk_gb" {
  type    = number
  default = 20
}

variable "worker_vcpu" {
  type    = number
  default = 4
}

variable "worker_memory_mb" {
  type    = number
  default = 24576
}

variable "worker_disk_gb" {
  type    = number
  default = 150
}

variable "ubuntu_image_url" {
  description = "URL of the Ubuntu cloud image (qcow2) to base the VMs on."
  type        = string
  default     = "https://cloud-images.ubuntu.com/releases/24.04/release/ubuntu-24.04-server-cloudimg-amd64.img"
}

variable "k3s_version" {
  description = "k3s release to install, e.g. \"v1.30.6+k3s1\". Empty string installs latest stable."
  type        = string
  default     = ""
}

variable "registry_port" {
  description = "Port the local Docker registry (running on the Ubuntu host) listens on."
  type        = number
  default     = 5000
}

variable "github_repo_url" {
  description = "URL of the weather-home-station GitHub repo the self-hosted CI runner registers against."
  type        = string
  default     = "https://github.com/aaksionau/weather-home-station"
}

variable "github_runner_pat" {
  description = "GitHub personal access token used to self-register the CI runner (fine-grained: 'Administration' repo permission, read/write, scoped to weather-home-station only; classic: 'repo' scope). Set this in terraform.tfvars, never commit it."
  type        = string
  sensitive   = true
}
