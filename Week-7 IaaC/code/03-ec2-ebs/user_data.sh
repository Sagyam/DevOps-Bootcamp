#!/bin/bash
# Runs once, as root, at first boot. Logs to /var/log/cloud-init-output.log
# NOTE: this file is read with file(), not templatefile(), so ${...} is safe here.
set -euxo pipefail

dnf install -y nginx
systemctl enable --now nginx

# --- find the extra EBS volume -------------------------------------------
# Gotcha: on Nitro instances (t3, m5, c5...) a volume attached as /dev/sdf
# shows up in the kernel as /dev/nvme1n1. Amazon Linux ships udev rules that
# create a /dev/sdf symlink, but the attachment may land AFTER boot, so poll.
DEV=""
for i in $(seq 1 60); do
  for candidate in /dev/sdf /dev/xvdf /dev/nvme1n1; do
    if [ -b "$candidate" ]; then
      DEV=$(readlink -f "$candidate")
      break 2
    fi
  done
  sleep 5
done

if [ -n "$DEV" ]; then
  # Only format if there is no filesystem yet - otherwise you wipe real data.
  if ! blkid "$DEV" >/dev/null 2>&1; then
    mkfs -t ext4 "$DEV"
  fi

  mkdir -p /data
  UUID=$(blkid -s UUID -o value "$DEV")
  # Mount by UUID, never by device name: device names are not stable.
  # nofail means a missing volume will not brick the boot.
  echo "UUID=$UUID /data ext4 defaults,nofail 0 2" >> /etc/fstab
  mount -a
  echo "written by user_data at $(date -u)" > /data/proof.txt
  MOUNT_STATUS="mounted $DEV on /data"
else
  MOUNT_STATUS="NO EXTRA VOLUME FOUND"
fi

# --- render a status page -------------------------------------------------
{
  echo "<!doctype html><html><head><meta charset=utf-8>"
  echo "<title>Terraform Lab</title>"
  echo "<style>body{font-family:ui-monospace,monospace;background:#0f172a;color:#e2e8f0;padding:2rem;line-height:1.6}"
  echo "h1{color:#fb923c}h2{color:#2dd4bf;margin-top:2rem}pre{background:#1e293b;padding:1rem;border-radius:8px;overflow-x:auto}</style>"
  echo "</head><body>"
  echo "<h1>Built by Terraform</h1>"
  echo "<p>instance: $(curl -s -H "X-aws-ec2-metadata-token: $(curl -sX PUT http://169.254.169.254/latest/api/token -H 'X-aws-ec2-metadata-token-ttl-seconds: 60')" http://169.254.169.254/latest/meta-data/instance-id)</p>"
  echo "<p>EBS status: <strong>$MOUNT_STATUS</strong></p>"
  echo "<h2>lsblk</h2><pre>"
  lsblk
  echo "</pre><h2>df -h</h2><pre>"
  df -h
  echo "</pre><h2>/data</h2><pre>"
  ls -la /data 2>/dev/null || echo "/data does not exist"
  echo "</pre></body></html>"
} > /usr/share/nginx/html/index.html

systemctl restart nginx
