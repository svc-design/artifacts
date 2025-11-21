#!/usr/bin/env bash
set -euo pipefail

# 强制非交互模式（解决 debconf / dpkg-preconfigure 报错）
export DEBIAN_FRONTEND=noninteractive
export DEBCONF_NONINTERACTIVE_SEEN=true

echo "[Cloud-Neutra] System Hardening"

##############################################
# SSH hardening
##############################################
sudo sed -i 's/^#PasswordAuthentication yes/PasswordAuthentication no/' /etc/ssh/sshd_config
sudo sed -i 's/^#PermitRootLogin .*/PermitRootLogin no/' /etc/ssh/sshd_config
sudo sed -i 's/^X11Forwarding yes/X11Forwarding no/' /etc/ssh/sshd_config

##############################################
# Sysctl tuning (safe defaults)
##############################################
cat <<EOF | sudo tee /etc/sysctl.d/99-cloud-neutra.conf
fs.inotify.max_user_watches=524288
vm.swappiness=10
net.ipv4.ip_forward=1
net.ipv4.conf.all.rp_filter=1
EOF

sudo sysctl --system || true

##############################################
# Journald persistent logging
##############################################
sudo mkdir -p /var/log/journal
sudo systemd-tmpfiles --create --prefix /var/log/journal

echo "[Cloud-Neutra] Hardening complete."
