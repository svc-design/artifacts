#!/usr/bin/env bash
set -euo pipefail

# 强制非交互模式（解决 debconf / dpkg-preconfigure 报错）
export DEBIAN_FRONTEND=noninteractive
export DEBCONF_NONINTERACTIVE_SEEN=true

echo "[Cloud-Neutra] OS Base Initialization"

##############################################
# Enable standard repositories
##############################################
sudo add-apt-repository universe -y || true
sudo add-apt-repository multiverse -y || true
sudo add-apt-repository restricted -y || true
sudo sed -i 's/# deb/deb/g' /etc/apt/sources.list

sudo apt-get update -y

##############################################
# Safe upgrade (no kernel updates)
##############################################
sudo apt-get dist-upgrade -y --no-install-recommends

##############################################
# Remove snapd
##############################################
if command -v snap >/dev/null 2>&1; then
  sudo systemctl stop snapd.service || true
fi

sudo apt-get remove --purge -y snapd || true
sudo rm -rf /var/cache/snapd/ ~/snap /snap || true

##############################################
# Remove MOTD noise and useless packages
##############################################
sudo apt-get remove --purge -y \
  landscape-common \
  update-notifier-common \
  motd-news-config \
  apport \
  whoopsie || true

sudo rm -rf /etc/update-motd.d/* || true

##############################################
# Add minimal essential tools
##############################################
sudo apt-get install -y --no-install-recommends \
  jq curl unzip gnupg lsb-release ca-certificates \
  software-properties-common net-tools iproute2 iptables

##############################################
# Disable auto-update timers
##############################################
sudo systemctl disable apt-daily.service apt-daily-upgrade.service || true
sudo systemctl disable apt-daily.timer apt-daily-upgrade.timer || true

echo "[Cloud-Neutra] Base OS setup completed."
