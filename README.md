# home-server

Terraform for the Dell OptiPlex 7060 Micro (i5-8500T, 32GB RAM, 512GB NVMe,
Ubuntu host) running a 2-node k3s cluster for the
[weather-home-station](../weather-home-station) services.

## Architecture

```
Ubuntu host (KVM/libvirt)
├── weather-registry          plain Docker registry, host:5000, holds the 5 app images
├── weather-ci-runner          self-hosted GitHub Actions runner — builds + pushes only, never deploys
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
            ├── dashboard-web  (NodePort 30190 — browser dashboard)
            ├── otel-collector (ClusterIP — OTLP receiver for all 4 .NET services)
            ├── prometheus     (ClusterIP — scrapes otel-collector)
            ├── loki           (ClusterIP — logs, via otel-collector)
            └── grafana        (NodePort 30300 — dashboards + log explore)
```

Both VMs attach to a real Linux bridge (`br0`) on the host, not macvtap.
Macvtap was the original design (avoids touching host networking at all),
but it has a hard limitation: the host itself can't reach VMs sharing its
own physical NIC that way, only other LAN devices can. Since Terraform (and
`kubectl` afterwards) runs directly on this host, that limitation is fatal —
a real bridge doesn't have it, at the cost of a one-time host networking
change (see below).

## Prerequisites

1. **Terraform runs directly on the Ubuntu/libvirt host itself** — SSH in
   and run it there, not from a separate WSL2/Windows machine. This is a
   deliberate choice, not just a convenience: the VMs' network setup (below)
   requires the host to reach them directly, so splitting Terraform onto a
   different machine reintroduces exactly the problem the bridge solves.
2. **A Linux bridge (`br0`) with your physical NIC enslaved to it** — see
   "Host networking setup" below. This is the riskiest one-time step, since
   it reconfigures the network interface carrying your SSH session.
3. On the server: `libvirtd`, `qemu-system-x86` (Ubuntu dropped the
   `qemu-kvm` metapackage name — installing that by name will fail),
   `genisoimage` (provides `mkisofs`, required to build the cloud-init ISO
   disks — the apply fails with `mkisofs: executable file not found` without
   it), and Docker. Your login user needs to be in the `libvirt`, `kvm`, and
   `docker` groups.
   ```bash
   sudo apt update
   sudo apt install -y qemu-system-x86 libvirt-daemon-system libvirt-clients \
     bridge-utils virtinst cpu-checker genisoimage
   curl -fsSL https://get.docker.com | sh
   sudo usermod -aG libvirt,kvm,docker $USER
   # log out/in (or `newgrp`) for group membership to take effect
   ```
4. **An AppArmor override for the custom storage pool path** — see
   "AppArmor override" below. Ubuntu confines each VM's QEMU process by
   default; without this, VM disks fail with `Could not open ... Permission
   denied` even when the underlying Unix file permissions are correct.
