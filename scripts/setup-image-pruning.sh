#!/usr/bin/env bash
# One-time setup of a weekly systemd timer that prunes unused Docker images
# on the host. The CI runner pushes a freshly-tagged image to the registry
# on every build and nothing ever removes old tags, so this fills the host
# disk over time (hit 94% used before this was added -- see README).
#
# Idempotent -- safe to re-run.
#
# Usage (run directly on the Ubuntu host):
#   ./setup-image-pruning.sh

set -euo pipefail

sudo tee /etc/systemd/system/docker-image-prune.service > /dev/null <<'EOF'
[Unit]
Description=Prune unused Docker images

[Service]
Type=oneshot
ExecStart=/usr/bin/docker image prune -a -f
EOF

sudo tee /etc/systemd/system/docker-image-prune.timer > /dev/null <<'EOF'
[Unit]
Description=Run docker image prune weekly

[Timer]
OnCalendar=Sun *-*-* 03:00:00
Persistent=true

[Install]
WantedBy=timers.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable --now docker-image-prune.timer

echo "Done. Verify with: systemctl list-timers docker-image-prune.timer"
