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

# 2. Disable unattended-upgrades & APT daily timers to prevent first-boot dpkg lock
echo "Disabling automatic background APT timers & unattended-upgrades..."
systemctl disable --now apt-daily.timer apt-daily-upgrade.timer unattended-upgrades.service 2>/dev/null || true
systemctl mask apt-daily.timer apt-daily-upgrade.timer unattended-upgrades.service 2>/dev/null || true

# 3. Disable cloud-init package update modules if cloud-init is installed
if [ -f /etc/cloud/cloud.cfg ]; then
  echo "Disabling cloud-init package-update modules..."
  sed -i 's/^[[:space:]]*- package-update-upgrade-install/# - package-update-upgrade-install/' /etc/cloud/cloud.cfg || true
  sed -i 's/^[[:space:]]*- apt-configure/# - apt-configure/' /etc/cloud/cloud.cfg || true
fi

# 4. Clean all APT lock files
rm -f /var/lib/dpkg/lock* /var/lib/apt/lists/lock /var/cache/apt/archives/lock

# 5. Reset cloud-init if installed
if command -v cloud-init &>/dev/null; then
  echo "Cleaning cloud-init data..."
  cloud-init clean --logs --seed || true
fi

# 6. Clean machine-id so new instance generates a fresh unique ID
truncate -s 0 /etc/machine-id
if [ -f /var/lib/dbus/machine-id ]; then
  rm -f /var/lib/dbus/machine-id
fi

# 7. Remove SSH Host Keys (will be regenerated on first boot)
rm -f /etc/ssh/ssh_host_*

# 8. Clean shell history and logs
rm -rf /root/.bash_history /home/*/.bash_history
truncate -s 0 /var/log/wtmp /var/log/lastlog /var/log/syslog || true

sync
echo "Golden Image cleanup completed successfully."