5. Terraform >= 1.7 installed on the server.
6. Two free static IPs on your LAN (outside your router's DHCP range) for
   the control-plane and worker VMs — reserve them in your router against
   the fixed MACs already in `locals.tf` (`52:54:00:12:34:01` /
   `52:54:00:12:34:02`), not against a DHCP-assigned address, since the VMs
   get static IPs via cloud-init, not DHCP.
7. **An SSH key pair on the server itself** (not on a separate dev machine)
   — `ssh_public_key` in tfvars gets injected into both VMs via cloud-init;
   `ssh_private_key_path` is what Terraform uses afterwards to SSH in and
   fetch the kubeconfig.

## Host networking setup (one-time)

Check your current config first (`cat /etc/netplan/*.yaml` — likely one
file, DHCP on your physical interface). Rewrite it to bridge that interface,
keeping the same MAC on the bridge so DHCP hands out the same IP:

```yaml
network:
  ethernets:
    eno1:                          # your physical NIC — `ip a` to confirm
      dhcp4: false
      dhcp6: false
      match:
        macaddress: e4:54:e8:56:d3:13   # that NIC's real MAC
      set-name: eno1
  bridges:
    br0:
      interfaces: [eno1]
      macaddress: e4:54:e8:56:d3:13     # same MAC, so the DHCP lease carries over
      dhcp4: true
      dhcp6: true
  version: 2
```

Apply it with `sudo netplan try`, **not** `netplan apply` — since this
reconfigures the interface carrying your current SSH session, `try` is what
makes it safe: it auto-reverts after ~120s unless you explicitly confirm
(press Enter) within that window. If your session survives the switchover,
confirm it. If it drops entirely, don't do anything — wait out the timeout
and it reverts on its own; no lockout. (Skip any custom bridge `parameters:`
like `stp`/`forward-delay` — `netplan try`'s rollback can't safely undo
those and will refuse to run at all if it sees them.)

Confirm afterwards: `ip a show br0` should show the IP; `bridge link show`
should list your physical NIC as a member in `forwarding` state.

## AppArmor override (one-time)

Ubuntu's libvirt/AppArmor integration only auto-whitelists the default
`/var/lib/libvirt/images` pool for VM disk access. This project uses a
custom pool (`weather-k3s`) at the same parent path, which isn't covered —
VMs fail to start with a `Permission denied` on the disk file otherwise.

```bash
sudo mkdir -p /etc/apparmor.d/abstractions/libvirt-qemu.d
echo '  /var/lib/libvirt/images/weather-k3s/** rwk,' | \
  sudo tee /etc/apparmor.d/abstractions/libvirt-qemu.d/weather-k3s
sudo systemctl reload apparmor
```

You'll also need the pool directory itself to be traversable and its files
readable by the unprivileged user Ubuntu runs QEMU as (`libvirt-qemu`) —
this is normally handled automatically for volumes Terraform creates, but
if you ever hit a plain (non-AppArmor) permission error here too:

```bash
sudo chmod 755 /var/lib/libvirt/images/weather-k3s
sudo find /var/lib/libvirt/images/weather-k3s -type f -exec chmod 644 {} \;
```

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
- Grafana: `http://<worker-ip>:30300` (anonymous access, Admin role — see notes below)

## CI/CD

Pushing to `main` on `weather-home-station` triggers
[`.github/workflows/build-and-push.yml`](../weather-home-station/.github/workflows/build-and-push.yml)
on the self-hosted runner (`weather-ci-runner`, provisioned by
`ci-runner.tf`): it builds all 5 images, tags them with the commit SHA, and
pushes them to the registry. **It stops there — deploying is always a
manual step**, so a bad build never touches the running cluster on its own.

The workflow's job summary prints the exact command to run. It looks like:

```bash
cd terraform/02-platform
terraform apply -var="image_tag=<commit-sha-from-the-Actions-run>"
```

For a one-off build without going through CI (e.g. testing a change before
pushing), `scripts/build-and-push.sh` still works the same way it always
did:

```bash
cd scripts
REGISTRY_HOST=... WEATHER_REPO=... ./build-and-push.sh v2
cd ../terraform/02-platform
# bump image_tag = "v2" in terraform.tfvars
terraform apply
```

**Runner setup, one-time:** create a GitHub fine-grained personal access
token scoped to just `weather-home-station`, with the "Administration"
repository permission set to read/write (that's what lets it register
itself as a runner). Put it in `github_runner_pat` in
`terraform/01-infrastructure/terraform.tfvars` and `terraform apply`. The
runner is given the host's Docker socket so it can build/push images
itself — equivalent to root on the host, which is fine for a single-user
box but worth knowing.

## Notes / things you'll likely want to change later

- Postgres/Kafka/Azurite are single-replica with no backups — fine for a
  homelab, not fine for data you can't lose. Consider a periodic
  `pg_dump` cron if the readings matter to you.
- The registry is unauthenticated and only reachable on your LAN
  (`registry_port`, default 5000) — don't expose the host to the internet
  without locking that down.
- Grafana (`grafana_node_port`, default 30300) has anonymous access enabled
  with the Admin role, same as the docker-compose stack — fine on a
  LAN-only NodePort, not fine if you ever expose this host to the internet.
- Prometheus and Loki have no retention/backup policy beyond their PVC size
  (10Gi each) — fine for a homelab, but they'll eventually fill up and need
  either a retention setting or a bigger PVC.
- `kubeconfig.yaml` in `terraform/01-infrastructure/` has full cluster-admin
  access — treat it like a credential (it's already `.gitignore`d).
- `terraform/01-infrastructure/terraform.tfstate` now holds your GitHub PAT
  in plaintext (Terraform state isn't encrypted at rest) — it's already
  `.gitignore`d, but don't hand that file to anyone.
