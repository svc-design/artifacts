#!/usr/bin/env bash
set -euo pipefail

echo "======================================================="
echo " Cleaning Golden Image prior to Snapshot"
echo "======================================================="

export DEBIAN_FRONTEND=noninteractive

# 1. Clean APT cache and lists
apt-get autoremove -y --purge
apt-get clean
rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

# 2. Reset cloud-init if installed
if command -v cloud-init &>/dev/null; then
  echo "Cleaning cloud-init data..."
  cloud-init clean --logs --seed || true
fi

# 3. Clean machine-id so new instance generates a fresh unique ID
truncate -s 0 /etc/machine-id
if [ -f /var/lib/dbus/machine-id ]; then
  rm -f /var/lib/dbus/machine-id
fi

# 4. Remove SSH Host Keys (will be regenerated on first boot)
rm -f /etc/ssh/ssh_host_*

# 5. Clean shell history and logs
rm -rf /root/.bash_history /home/*/.bash_history
truncate -s 0 /var/log/wtmp /var/log/lastlog /var/log/syslog || true

sync
echo "Golden Image cleanup completed."
