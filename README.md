# home-server

Terraform for the Dell OptiPlex 7060 Micro (i5-8500T, 32GB RAM, 512GB NVMe,
Ubuntu host) running a 2-node k3s cluster for the
[weather-home-station](../weather-home-station) services.

## Architecture

```
Ubuntu host (KVM/libvirt)
├── weather-registry          plain Docker registry, host:5000, holds the 5 app images
├── VM: control-plane          2 vCPU / 4GB — k3s server, tainted (no workloads)
└── VM: worker                 4 vCPU / 24GB — k3s agent, runs everything below
        └── namespace: weather
            ├── kafka          (single-node KRaft, as in docker-compose)
            ├── postgres
            ├── azurite
            ├── weather-gateway-api      (NodePort 30135 — ESP32 posts here)
            ├── weather-processor-worker
            ├── weather-rules-worker
            ├── dashboard-api  (ClusterIP only, proxied by dashboard-web)
            └── dashboard-web  (NodePort 30190 — browser dashboard)
```

Both VMs get real LAN IPs via **macvtap** (bridge mode) straight off the
host's physical NIC — no Linux bridge needed on the host, so there's no risk
of the apply cutting off SSH to the host itself.

## Prerequisites

1. **Run Terraform from WSL/Linux/macOS, not native Windows.** The libvirt
   provider needs the libvirt client library, which isn't available on
   Windows. From this Windows machine, use WSL2.
2. Passwordless SSH key auth from wherever you run `terraform apply` to the
   Ubuntu server (`ssh ubuntu@<server-ip>` with no prompt).
3. On the Ubuntu server: `libvirtd`, `qemu-kvm`, and Docker installed, and
   your SSH user in the `libvirt` and `docker` groups.
4. Terraform >= 1.7 installed where you run `apply`.
5. Two free static IPs on your LAN (outside your router's DHCP range) for
   the control-plane and worker VMs.
6. The physical NIC name on the server (`ip a` on the server — the interface
   with your LAN IP on it, e.g. `enp1s0`).

## Deploy order

```bash
# 1. Provision the VMs and bootstrap k3s
cd terraform/01-infrastructure
cp terraform.tfvars.example terraform.tfvars   # fill in your values
terraform init
terraform apply
# outputs: control_plane_ip, worker_ip, registry_host, kubeconfig_path

# 2. Build and push the 5 service images to the registry it just created
cd ../../scripts
REGISTRY_HOST=$(cd ../terraform/01-infrastructure && terraform output -raw registry_host) \
  WEATHER_REPO=/path/to/weather-home-station \
  ./build-and-push.sh v1

# 3. Deploy the services onto the cluster
cd ../terraform/02-platform
cp terraform.tfvars.example terraform.tfvars   # set registry_host + image_tag = "v1"
terraform init
terraform apply
```

Then:
- Dashboard: `http://<worker-ip>:30190`
- Point the ESP32 station at: `http://<worker-ip>:30135`

## Redeploying after a code change

```bash
cd scripts
REGISTRY_HOST=... WEATHER_REPO=... ./build-and-push.sh v2
cd ../terraform/02-platform
# bump image_tag = "v2" in terraform.tfvars
terraform apply
```

## Notes / things you'll likely want to change later

- Postgres/Kafka/Azurite are single-replica with no backups — fine for a
  homelab, not fine for data you can't lose. Consider a periodic
  `pg_dump` cron if the readings matter to you.
- The registry is unauthenticated and only reachable on your LAN
  (`registry_port`, default 5000) — don't expose the host to the internet
  without locking that down.
- `kubeconfig.yaml` in `terraform/01-infrastructure/` has full cluster-admin
  access — treat it like a credential (it's already `.gitignore`d).
